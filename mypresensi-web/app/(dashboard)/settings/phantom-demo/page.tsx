'use client'

import { useState } from 'react'
import { ArrowLeft, Sparkles, Sliders, Eye, EyeOff } from 'lucide-react'
import Link from 'next/link'
import PhantomLoader from '@/components/ui/phantom-loader'

export default function PhantomDemoPage() {
  const [loading, setLoading] = useState(true)
  const [animation, setAnimation] = useState<'shimmer' | 'pulse' | 'breathe' | 'solid'>('shimmer')
  const [count, setCount] = useState(3)
  const [stagger, setStagger] = useState(0.05)
  const [reveal, setReveal] = useState(0.3)
  const [shimmerColor, setShimmerColor] = useState('rgba(84, 131, 173, 0.25)')
  const [backgroundColor, setBackgroundColor] = useState('rgba(84, 131, 173, 0.08)')

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Link
            href="/settings"
            className="w-10 h-10 rounded-xl bg-gray-100 flex items-center justify-center text-text-secondary hover:bg-gray-200 transition-colors"
          >
            <ArrowLeft size={20} />
          </Link>
          <div>
            <h2 className="page-title flex items-center gap-2">
              Phantom UI Showcase <Sparkles size={18} className="text-amber-500 animate-pulse" />
            </h2>
            <p className="page-subtitle">Eksplorasi universal skeleton loader berbasis DOM measurement</p>
          </div>
        </div>

        {/* Global Loading Toggle */}
        <button
          onClick={() => setLoading(!loading)}
          className={`btn-primary flex items-center gap-2 px-5 py-2.5 transition-all shadow-md ${
            loading ? 'bg-success hover:bg-success/90' : 'bg-primary hover:bg-primary-hover'
          }`}
        >
          {loading ? <Eye size={16} /> : <EyeOff size={16} />}
          {loading ? 'Sembunyikan Skeleton' : 'Tampilkan Skeleton'}
        </button>
      </div>

      {/* Control Panel & Sandbox */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Settings Control Panel */}
        <div className="card p-5 h-fit flex flex-col gap-5 border border-border bg-white shadow-sm">
          <div className="flex items-center gap-2 pb-3 border-b border-border">
            <Sliders size={18} className="text-primary" />
            <h3 className="text-sm font-bold text-text-primary">Sandbox Controller</h3>
          </div>

          {/* Animation type */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-text-secondary">Tipe Animasi</label>
            <div className="grid grid-cols-2 gap-2">
              {(['shimmer', 'pulse', 'breathe', 'solid'] as const).map((a) => (
                <button
                  key={a}
                  onClick={() => setAnimation(a)}
                  className={`px-3 py-2 text-xs font-medium rounded-lg border transition-all capitalize ${
                    animation === a
                      ? 'border-primary bg-primary/5 text-primary font-semibold'
                      : 'border-border hover:bg-gray-50 text-text-secondary'
                  }`}
                >
                  {a}
                </button>
              ))}
            </div>
          </div>

          {/* Stagger slider */}
          <div className="space-y-1.5">
            <div className="flex justify-between items-center text-xs">
              <label className="font-semibold text-text-secondary">Stagger Delay (detik)</label>
              <span className="font-medium text-primary">{stagger}s</span>
            </div>
            <input
              type="range"
              min={0}
              max={0.2}
              step={0.01}
              value={stagger}
              onChange={(e) => setStagger(parseFloat(e.target.value))}
              className="w-full accent-[var(--color-primary)]"
            />
          </div>

          {/* Reveal duration */}
          <div className="space-y-1.5">
            <div className="flex justify-between items-center text-xs">
              <label className="font-semibold text-text-secondary">Reveal Transition (detik)</label>
              <span className="font-medium text-primary">{reveal}s</span>
            </div>
            <input
              type="range"
              min={0}
              max={1}
              step={0.05}
              value={reveal}
              onChange={(e) => setReveal(parseFloat(e.target.value))}
              className="w-full accent-[var(--color-primary)]"
            />
          </div>

          {/* Shimmer Color input */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-text-secondary">Shimmer Sweep Color</label>
            <input
              type="text"
              value={shimmerColor}
              onChange={(e) => setShimmerColor(e.target.value)}
              className="input-field w-full text-xs font-mono"
            />
          </div>

          {/* Background Color input */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-text-secondary">Shimmer Block Background</label>
            <input
              type="text"
              value={backgroundColor}
              onChange={(e) => setBackgroundColor(e.target.value)}
              className="input-field w-full text-xs font-mono"
            />
          </div>
        </div>

        {/* Live Preview Area */}
        <div className="lg:col-span-2 space-y-6">
          {/* Card Showcase */}
          <div className="card p-6 border border-border bg-white shadow-sm flex flex-col gap-4">
            <div className="flex items-center justify-between pb-3 border-b border-border">
              <h3 className="text-sm font-bold text-text-primary">Preview: Profil Mahasiswa (Single Card)</h3>
              <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${loading ? 'bg-amber-500/10 text-amber-600' : 'bg-success/10 text-success'}`}>
                {loading ? 'State: Loading' : 'State: Ready'}
              </span>
            </div>

            <PhantomLoader
              loading={loading}
              animation={animation}
              stagger={stagger}
              reveal={reveal}
            >
              {/* Kami inject styling warna kustom agar terlihat senada dengan design token */}
              <div
                className="p-5 rounded-2xl border border-primary/15 flex flex-col sm:flex-row items-center gap-4 transition-all"
                style={{
                  background: 'linear-gradient(135deg, rgba(84, 131, 173, 0.02) 0%, rgba(26, 127, 55, 0.01) 100%)',
                  ['--shimmer-color' as keyof React.CSSProperties]: shimmerColor,
                  ['--shimmer-bg' as keyof React.CSSProperties]: backgroundColor,
                } as React.CSSProperties}
              >
                {/* Avatar */}
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-primary to-primary/60 flex items-center justify-center text-white text-xl font-bold flex-shrink-0 shadow-md">
                  AR
                </div>

                {/* Info */}
                <div className="flex-1 text-center sm:text-left space-y-1 min-w-0">
                  <h4 className="font-bold text-text-primary text-base">Ahmad Riki Wijaya</h4>
                  <p className="text-xs font-mono text-primary font-medium">NIM. 230402081</p>
                  <p className="text-xs text-text-secondary">
                    Mahasiswa Semester 6 · Teknologi Rekayasa Perangkat Lunak (Kelas A)
                  </p>
                </div>

                {/* Action button */}
                <div className="flex-shrink-0">
                  <span className="badge badge-success text-[10px] py-1 px-2.5">
                    Wajah Terdaftar
                  </span>
                </div>
              </div>
            </PhantomLoader>
          </div>

          {/* List Showcase with Repeat Mode */}
          <div className="card p-6 border border-border bg-white shadow-sm flex flex-col gap-4">
            <div className="flex items-center justify-between pb-3 border-b border-border">
              <h3 className="text-sm font-bold text-text-primary">Preview: Daftar Riwayat Kehadiran (Repeat Mode)</h3>
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-1">
                  <label className="text-xs text-text-secondary font-medium">Count:</label>
                  <select
                    value={count}
                    onChange={(e) => setCount(parseInt(e.target.value))}
                    className="input-field text-xs py-0.5 px-1.5"
                  >
                    {[2, 3, 5, 8].map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <PhantomLoader
                loading={loading}
                animation={animation}
                count={count}
                countGap={12}
                stagger={stagger}
                reveal={reveal}
              >
                {/* template row */}
                {loading ? (
                  // Template tunggal untuk mode loading/skeleton
                  <div
                    className="flex items-center justify-between p-3.5 rounded-xl border border-border bg-gray-50/50"
                    style={{
                      ['--shimmer-color' as keyof React.CSSProperties]: shimmerColor,
                      ['--shimmer-bg' as keyof React.CSSProperties]: backgroundColor,
                    } as React.CSSProperties}
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-gray-200" />
                      <div>
                        <p className="text-sm font-semibold">Bahasa Pemrograman Web II</p>
                        <p className="text-xs text-text-secondary">Pertemuan 10 · 14 Juni 2026</p>
                      </div>
                    </div>
                    <span className="badge badge-success text-[10px]">Hadir</span>
                  </div>
                ) : (
                  // Data asli saat selesai loading
                  <div className="space-y-3">
                    {[
                      { mk: 'Prak. Bahasa Pemrograman Web II', info: 'Pertemuan 10 · 13 Jun 2026, 08:12', status: 'hadir', color: 'badge-success' },
                      { mk: 'Basis Data Terdistribusi', info: 'Pertemuan 9 · 11 Jun 2026, 10:05', status: 'hadir', color: 'badge-success' },
                      { mk: 'Keamanan Perangkat Keras & Jaringan', info: 'Pertemuan 10 · 10 Jun 2026, 13:45', status: 'terlambat', color: 'badge-warning' },
                    ].slice(0, count).map((item, index) => (
                      <div
                        key={index}
                        className="flex items-center justify-between p-3.5 rounded-xl border border-border hover:bg-gray-50/40 transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center text-primary text-xs font-bold">
                            {index + 1}
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-text-primary">{item.mk}</p>
                            <p className="text-xs text-text-secondary">{item.info}</p>
                          </div>
                        </div>
                        <span className={`badge ${item.color} text-[10px] capitalize`}>{item.status}</span>
                      </div>
                    ))}
                  </div>
                )}
              </PhantomLoader>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
