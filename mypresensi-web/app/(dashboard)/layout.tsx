// app/(dashboard)/layout.tsx
// Layout bersama untuk semua halaman dashboard (admin/dosen).
// Berisi: Sidebar kiri + Top header bar + konten kanan.
// Server Component — validasi session di sini.

import { redirect } from 'next/navigation'
import { createClient, createAdminClient } from '@/lib/supabase/server'
import Sidebar from '@/components/layout/sidebar'
import TopBar from '@/components/layout/topbar'
import { SidebarProvider } from '@/components/layout/sidebar-provider'
import AiChatWidget from '@/components/ai/ai-chat-widget'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  // Gunakan admin client untuk fetch profile (bypass RLS)
  // Aman karena user sudah terverifikasi via getUser() di atas
  const adminClient = createAdminClient()
  const { data: profile } = await adminClient
    .from('profiles')
    .select('id, full_name, nim_nip, role, avatar_url, must_change_password')
    .eq('id', user.id)
    .single()

  // Jika belum ganti password, paksa ke halaman change-password
  if (profile?.must_change_password) {
    redirect('/change-password')
  }

  return (
    <SidebarProvider>
      <div className="flex h-screen overflow-hidden bg-background">
        {/* Skip-to-content untuk keyboard user (WCAG 2.1) */}
        <a href="#main-content" className="skip-to-content">
          Lewati ke konten utama
        </a>

        {/* Sidebar kiri — desktop static, mobile slide-in drawer */}
        <Sidebar profile={profile} />

        {/* Konten kanan */}
        <div className="flex flex-col flex-1 overflow-hidden min-w-0">
          <TopBar profile={profile} />
          <main
            id="main-content"
            tabIndex={-1}
            className="flex-1 overflow-y-auto p-4 md:p-6"
          >
            {children}

            {/* Footer */}
            <footer className="mt-8 pt-4 pb-2 border-t border-border">
              <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-1 text-xs text-text-secondary">
                <p>© {new Date().getFullYear()} MyPresensi — TRPL Politeknik Pertanian Negeri Samarinda</p>
                <p>v1.0.0</p>
              </div>
            </footer>
          </main>
        </div>
        <AiChatWidget />
      </div>
    </SidebarProvider>
  )
}
