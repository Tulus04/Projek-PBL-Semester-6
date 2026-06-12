// app/(dashboard)/loading.tsx
// Instant loading state (skeleton) untuk SEMUA halaman dashboard.
// Tanpa file ini, klik menu menunggu Server Component selesai fetch data
// sebelum halaman berpindah → navigasi terasa "stuck" di menu lama.
// Dengan loading.tsx, Next.js langsung menampilkan skeleton saat navigasi.

export default function DashboardLoading() {
  return (
    <div
      className="animate-pulse space-y-5"
      aria-busy="true"
      aria-label="Memuat halaman"
    >
      {/* Page title */}
      <div className="space-y-2">
        <div className="h-7 w-52 rounded-lg bg-slate-200/80" />
        <div className="h-4 w-80 max-w-full rounded-lg bg-slate-200/60" />
      </div>

      {/* KPI cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-28 rounded-2xl bg-slate-200/70" />
        ))}
      </div>

      {/* Main content block (table/list) */}
      <div className="space-y-3 rounded-2xl border border-slate-200/70 p-4">
        <div className="h-9 w-full max-w-sm rounded-lg bg-slate-200/70" />
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="h-12 w-full rounded-xl bg-slate-200/60" />
        ))}
      </div>
    </div>
  )
}
