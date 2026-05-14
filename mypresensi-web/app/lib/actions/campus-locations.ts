'use server'
// app/lib/actions/campus-locations.ts
// Server actions untuk CRUD lokasi kampus (preset geofencing sesi absensi).
// Admin mengelola daftar lokasi, dosen memilih lokasi saat buat sesi.

import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/server'
import { requireRole } from '@/lib/auth-guard'
import { logAudit } from '@/lib/audit-logger'
import { revalidatePath } from 'next/cache'

// ===========================
// Zod Schema
// ===========================
const campusLocationSchema = z.object({
  name: z.string().min(2, 'Nama lokasi minimal 2 karakter').max(100),
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  radius_meters: z.coerce.number().int().min(50, 'Radius minimal 50 meter').max(500, 'Radius maksimal 500 meter'),
})

// ===========================
// GET — Fetch semua lokasi aktif
// ===========================
export async function getCampusLocations() {
  const supabase = createAdminClient()

  const { data, error } = await supabase
    .from('campus_locations')
    .select('*')
    .eq('is_active', true)
    .order('is_default', { ascending: false })
    .order('name', { ascending: true })

  if (error) return []
  return data ?? []
}

// ===========================
// GET — Fetch lokasi default
// ===========================
export async function getDefaultCampusLocation() {
  const supabase = createAdminClient()

  const { data } = await supabase
    .from('campus_locations')
    .select('*')
    .eq('is_default', true)
    .eq('is_active', true)
    .single()

  return data
}

// ===========================
// CREATE — Tambah lokasi baru (admin only)
// ===========================
export async function addCampusLocationAction(formData: FormData) {
  await requireRole(['admin'])

  const raw = {
    name: formData.get('name') as string,
    latitude: formData.get('latitude') as string,
    longitude: formData.get('longitude') as string,
    radius_meters: formData.get('radius_meters') as string,
  }

  const parsed = campusLocationSchema.safeParse(raw)
  if (!parsed.success) {
    const msgs = Object.values(parsed.error.flatten().fieldErrors).flat()
    return { error: msgs[0] || 'Data tidak valid', success: false }
  }

  const supabase = createAdminClient()

  const { error: insertError } = await supabase.from('campus_locations').insert({
    name: parsed.data.name,
    latitude: parsed.data.latitude,
    longitude: parsed.data.longitude,
    radius_meters: parsed.data.radius_meters,
    is_default: false,
    is_active: true,
  })

  if (insertError) {
    return { error: `Gagal menambahkan lokasi: ${insertError.message}`, success: false }
  }

  await logAudit({
    action: 'create_campus_location',
    details: { name: parsed.data.name, latitude: parsed.data.latitude, longitude: parsed.data.longitude },
  })

  revalidatePath('/settings')
  revalidatePath('/sesi')
  return { error: null, success: true }
}

// ===========================
// UPDATE — Edit lokasi (admin only)
// ===========================
export async function updateCampusLocationAction(locationId: string, formData: FormData) {
  await requireRole(['admin'])

  const raw = {
    name: formData.get('name') as string,
    latitude: formData.get('latitude') as string,
    longitude: formData.get('longitude') as string,
    radius_meters: formData.get('radius_meters') as string,
  }

  const parsed = campusLocationSchema.safeParse(raw)
  if (!parsed.success) {
    const msgs = Object.values(parsed.error.flatten().fieldErrors).flat()
    return { error: msgs[0] || 'Data tidak valid', success: false }
  }

  const supabase = createAdminClient()

  const { error: updateError } = await supabase
    .from('campus_locations')
    .update({
      name: parsed.data.name,
      latitude: parsed.data.latitude,
      longitude: parsed.data.longitude,
      radius_meters: parsed.data.radius_meters,
    })
    .eq('id', locationId)

  if (updateError) {
    return { error: `Gagal mengubah lokasi: ${updateError.message}`, success: false }
  }

  await logAudit({
    action: 'update_campus_location',
    details: { location_id: locationId, name: parsed.data.name },
  })

  revalidatePath('/settings')
  revalidatePath('/sesi')
  return { error: null, success: true }
}

// ===========================
// DELETE — Hapus lokasi (admin only, tidak bisa hapus default)
// ===========================
export async function deleteCampusLocationAction(locationId: string) {
  await requireRole(['admin'])

  const supabase = createAdminClient()

  // Guard: tidak bisa hapus lokasi default
  const { data: location } = await supabase
    .from('campus_locations')
    .select('id, name, is_default')
    .eq('id', locationId)
    .single()

  if (!location) {
    return { error: 'Lokasi tidak ditemukan', success: false }
  }

  if (location.is_default) {
    return { error: 'Lokasi default tidak bisa dihapus. Ubah default ke lokasi lain terlebih dahulu.', success: false }
  }

  const { error: deleteError } = await supabase
    .from('campus_locations')
    .delete()
    .eq('id', locationId)

  if (deleteError) {
    return { error: `Gagal menghapus lokasi: ${deleteError.message}`, success: false }
  }

  await logAudit({
    action: 'delete_campus_location',
    details: { location_id: locationId, name: location.name },
  })

  revalidatePath('/settings')
  revalidatePath('/sesi')
  return { error: null, success: true }
}

// ===========================
// SET DEFAULT — Ubah lokasi default (admin only)
// ===========================
export async function setDefaultLocationAction(locationId: string) {
  await requireRole(['admin'])

  const supabase = createAdminClient()

  // Cek lokasi ada
  const { data: location } = await supabase
    .from('campus_locations')
    .select('id, name')
    .eq('id', locationId)
    .single()

  if (!location) {
    return { error: 'Lokasi tidak ditemukan', success: false }
  }

  // Unset semua default
  await supabase
    .from('campus_locations')
    .update({ is_default: false })
    .neq('id', locationId)

  // Set lokasi ini sebagai default
  const { error: updateError } = await supabase
    .from('campus_locations')
    .update({ is_default: true })
    .eq('id', locationId)

  if (updateError) {
    return { error: `Gagal mengubah default: ${updateError.message}`, success: false }
  }

  await logAudit({
    action: 'set_default_campus_location',
    details: { location_id: locationId, name: location.name },
  })

  revalidatePath('/settings')
  revalidatePath('/sesi')
  return { error: null, success: true }
}
