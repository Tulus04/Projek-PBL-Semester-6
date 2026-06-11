const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://ibnzsitiqgmrntkaqool.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlibnpzaXRpcWdtcm50a2Fxb29sIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTQ4MjIzNywiZXhwIjoyMDkxMDU4MjM3fQ.UF077nD6dcY8ncroTr7JwAHhABKSSn2nlGf05b4FQi0';

const supabase = createClient(supabaseUrl, supabaseKey);

async function test() {
  const { data, error } = await supabase
    .from('sessions')
    .select(`
      id, course_id, session_number, topic,
      started_at, ended_at, is_active,
      course:courses!sessions_course_id_fkey(
        code, name,
        dosen:profiles!courses_dosen_id_fkey(full_name)
      )
    `)
    .limit(3);

  if (error) {
    console.error('Error:', error);
  } else {
    console.log('Data:', JSON.stringify(data, null, 2));
  }
}

test();
