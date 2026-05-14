-- mypresensi-web/supabase/migrations/005_mobilefacenet_threshold.sql
-- Update threshold face recognition agar sesuai dengan MobileFaceNet (TFLite, 192-d).
--
-- Threshold lama (0.75) didasarkan pada heuristic landmark embedding yang
-- sudah ditinggalkan di v1.1. MobileFaceNet menghasilkan embedding identitas
-- dengan distribusi berbeda — threshold ~0.65 dianggap reliable per literatur
-- (LFW benchmark: genuine pair ~0.7-0.8, impostor pair <0.5).
--
-- Mobile app default = 0.65 (lihat FaceEmbeddingService.defaultThreshold).
-- Setting ini dipakai server untuk komputasi anchor / monitoring saja.

UPDATE settings
SET value = '0.65',
    description = 'Batas minimum cosine similarity untuk match wajah (MobileFaceNet 192-d, sesuai LFW benchmark)',
    updated_at = NOW()
WHERE key = 'face_confidence_threshold';

-- Insert kalau belum ada (idempotent)
INSERT INTO settings (key, value, description) VALUES
  ('face_confidence_threshold', '0.65', 'Batas minimum cosine similarity untuk match wajah (MobileFaceNet 192-d, sesuai LFW benchmark)')
ON CONFLICT (key) DO NOTHING;
