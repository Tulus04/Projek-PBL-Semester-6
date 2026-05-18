-- ============================================================
-- verify-face.sql — Smoke test queries untuk face register/verify/delete
-- ============================================================
-- Tujuan : Verifikasi flow biometrik (UU PDP Pasal 4 — data spesifik).
--          Coverage:
--            (a) Register wajah   → row baru di face_embeddings + flag profiles
--            (b) Verify server-side (T0-#10) → audit log similarity, BUKAN embedding
--            (c) Delete /face/me  → row hilang + flag false (UU PDP hak hapus)
--            (d) RPC at-risk revoke (T0-#11) → grants benar
--
-- Pakai  : Supabase Studio → SQL Editor (login admin), atau psql.
-- Substitusi:
--   <STUDENT_ID> = profiles.id mahasiswa demo
-- ============================================================

-- ============================================================
-- Section 1: Pre-test baseline
-- ============================================================
-- Catat status awal sebelum test register/verify/delete.

-- 1.1 Apakah mahasiswa sudah punya embedding tersimpan?
SELECT
  fe.id,
  fe.user_id,
  fe.embedding_hash,                -- TIDAK select kolom 'embedding' (Tier 1, 192-d float)
  fe.registered_at,
  fe.updated_at,
  octet_length(fe.embedding) AS embedding_bytes  -- panjang BYTEA, hint integrity
FROM face_embeddings fe
WHERE fe.user_id = '<STUDENT_ID>';

-- 1.2 Flag profiles.is_face_registered konsisten dengan section 1.1?
SELECT id, full_name, nim_nip, is_face_registered, role
FROM profiles
WHERE id = '<STUDENT_ID>';

-- 1.3 Setting threshold yang dipakai server saat verify
SELECT key, value, description
FROM settings
WHERE key IN ('face_confidence_threshold', 'face_verification_mode');
-- Expected: face_confidence_threshold = 0.65 (MobileFaceNet 192-d, migration 005)


-- ============================================================
-- Section 2: Verify face register (POST /api/mobile/face/register)
-- ============================================================
-- Setelah mahasiswa selesai 7-frame averaging + tap "Daftarkan Wajah":
--   - Row baru / overwrite di face_embeddings (UNIQUE user_id → upsert)
--   - profiles.is_face_registered = true
--   - 1 row audit 'mobile_face_register'

-- 2.1 Embedding tersimpan + hash ada
SELECT
  fe.user_id,
  fe.embedding_hash,                -- non-null, hex 64 char (sha256)
  fe.registered_at,
  fe.updated_at,
  octet_length(fe.embedding) AS embedding_bytes  -- ~1500-2000 byte (192 float64)
FROM face_embeddings fe
WHERE fe.user_id = '<STUDENT_ID>';

-- 2.2 Flag profiles flipped ke true
SELECT is_face_registered
FROM profiles
WHERE id = '<STUDENT_ID>';
-- Expected: true

-- 2.3 Audit row register
SELECT
  al.action, al.user_id, al.ip_address,
  al.details ? 'embedding_hash' AS has_hash_only,
  al.details ? 'embedding'      AS has_raw_embedding,  -- HARUS false
  al.details->>'device_id'      AS device_id,
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_face_register'
  AND al.created_at > now() - interval '15 minutes'
ORDER BY al.created_at DESC
LIMIT 1;
-- Expected: has_hash_only=true, has_raw_embedding=false (rule 04-security B.3)


-- ============================================================
-- Section 3: Verify face verify server-side (T0-#10 — POST /api/mobile/face/verify)
-- ============================================================
-- Kontrak baru server-side:
--   Request : { embedding: number[192] }
--   Response: { match, similarity, threshold }   ← BOOLEAN, bukan raw embedding
-- Hapus    : GET /api/mobile/face/embedding (endpoint lama bocor embedding)

-- 3.1 Audit row verify — sukses match
SELECT
  al.action,                        -- 'mobile_face_verify'
  al.user_id, al.ip_address,
  al.details->>'matched'    AS matched_flag,
  al.details->>'similarity' AS similarity,   -- float 0..1
  al.details->>'threshold'  AS threshold,    -- = settings.face_confidence_threshold
  al.details->>'device_id'  AS device_id,
  al.details ? 'embedding'  AS leaked_raw_embedding,  -- HARUS false
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_face_verify'
  AND al.created_at > now() - interval '10 minutes'
ORDER BY al.created_at DESC
LIMIT 5;

-- 3.2 Distribusi similarity score (untuk lihat threshold tuning)
SELECT
  date_trunc('hour', created_at) AS bucket,
  count(*) AS verify_count,
  round(avg((details->>'similarity')::numeric), 4) AS avg_similarity,
  count(*) FILTER (WHERE (details->>'matched')::boolean = true) AS matched_count
FROM audit_logs
WHERE action = 'mobile_face_verify'
  AND created_at > now() - interval '24 hours'
GROUP BY 1
ORDER BY 1 DESC;


-- ============================================================
-- Section 4: Verify face delete (P2 — UU PDP hak hapus)
-- ============================================================
-- DELETE /api/mobile/face/me
--   - HARD DELETE row di face_embeddings (bukan soft delete)
--   - profiles.is_face_registered = false
--   - audit 'mobile_face_delete'

-- 4.1 Row di face_embeddings sudah hilang
SELECT count(*) AS embedding_rows_after_delete
FROM face_embeddings
WHERE user_id = '<STUDENT_ID>';
-- Expected: 0

-- 4.2 Flag profiles flipped ke false
SELECT is_face_registered
FROM profiles
WHERE id = '<STUDENT_ID>';
-- Expected: false

-- 4.3 Audit row delete dengan detail forensic
SELECT
  al.action, al.user_id, al.ip_address,
  al.details ? 'previous_hash' AS has_previous_hash,
  al.details ? 'registered_at' AS has_registered_at,
  al.details->>'device_id'     AS device_id,
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_face_delete'
  AND al.created_at > now() - interval '10 minutes'
ORDER BY al.created_at DESC
LIMIT 1;


-- ============================================================
-- Section 5: At-risk RPC revoke verification (T0-#11 — migration 018)
-- ============================================================
-- Function get_at_risk_students HARUS hanya executable oleh service_role
-- (+ owner postgres). anon & authenticated REVOKED.

-- 5.1 Cek grants pada function
SELECT
  pg_get_userbyid(grantee.oid) AS grantee_role,
  has_function_privilege(grantee.oid, p.oid, 'EXECUTE') AS can_execute
FROM pg_proc p
CROSS JOIN pg_roles grantee
WHERE p.proname = 'get_at_risk_students'
  AND p.pronamespace = 'public'::regnamespace
  AND grantee.rolname IN ('anon', 'authenticated', 'service_role', 'postgres')
ORDER BY grantee.rolname;
-- Expected:
--   anon          | false
--   authenticated | false
--   service_role  | true
--   postgres      | true

-- 5.2 Cek SECURITY DEFINER + search_path eksplisit (rule 04-security B + 14-supabase G)
SELECT
  p.proname,
  p.prosecdef AS is_security_definer,
  p.proconfig AS config_settings   -- harus include 'search_path=public, pg_temp'
FROM pg_proc p
WHERE p.proname = 'get_at_risk_students'
  AND p.pronamespace = 'public'::regnamespace;


-- ============================================================
-- Section 6: RLS evidence — face_embeddings only owner + service_role
-- ============================================================
-- Pastikan tidak ada policy public yang bocor embedding ke role lain.

SELECT
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual           -- USING clause
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'face_embeddings';
-- Expected: 1 policy "Users can manage own face embedding" FOR ALL
--   USING (auth.uid() = user_id) — tidak ada policy public/anon
