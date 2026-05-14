// app/components/dashboard/recent-activity-feed.tsx
// Widget timeline aktivitas terbaru di dashboard admin.
// Render 15 audit_logs terbaru dengan icon variant per action + waktu relatif.
// Server Component (data sudah di-fetch dari Server Action di parent).

import Link from 'next/link'
import {
  LogIn, LogOut,
  PlayCircle, ClipboardCheck,
  Camera, FileText,
  UserCog, Shield,
  Settings, Download,
  Clock, ChevronRight, History,
} from 'lucide-react'
import EmptyState from '@/components/ui/empty-state'
import type { ActivityItem, ActivityIconType } from '@/lib/actions/recent-activity'

interface RecentActivityFeedProps {
  activities: ActivityItem[]
}

// Icon mapping per ActivityIconType
const ICON_MAP: Record<ActivityIconType, typeof LogIn> = {
  login: LogIn,
  logout: LogOut,
  session: PlayCircle,
  attendance: ClipboardCheck,
  face: Camera,
  leave: FileText,
  user: UserCog,
  security: Shield,
  settings: Settings,
  export: Download,
  default: Clock,
}

// Tier → CSS class untuk wrapper icon
const TIER_STYLE: Record<ActivityItem['tier'], string> = {
  success: 'bg-success/10 text-success',
  danger: 'bg-danger/10 text-danger',
  warning: 'bg-warning/10 text-warning',
  info: 'bg-primary/10 text-primary',
  neutral: 'bg-gray-100 text-text-secondary',
}

// Format waktu relatif singkat: "5m", "2j", "3h", atau tanggal
function formatRelative(iso: string): string {
  const date = new Date(iso)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffSec = Math.floor(diffMs / 1000)
  if (diffSec < 60) return 'Baru saja'
  const diffMin = Math.floor(diffSec / 60)
  if (diffMin < 60) return `${diffMin} menit lalu`
  const diffHour = Math.floor(diffMin / 60)
  if (diffHour < 24) return `${diffHour} jam lalu`
  const diffDay = Math.floor(diffHour / 24)
  if (diffDay < 7) return `${diffDay} hari lalu`
  return date.toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })
}

function ActivityRow({ activity }: { activity: ActivityItem }) {
  const Icon = ICON_MAP[activity.actionIcon] ?? Clock
  const iconClass = TIER_STYLE[activity.tier] ?? TIER_STYLE.neutral

  return (
    <div className="flex items-start gap-3 py-2.5 border-b border-border last:border-0">
      {/* Icon */}
      <div className={`flex-shrink-0 w-8 h-8 rounded-lg flex items-center justify-center ${iconClass}`}>
        <Icon size={14} />
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <p className="text-xs text-text-primary leading-relaxed">
          {activity.description}
        </p>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-[10px] uppercase tracking-wide font-bold text-text-secondary">
            {activity.actionLabel}
          </span>
          <span className="text-[10px] text-text-secondary">·</span>
          <span className="text-[10px] text-text-secondary">{formatRelative(activity.createdAt)}</span>
        </div>
      </div>
    </div>
  )
}

export default function RecentActivityFeed({ activities }: RecentActivityFeedProps) {
  return (
    <div className="card p-5 h-full flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between gap-3 mb-3">
        <div className="flex items-center gap-3">
          <div className="kpi-icon-box">
            <History size={18} />
          </div>
          <div>
            <h3 className="text-base font-bold font-heading text-text-primary leading-tight">
              Aktivitas Terbaru
            </h3>
            <p className="text-xs text-text-secondary">Audit log sistem</p>
          </div>
        </div>
      </div>

      {/* List atau empty state */}
      <div className="flex-1 overflow-y-auto -mx-1 px-1" style={{ maxHeight: 480 }}>
        {activities.length === 0 ? (
          <EmptyState
            icon={History}
            title="Belum ada aktivitas"
            description="Aktivitas user akan muncul di sini secara otomatis."
            size="compact"
          />
        ) : (
          activities.map(act => (
            <ActivityRow key={act.id} activity={act} />
          ))
        )}
      </div>

      {/* CTA Lihat Semua */}
      {activities.length > 0 && (
        <Link
          href="/audit"
          className="flex items-center justify-between rounded-xl bg-primary/5 hover:bg-primary/10 transition-colors px-4 py-2.5 text-sm font-semibold text-primary group mt-3"
        >
          <span>Lihat semua audit log</span>
          <ChevronRight size={16} className="group-hover:translate-x-0.5 transition-transform" />
        </Link>
      )}
    </div>
  )
}
