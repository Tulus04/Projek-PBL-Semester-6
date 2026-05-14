// scripts/smoke-test-mobile-api.mjs
// Smoke test otomatis untuk endpoint mobile MyPresensi.
// Verify BUG-011 fix: setiap audit_logs row dari /api/mobile/* harus punya
// user_id, ip_address, dan details.user_agent terisi (forensic trail lengkap).
//
// Cakupan: 6 audit action types
//   - mobile_login
//   - mobile_change_password (roundtrip: forward + revert)
//   - mobile_face_register
//   - mobile_attendance_submit (positive case)
//   - mock_location_detected (negative case, expect 403)
//   - mobile_leave_request_submit
//
// Run: npm run test:smoke
//
// Prerequisites:
//   1. Dev server jalan di http://localhost:3000 (npm run dev)
//   2. Akun test mahasiswa di .dev-accounts.md (default: Budi Santoso P2100003)
//   3. .env.local terisi NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
//   4. Minimal 2 sesi aktif di MK001 (untuk attendance + leave request)
//
// Override via env var (opsional):
//   BASE_URL=http://localhost:3000
//   TEST_EMAIL=budi.santoso@student.ac.id
//   TEST_PASSWORD=P2100003@politani
//   TEST_NIM=P2100003
//
// Exit code 0 = semua test pass, 1 = ada yang gagal.
// Script idempotent — selalu cleanup state DB ke baseline awal.

import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

// =====================================================
// Setup
// =====================================================

const __dirname = dirname(fileURLToPath(import.meta.url))

/** Parse .env.local secara manual (tanpa dependency dotenv) */
function loadEnv() {
  const envPath = join(__dirname, '..', '.env.local')
  const content = readFileSync(envPath, 'utf-8')
  const env = {}
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const idx = trimmed.indexOf('=')
    if (idx === -1) continue
    const key = trimmed.slice(0, idx).trim()
    const value = trimmed
      .slice(idx + 1)
      .trim()
      .replace(/^["']|["']$/g, '')
    env[key] = value
  }
  return env
}

const env = loadEnv()
const SUPABASE_URL = env.NEXT_PUBLIC_SUPABASE_URL
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('FATAL: NEXT_PUBLIC_SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY tidak ditemukan di .env.local')
  process.exit(1)
}

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000'
const TEST_EMAIL = process.env.TEST_EMAIL || 'budi.santoso@student.ac.id'
const TEST_PASSWORD = process.env.TEST_PASSWORD || 'P2100003@politani'
const TEST_NIM = process.env.TEST_NIM || 'P2100003'
const NEW_PASSWORD = 'TestSmoke12345!' // Sementara untuk roundtrip
const USER_AGENT = 'MyPresensi-SmokeTest/1.0 (Node)'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
})

// =====================================================
// Pretty-print helpers
// =====================================================

const c = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m',
  bold: '\x1b[1m',
}

let passed = 0
let failed = 0
const failures = []

function log(msg, color = '') {
  console.log(`${color}${msg}${c.reset}`)
}
function pass(name, info = '') {
  passed++
  log(`  ${c.green}✓${c.reset} ${name}${info ? ` ${c.gray}${info}${c.reset}` : ''}`)
}
function fail(name, err) {
  failed++
  failures.push(`${name}: ${err}`)
  log(`  ${c.red}✗${c.reset} ${name}: ${c.red}${err}${c.reset}`)
}
function section(name) {
  log(`\n${c.bold}${c.cyan}━━━ ${name} ━━━${c.reset}`)
}
function info(msg) {
  log(`  ${c.gray}${msg}${c.reset}`)
}

// =====================================================
// HTTP helper
// =====================================================

async function api(path, options = {}) {
  const url = `${BASE_URL}/api/mobile${path}`
  const res = await fetch(url, {
    method: 'POST',
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': USER_AGENT,
      ...(options.headers || {}),
    },
  })
  const text = await res.text()
  let data
  try {
    data = JSON.parse(text)
  } catch {
    data = { raw: text }
  }
  return { status: res.status, data }
}

// =====================================================
// Cleanup tracking
// =====================================================

const ctx = {
  profileId: null,
  baselineTime: null,
  attendanceSessionId: null,
  leaveSessionId: null,
  courseId: null,
  enrollmentCreated: false, // true kalau script yang buat (perlu rollback)
  passwordChanged: false, // true kalau forward berhasil tapi revert gagal
}

