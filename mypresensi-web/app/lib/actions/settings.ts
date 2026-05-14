'use server'
// app/lib/actions/settings.ts
// Server actions untuk manajemen pengaturan sistem.

import { revalidatePath } from 'next/cache'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

export interface SettingsFormState {
  error: string | null
  success: boolean
}

export async function updateSettingsAction(
  _prev: SettingsFormState,
  formData: FormData
): Promise<SettingsFormState> {
  const supabase = createAdminClient()

  // Collect all setting keys from the form
  const entries = Array.from(formData.entries())
  const settings = entries.filter(([key]) => key.startsWith('setting_'))

  try {
    for (const [key, value] of settings) {
      const settingKey = key.replace('setting_', '')
      const { error } = await supabase
        .from('settings')
        .update({ value: String(value), updated_at: new Date().toISOString() })
        .eq('key', settingKey)

      if (error) throw error
    }

    await logAudit({
      action: 'update_settings',
      details: Object.fromEntries(settings.map(([k, v]) => [k.replace('setting_', ''), v])),
    })

    revalidatePath('/settings')
    return { error: null, success: true }
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Gagal menyimpan pengaturan'
    return { error: message, success: false }
  }
}
