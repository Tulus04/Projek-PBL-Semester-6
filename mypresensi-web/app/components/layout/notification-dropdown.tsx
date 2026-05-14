'use client'
// app/components/layout/notification-dropdown.tsx
// Dropdown notifikasi yang muncul saat bell icon diklik.
// Menampilkan daftar notifikasi, badge counter, dan aksi mark-as-read.
// Polling setiap 30 detik untuk update counter.

import { useState, useEffect, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import {
  Bell,
  Info,
  CheckCircle2,
  AlertTriangle,
  XCircle,
  CheckCheck,
} from 'lucide-react'
import {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
} from '@/lib/actions/notifications'
import type { NotificationItem } from '@/lib/actions/notifications'

// ==========================================
// HELPER: Waktu relatif (Bahasa Indonesia)
// ==========================================

function timeAgo(dateStr: string): string {
  const now = new Date()
  const date = new Date(dateStr)
  const diffMs = now.getTime() - date.getTime()
  const diffSec = Math.floor(diffMs / 1000)
  const diffMin = Math.floor(diffSec / 60)
  const diffHour = Math.floor(diffMin / 60)
  const diffDay = Math.floor(diffHour / 24)

  if (diffSec < 60) return 'Baru saja'
  if (diffMin < 60) return `${diffMin} menit lalu`
  if (diffHour < 24) return `${diffHour} jam lalu`
  if (diffDay < 7) return `${diffDay} hari lalu`
  return date.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })
}

// ==========================================
// HELPER: Icon berdasarkan tipe notifikasi
// ==========================================

function NotificationIcon({ type }: { type: string }) {
  const iconProps = { size: 16, strokeWidth: 2 }

  switch (type) {
    case 'success':
      return <CheckCircle2 {...iconProps} className="text-success flex-shrink-0" />
    case 'warning':
      return <AlertTriangle {...iconProps} className="text-warning flex-shrink-0" />
    case 'danger':
      return <XCircle {...iconProps} className="text-danger flex-shrink-0" />
    default:
      return <Info {...iconProps} className="text-primary flex-shrink-0" />
  }
}

// ==========================================
// KOMPONEN UTAMA
// ==========================================

export default function NotificationDropdown() {
  const [isOpen, setIsOpen] = useState(false)
  const [notifications, setNotifications] = useState<NotificationItem[]>([])
  const [unreadCount, setUnreadCount] = useState(0)
  const [isLoading, setIsLoading] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)
  const router = useRouter()

  // Fetch unread count (polling)
  const fetchUnreadCount = useCallback(async () => {
    const count = await getUnreadCount()
    setUnreadCount(count)
  }, [])

  // Fetch notifications saat dropdown dibuka
  const fetchNotifications = useCallback(async () => {
    setIsLoading(true)
    const { notifications: data } = await getNotifications(20)
    setNotifications(data)
    setIsLoading(false)
  }, [])

  // Polling setiap 30 detik untuk update badge counter
  useEffect(() => {
    fetchUnreadCount()
    const interval = setInterval(fetchUnreadCount, 30000)
    return () => clearInterval(interval)
  }, [fetchUnreadCount])

  // Fetch data saat dropdown dibuka
  useEffect(() => {
    if (isOpen) {
      fetchNotifications()
    }
  }, [isOpen, fetchNotifications])

  // Tutup dropdown saat klik di luar
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Handler: klik notifikasi
  const handleClickNotification = async (notification: NotificationItem) => {
    if (!notification.is_read) {
      await markAsRead(notification.id)
      setUnreadCount((prev) => Math.max(0, prev - 1))
      setNotifications((prev) =>
        prev.map((n) => (n.id === notification.id ? { ...n, is_read: true } : n))
      )
    }
    if (notification.href) {
      setIsOpen(false)
      router.push(notification.href)
    }
  }

  // Handler: tandai semua dibaca
  const handleMarkAllRead = async () => {
    await markAllAsRead()
    setUnreadCount(0)
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })))
  }

  return (
    <div ref={dropdownRef} className="relative">
      {/* Bell Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-9 h-9 rounded-xl flex items-center justify-center text-text-secondary hover:bg-primary/5 hover:text-primary transition-colors relative"
        aria-label="Notifikasi"
        id="notification-bell"
      >
        <Bell size={18} strokeWidth={1.75} />
        {unreadCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] rounded-full bg-danger text-white text-[10px] font-bold flex items-center justify-center px-1 leading-none">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>

      {/* Dropdown Panel */}
      {isOpen && (
        <div
          className="absolute right-0 top-full mt-2 w-[380px] bg-white rounded-2xl border border-border overflow-hidden z-50"
          style={{ boxShadow: '0 8px 32px rgba(0, 0, 0, 0.12)' }}
        >
          {/* Header */}
          <div className="flex items-center justify-between px-5 py-3.5 border-b border-border">
            <h3 className="text-sm font-bold text-text-primary">Notifikasi</h3>
            {unreadCount > 0 && (
              <button
                onClick={handleMarkAllRead}
                className="flex items-center gap-1.5 text-xs font-medium text-primary hover:text-primary-hover transition-colors"
              >
                <CheckCheck size={14} />
                Tandai Semua Dibaca
              </button>
            )}
          </div>

          {/* Content */}
          <div className="max-h-[400px] overflow-y-auto">
            {isLoading ? (
              <div className="flex items-center justify-center py-12">
                <div className="w-5 h-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
              </div>
            ) : notifications.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 px-6 text-center">
                <div className="w-12 h-12 rounded-2xl bg-primary/5 flex items-center justify-center mb-3">
                  <Bell size={24} className="text-text-disabled" />
                </div>
                <p className="text-sm text-text-secondary">Belum ada notifikasi.</p>
              </div>
            ) : (
              <div>
                {notifications.map((notif) => (
                  <button
                    key={notif.id}
                    onClick={() => handleClickNotification(notif)}
                    className={`w-full text-left px-5 py-3.5 flex gap-3 items-start hover:bg-background/60 transition-colors border-b border-border/50 last:border-b-0 ${
                      !notif.is_read ? 'bg-primary/[0.03]' : ''
                    }`}
                  >
                    {/* Icon */}
                    <div className="mt-0.5">
                      <NotificationIcon type={notif.type} />
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm leading-snug ${
                        notif.is_read ? 'text-text-secondary' : 'text-text-primary font-semibold'
                      }`}>
                        {notif.title}
                      </p>
                      <p className="text-xs text-text-secondary mt-0.5 line-clamp-2 leading-relaxed">
                        {notif.message}
                      </p>
                      <p className="text-[11px] text-text-disabled mt-1">
                        {timeAgo(notif.created_at)}
                      </p>
                    </div>

                    {/* Unread indicator */}
                    {!notif.is_read && (
                      <div className="mt-1.5 flex-shrink-0">
                        <div className="w-2 h-2 rounded-full bg-primary" />
                      </div>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Footer — jika ada notifikasi */}
          {notifications.length > 0 && (
            <div className="border-t border-border px-5 py-2.5">
              <p className="text-[11px] text-text-disabled text-center">
                Menampilkan {notifications.length} notifikasi terbaru
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