async function cleanup() {
  section('CLEANUP')
  if (!ctx.profileId) {
    info('No profile context, skipping cleanup')
    return
  }

  try {
    // Hapus attendances/leave_requests/face_embeddings yang dibuat selama test
    if (ctx.attendanceSessionId) {
      const { count: attCount } = await admin
        .from('attendances')
        .delete({ count: 'exact' })
        .eq('session_id', ctx.attendanceSessionId)
        .eq('student_id', ctx.profileId)
      info(`Deleted ${attCount ?? 0} attendance row(s)`)
    }

    if (ctx.baselineTime) {
      const { count: leaveCount } = await admin
        .from('leave_requests')
        .delete({ count: 'exact' })
        .eq('student_id', ctx.profileId)
        .gte('created_at', ctx.baselineTime)
      info(`Deleted ${leaveCount ?? 0} leave request row(s)`)
    }

    const { count: faceCount } = await admin
      .from('face_embeddings')
      .delete({ count: 'exact' })
      .eq('user_id', ctx.profileId)
    info(`Deleted ${faceCount ?? 0} face embedding row(s)`)

    // Reset session_code
    if (ctx.attendanceSessionId) {
      await admin
        .from('sessions')
        .update({ session_code: null, session_code_expires_at: null })
        .eq('id', ctx.attendanceSessionId)
      info(`Reset session_code on session ${ctx.attendanceSessionId.slice(0, 8)}...`)
    }

    // Hapus enrollment kalau script yang buat
    if (ctx.enrollmentCreated && ctx.courseId) {
      await admin
        .from('enrollments')
        .delete()
        .eq('course_id', ctx.courseId)
        .eq('student_id', ctx.profileId)
      info('Deleted test enrollment')
    }

    // Reset profile flags
    await admin
      .from('profiles')
      .update({ is_face_registered: false, must_change_password: true })
      .eq('id', ctx.profileId)
    info('Reset profile flags (must_change_password=true, is_face_registered=false)')

    if (ctx.passwordChanged) {
      log(
        `  ${c.yellow}⚠ WARNING: password mungkin masih ${NEW_PASSWORD}, revert otomatis gagal. Reset manual via dashboard admin.${c.reset}`
      )
    }
  } catch (err) {
    log(`  ${c.red}Cleanup error: ${err.message}${c.reset}`)
  }
}

// =====================================================
// Main test sequence
// =====================================================

