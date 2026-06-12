import { NextResponse } from 'next/server'
import { createAdminClient } from '@/lib/supabase/server'

export async function GET() {
  const supabase = createAdminClient()
  
  const { data: sessionData, error } = await supabase
      .from('sessions')
      .select('course_id, topic, session_number, target_kelas, course:courses!course_id(name)')
      .limit(1)
      .single()

  return NextResponse.json({ sessionData, error })
}