async function main() {
  log(`${c.bold}${c.cyan}MyPresensi Mobile API Smoke Test${c.reset}`)
  info(`Base URL:     ${BASE_URL}`)
  info(`Test account: ${TEST_EMAIL} (${TEST_NIM})`)
  info(`Started at:   ${new Date().toISOString()}\n`)

  // -------- SETUP: Get profile + sessions --------
  section('SETUP')

  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('id, full_name, nim_nip')
    .eq('nim_nip', TEST_NIM)
    .single()

  if (profileError || !profile) {
    fail('Get profile', profileError?.message ?? 'not found')
    return
  }
  ctx.profileId = profile.id
  info(`Profile: ${profile.full_name} (${profile.nim_nip}) ${profile.id.slice(0, 8)}...`)

  // Baseline timestamp untuk filter audit_logs row baru
  ctx.baselineTime = new Date().toISOString()
  info(`Baseline: ${ctx.baselineTime}`)

  // Find MK001 + active sessions
  const { data: course } = await admin.from('courses').select('id').eq('code', 'MK001').single()
  if (!course) {
    fail('Setup', 'MK001 course not found')
    return
  }
  ctx.courseId = course.id

  const { data: sessions } = await admin
    .from('sessions')
    .select('id, session_number, mode, location_lat, location_lng, radius_meters')
    .eq('course_id', course.id)
    .eq('is_active', true)
    .is('ended_at', null)
    .order('session_number')

  if (!sessions || sessions.length === 0) {
    fail('Setup', 'No active sessions in MK001 — buat sesi aktif dulu via dashboard dosen')
    return
  }
  ctx.attendanceSessionId = sessions[0].id
  ctx.leaveSessionId = sessions[1]?.id ?? sessions[0].id
  info(`Attendance: session #${sessions[0].session_number} (mode=${sessions[0].mode})`)
  info(`Leave:      session #${(sessions[1]?.session_number ?? sessions[0].session_number)}`)

  // Insert enrollment (idempotent)
  const { data: existingEnroll } = await admin
    .from('enrollments')
    .select('id')
    .eq('course_id', course.id)
    .eq('student_id', profile.id)
    .limit(1)
    .maybeSingle()

  if (!existingEnroll) {
    const { error: enrollError } = await admin.from('enrollments').insert({
      course_id: course.id,
      student_id: profile.id,
      academic_year: '2025/2026',
    })
    if (enrollError) {
      fail('Setup enrollment', enrollError.message)
      return
    }
    ctx.enrollmentCreated = true
    info('Enrollment created (will rollback on cleanup)')
  } else {
    info('Enrollment already exists (preserved)')
  }

  // Set session_code untuk attendance test
  const TEST_CODE = '999999'
  await admin
    .from('sessions')
    .update({
      session_code: TEST_CODE,
      session_code_expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
    })
    .eq('id', ctx.attendanceSessionId)
  info(`Session code set: ${TEST_CODE} (expires +5min)`)

  // -------- TEST 1: mobile_login --------
  section('TEST 1: mobile_login')

  let res = await api('/auth/login', {
    body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
  })
  if (res.status !== 200 || !res.data.access_token) {
    fail('Login', `${res.status} ${JSON.stringify(res.data)}`)
    return
  }
  pass('Login', `200, JWT received, must_change_password=${res.data.must_change_password}`)
  const jwt = res.data.access_token
  const authHeader = { Authorization: `Bearer ${jwt}` }

  // -------- TEST 2: mobile_attendance_submit (positive) --------
  section('TEST 2: mobile_attendance_submit (positive)')

  const sessionInfo = sessions[0]
  res = await api('/attendance/submit', {
    headers: authHeader,
    body: JSON.stringify({
      session_id: ctx.attendanceSessionId,
      session_code: TEST_CODE,
      latitude: sessionInfo.location_lat,
      longitude: sessionInfo.location_lng,
      is_mock_location: false,
      device_model: 'SmokeTest-Node',
      device_os: process.platform,
    }),
  })
  // Status valid: 'hadir' (on-time) atau 'terlambat' (late but accepted).
  // Keduanya berarti server sukses insert attendance + trigger audit `mobile_attendance_submit`.
  if (res.status === 201 && (res.data.status === 'hadir' || res.data.status === 'terlambat')) {
    pass(
      'Attendance positive',
      `201, status=${res.data.status}, distance=${res.data.distance_meters}m, is_location_valid=${res.data.is_location_valid}`
    )
  } else {
    fail('Attendance positive', `${res.status} ${JSON.stringify(res.data)}`)
  }

  // Hapus row supaya layer 4 (duplicate check) tidak block test berikutnya
  await admin
    .from('attendances')
    .delete()
    .eq('session_id', ctx.attendanceSessionId)
    .eq('student_id', profile.id)
  info('Attendance row deleted (allow next test)')

  // -------- TEST 3: mock_location_detected (negative, expect 403) --------
  section('TEST 3: mock_location_detected')

  res = await api('/attendance/submit', {
    headers: authHeader,
    body: JSON.stringify({
      session_id: ctx.attendanceSessionId,
      session_code: TEST_CODE,
      latitude: sessionInfo.location_lat,
      longitude: sessionInfo.location_lng,
      is_mock_location: true,
      device_model: 'SmokeTest-Node',
    }),
  })
  if (res.status === 403) {
    pass('Mock GPS rejected', `403 (expected) — ${res.data.error}`)
  } else {
    fail('Mock GPS rejection', `expected 403, got ${res.status} ${JSON.stringify(res.data)}`)
  }

  // -------- TEST 4: mobile_leave_request_submit --------
  section('TEST 4: mobile_leave_request_submit')

  res = await api('/leave-requests/submit', {
    headers: authHeader,
    body: JSON.stringify({
      session_id: ctx.leaveSessionId,
      type: 'sakit',
      reason: 'Smoke test otomatis - tidak bisa hadir karena demam (Node.js script)',
    }),
  })
  if (res.status === 201 && res.data.id) {
    pass('Leave request', `201, id=${res.data.id.slice(0, 8)}..., status=${res.data.status}`)
  } else {
    fail('Leave request', `${res.status} ${JSON.stringify(res.data)}`)
  }

  // -------- TEST 5: mobile_face_register --------
  section('TEST 5: mobile_face_register')

  // Generate dummy 192-d normalized vector (magnitude=1)
  const vec = Array.from({ length: 192 }, () => Math.random() * 2 - 1)
  const mag = Math.sqrt(vec.reduce((s, v) => s + v * v, 0))
  const normalized = vec.map((v) => Number((v / mag).toFixed(6)))

  res = await api('/face/register', {
    headers: authHeader,
    body: JSON.stringify({ embedding: normalized }),
  })
  if (res.status === 201 && res.data.embedding_hash) {
    pass('Face register', `201, hash=${res.data.embedding_hash.slice(0, 16)}...`)
  } else {
    fail('Face register', `${res.status} ${JSON.stringify(res.data)}`)
  }

  // -------- TEST 6: mobile_change_password (roundtrip) --------
  section('TEST 6: mobile_change_password (roundtrip)')

  // Forward: default → NEW_PASSWORD
  res = await api('/auth/change-password', {
    headers: authHeader,
    body: JSON.stringify({ newPassword: NEW_PASSWORD, confirmPassword: NEW_PASSWORD }),
  })
  if (res.status === 200 && res.data.success) {
    pass('Change password forward', `200, password set to TestSmoke***`)
    ctx.passwordChanged = true
  } else {
    fail('Change password forward', `${res.status} ${JSON.stringify(res.data)}`)
  }

  // Revert: NEW_PASSWORD → default (via re-login)
  if (ctx.passwordChanged) {
    const reLogin = await api('/auth/login', {
      body: JSON.stringify({ email: TEST_EMAIL, password: NEW_PASSWORD }),
    })
    if (reLogin.status !== 200) {
      fail('Re-login (after password change)', `${reLogin.status} ${JSON.stringify(reLogin.data)}`)
    } else {
      const revertRes = await api('/auth/change-password', {
        headers: { Authorization: `Bearer ${reLogin.data.access_token}` },
        body: JSON.stringify({ newPassword: TEST_PASSWORD, confirmPassword: TEST_PASSWORD }),
      })
      if (revertRes.status === 200 && revertRes.data.success) {
        pass('Change password revert', `200, password back to default`)
        ctx.passwordChanged = false // safe to skip warning
      } else {
        fail(
          'Change password revert',
          `${revertRes.status} ${JSON.stringify(revertRes.data)} — MANUAL RESET PERLU`
        )
      }
    }
  }

  // -------- VERIFY: audit_logs forensic trail --------
  section('VERIFY: audit_logs forensic trail (BUG-011 fix)')

  // Filter row baru sejak baselineTime, action mobile_* atau mock_location_detected
  const { data: newLogs, error: logsError } = await admin
    .from('audit_logs')
    .select('action, user_id, ip_address, details')
    .gte('created_at', ctx.baselineTime)
    .or('action.like.mobile_%,action.eq.mock_location_detected')
    .order('created_at', { ascending: true })

  if (logsError) {
    fail('Query audit_logs', logsError.message)
    return
  }

  const logs = newLogs || []
  info(`Total new audit logs: ${logs.length}`)

  const stats = {
    total: logs.length,
    with_user_id: logs.filter((l) => l.user_id).length,
    with_ip: logs.filter((l) => l.ip_address).length,
    with_ua: logs.filter((l) => l.details?.user_agent).length,
  }

  if (
    stats.total > 0 &&
    stats.with_user_id === stats.total &&
    stats.with_ip === stats.total &&
    stats.with_ua === stats.total
  ) {
    pass(
      'Forensic trail complete',
      `${stats.total}/${stats.total} rows with user_id+ip_address+user_agent (100%)`
    )
  } else {
    fail(
      'Forensic trail incomplete',
      `user_id ${stats.with_user_id}/${stats.total}, ip ${stats.with_ip}/${stats.total}, ua ${stats.with_ua}/${stats.total}`
    )
  }

  // Per-action breakdown
  const byAction = {}
  for (const l of logs) {
    byAction[l.action] = (byAction[l.action] || 0) + 1
  }
  info('Action breakdown:')
  for (const [action, count] of Object.entries(byAction).sort()) {
    info(`  ${action}: ${count}`)
  }
}

// =====================================================
// Run
// =====================================================

const startTime = Date.now()
main()
  .catch((err) => {
    log(`\n${c.red}FATAL: ${err.message}${c.reset}`)
    console.error(err)
    failed++
    failures.push(`FATAL: ${err.message}`)
  })
  .finally(async () => {
    await cleanup()

    const duration = ((Date.now() - startTime) / 1000).toFixed(1)
    log(`\n${c.bold}━━━ SUMMARY ━━━${c.reset}`)
    log(`  ${c.green}✓ Passed: ${passed}${c.reset}`)
    if (failed > 0) {
      log(`  ${c.red}✗ Failed: ${failed}${c.reset}`)
      log(`\n${c.red}FAILURES:${c.reset}`)
      for (const f of failures) log(`  ${c.red}- ${f}${c.reset}`)
    }
    info(`Duration: ${duration}s`)

    if (failed === 0) {
      log(
        `\n${c.bold}${c.green}✓ BUG-011 FIX VERIFIED${c.reset}: semua mobile audit log punya user_id, ip_address, user_agent.`
      )
      process.exit(0)
    } else {
      log(`\n${c.bold}${c.red}✗ SMOKE TEST FAILED${c.reset}`)
      process.exit(1)
    }
  })
