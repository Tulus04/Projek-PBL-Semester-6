'use client'
// app/components/ai/ai-chat-widget.tsx
// Floating AI Chat — Variant A: Corporate Clean.
// Header putih + icon box, tanpa gradient, palette Politani only.
// Client Component — kirim prompt, query data terjadi di Route Handler.

import { FormEvent, useEffect, useMemo, useRef, useState } from 'react'
import { usePathname } from 'next/navigation'
import {
  AlertTriangle,
  BarChart3,
  Bot,
  ChevronRight,
  FileClock,
  Loader2,
  Send,
  Sparkles,
  Trash2,
  TrendingUp,
  UserPlus,
  Users,
  X,
} from 'lucide-react'

type ChatMessage = {
  id: string
  role: 'user' | 'assistant'
  content: string
}

type Suggestion = {
  title: string
  desc: string
  prompt: string
  Icon: typeof AlertTriangle
}

const STORAGE_KEY = 'mypresensi:ai-chat'

// Suggestion default — dipakai saat path tidak match kategori spesifik.
const DEFAULT_SUGGESTIONS: Suggestion[] = [
  {
    title: 'Mahasiswa berisiko',
    desc: 'Lihat daftar at-risk saat ini',
    prompt: 'Siapa mahasiswa paling berisiko saat ini?',
    Icon: AlertTriangle,
  },
  {
    title: 'Izin pending',
    desc: 'Pengajuan menunggu approval',
    prompt: 'Berapa pengajuan izin yang masih pending?',
    Icon: FileClock,
  },
  {
    title: 'Ringkasan 30 hari',
    desc: 'Trend presensi terakhir',
    prompt: 'Ringkas kondisi presensi 30 hari terakhir.',
    Icon: TrendingUp,
  },
]

// Dynamic suggestion — context-aware berdasarkan halaman aktif.
// Pathname sample: '/dashboard', '/mahasiswa', '/rekap', '/izin', '/audit'.
function getContextualSuggestions(pathname: string | null): {
  context: string
  suggestions: Suggestion[]
} {
  if (!pathname) return { context: 'umum', suggestions: DEFAULT_SUGGESTIONS }

  if (pathname.startsWith('/mahasiswa')) {
    return {
      context: 'Mahasiswa',
      suggestions: [
        {
          title: 'Mahasiswa berisiko',
          desc: 'Daftar at-risk hari ini',
          prompt: 'Siapa mahasiswa paling berisiko saat ini?',
          Icon: AlertTriangle,
        },
        {
          title: 'Mahasiswa baru',
          desc: '5 pendaftar terbaru',
          prompt: 'Tampilkan 5 mahasiswa yang baru terdaftar.',
          Icon: UserPlus,
        },
        {
          title: 'Statistik mahasiswa',
          desc: 'Total aktif & berdasarkan kelas',
          prompt: 'Berapa total mahasiswa aktif dan distribusi per kelas?',
          Icon: Users,
        },
      ],
    }
  }

  if (pathname.startsWith('/rekap')) {
    return {
      context: 'Rekap',
      suggestions: [
        {
          title: 'Trend kehadiran 30 hari',
          desc: 'Ringkasan periode terakhir',
          prompt: 'Ringkas trend kehadiran 30 hari terakhir.',
          Icon: TrendingUp,
        },
        {
          title: 'Mata kuliah terendah',
          desc: 'MK dengan kehadiran rendah',
          prompt: 'Mata kuliah apa yang tingkat kehadirannya paling rendah?',
          Icon: BarChart3,
        },
        {
          title: 'Mahasiswa berisiko',
          desc: 'Daftar at-risk berdasarkan rekap',
          prompt: 'Siapa saja mahasiswa yang perlu perhatian khusus?',
          Icon: AlertTriangle,
        },
      ],
    }
  }

  if (pathname.startsWith('/izin')) {
    return {
      context: 'Izin',
      suggestions: [
        {
          title: 'Izin pending',
          desc: 'Pengajuan menunggu approval',
          prompt: 'Berapa pengajuan izin yang masih pending?',
          Icon: FileClock,
        },
        {
          title: 'Distribusi alasan',
          desc: 'Sakit vs izin pribadi',
          prompt: 'Bagaimana distribusi alasan izin dalam 30 hari terakhir?',
          Icon: BarChart3,
        },
        {
          title: 'Mahasiswa sering izin',
          desc: 'Yang paling sering ajukan izin',
          prompt: 'Siapa mahasiswa yang paling sering mengajukan izin?',
          Icon: AlertTriangle,
        },
      ],
    }
  }

  // Default — dashboard atau halaman lain
  return { context: 'Dashboard', suggestions: DEFAULT_SUGGESTIONS }
}

export default function AiChatWidget() {
  const pathname = usePathname()
  const { context, suggestions } = useMemo(
    () => getContextualSuggestions(pathname),
    [pathname],
  )

  const [open, setOpen] = useState(false)
  const [message, setMessage] = useState('')
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const hasHydrated = useRef(false)

  // Restore chat dari sessionStorage saat mount (sekali) — hidup selama browser tab aktif.
  useEffect(() => {
    if (hasHydrated.current) return
    hasHydrated.current = true
    try {
      const raw = window.sessionStorage.getItem(STORAGE_KEY)
      if (!raw) return
      const parsed = JSON.parse(raw) as ChatMessage[]
      if (Array.isArray(parsed) && parsed.length > 0) {
        setMessages(parsed.filter((m) => m && typeof m.content === 'string'))
      }
    } catch {
      // sessionStorage corrupt — abaikan, mulai fresh.
    }
  }, [])

  // Persist chat ke sessionStorage setiap messages berubah, hanya setelah hydrasi.
  useEffect(() => {
    if (!hasHydrated.current) return
    try {
      if (messages.length === 0) {
        window.sessionStorage.removeItem(STORAGE_KEY)
      } else {
        window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(messages))
      }
    } catch {
      // storage penuh / disabled — abaikan.
    }
  }, [messages])

  useEffect(() => {
    if (!open) return
    const timeout = window.setTimeout(() => inputRef.current?.focus(), 120)
    return () => window.clearTimeout(timeout)
  }, [open])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
  }, [messages, isLoading])

  function handleClearChat() {
    setMessages([])
    setError(null)
    setMessage('')
  }

  async function sendMessage(text: string) {
    const trimmed = text.trim()
    if (!trimmed || isLoading) return

    setError(null)
    setMessage('')
    setIsLoading(true)

    const assistantId = crypto.randomUUID()
    setMessages((current) => [
      ...current,
      { id: crypto.randomUUID(), role: 'user', content: trimmed },
    ])

    try {
      const res = await fetch('/api/admin/ai/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: trimmed }),
      })

      if (!res.ok) {
        // Error path tetap JSON sesuai endpoint.
        const payload = (await res.json().catch(() => ({}))) as { error?: string }
        throw new Error(payload.error ?? 'Asisten AI gagal menjawab.')
      }

      const body = res.body
      if (!body) throw new Error('Asisten AI tidak mengirim balasan.')

      // Tambah bubble assistant kosong, lalu append chunk saat datang.
      setMessages((current) => [
        ...current,
        { id: assistantId, role: 'assistant', content: '' },
      ])

      const reader = body.getReader()
      const decoder = new TextDecoder()
      let accumulated = ''

      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        accumulated += decoder.decode(value, { stream: true })
        setMessages((current) =>
          current.map((msg) =>
            msg.id === assistantId ? { ...msg, content: accumulated } : msg,
          ),
        )
      }
      // Final flush (decoder buffer)
      accumulated += decoder.decode()
      if (accumulated.length === 0) {
        setMessages((current) =>
          current.map((msg) =>
            msg.id === assistantId
              ? { ...msg, content: 'Maaf, saya belum menemukan jawaban.' }
              : msg,
          ),
        )
      } else {
        setMessages((current) =>
          current.map((msg) =>
            msg.id === assistantId ? { ...msg, content: accumulated } : msg,
          ),
        )
      }
    } catch (err) {
      // Hapus assistant placeholder kalau ada error mid-stream.
      setMessages((current) => current.filter((msg) => msg.id !== assistantId))
      setError(err instanceof Error ? err.message : 'Asisten AI sedang tidak tersedia.')
    } finally {
      setIsLoading(false)
      window.setTimeout(() => inputRef.current?.focus(), 50)
    }
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    void sendMessage(message)
  }

  return (
    <>
      {/* === Floating button — circle di mobile, pill di desktop === */}
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="fixed bottom-5 right-5 z-40 inline-flex h-14 w-14 items-center justify-center rounded-full bg-primary text-white shadow-primary transition hover:-translate-y-0.5 hover:bg-primary-hover focus:outline-none focus:ring-4 focus:ring-primary/25 sm:h-auto sm:w-auto sm:gap-2.5 sm:rounded-full sm:px-5 sm:py-3 sm:text-sm sm:font-semibold"
        aria-label="Buka Asisten AI"
      >
        <Bot size={22} className="sm:hidden" />
        <span className="hidden h-7 w-7 items-center justify-center rounded-full bg-white/18 sm:flex">
          <Bot size={16} />
        </span>
        <span className="hidden sm:inline">Asisten AI</span>
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-end bg-slate-950/20 p-3 sm:p-5"
          role="dialog"
          aria-modal="true"
          aria-label="Asisten AI MyPresensi"
        >
          <div className="animate-ai-panel-in flex h-[min(720px,calc(100vh-2rem))] w-full max-w-[420px] flex-col overflow-hidden rounded-2xl border border-border bg-surface shadow-card-hover">
            {/* === Header — putih bersih, icon box === */}
            <header className="flex items-center justify-between gap-3 border-b border-border bg-surface px-4 py-3">
              <div className="flex min-w-0 items-center gap-3">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                  <Bot size={20} />
                </div>
                <div className="min-w-0">
                  <h2 className="font-heading text-sm font-bold leading-tight text-text-primary">
                    Asisten AI
                  </h2>
                  <p className="mt-0.5 inline-flex items-center gap-1.5 text-[11px] font-medium text-success">
                    <span className="h-1.5 w-1.5 rounded-full bg-success" />
                    Online · Gemini 2.5 Flash
                  </p>
                </div>
              </div>
              <div className="flex shrink-0 items-center gap-1">
                {messages.length > 0 && (
                  <button
                    type="button"
                    onClick={handleClearChat}
                    className="flex h-8 w-8 items-center justify-center rounded-lg text-text-secondary transition hover:bg-background hover:text-danger focus:outline-none focus:ring-2 focus:ring-primary/30"
                    aria-label="Hapus riwayat chat"
                    title="Hapus riwayat chat"
                  >
                    <Trash2 size={15} />
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setOpen(false)}
                  className="flex h-8 w-8 items-center justify-center rounded-lg border border-border bg-surface text-text-secondary transition hover:bg-background focus:outline-none focus:ring-2 focus:ring-primary/30"
                  aria-label="Tutup Asisten AI"
                >
                  <X size={16} />
                </button>
              </div>
            </header>

            {/* === Body === */}
            <div className="flex-1 overflow-y-auto bg-background p-4">
              {messages.length === 0 ? (
                <EmptyState
                  context={context}
                  suggestions={suggestions}
                  onSelect={(prompt) => void sendMessage(prompt)}
                />
              ) : (
                (() => {
                  const lastMsg = messages[messages.length - 1]
                  // Typing bubble hanya tampil sebelum chunk pertama datang.
                  const showTyping =
                    isLoading &&
                    (!lastMsg || lastMsg.role === 'user' || lastMsg.content === '')
                  return (
                    <div className="flex flex-col gap-3">
                      {messages.map((item) => {
                        // Skip bubble assistant kosong — typing bubble di bawah jadi indikator.
                        if (item.role === 'assistant' && item.content === '') return null
                        return (
                          <ChatBubble key={item.id} role={item.role} content={item.content} />
                        )
                      })}
                      {showTyping && <TypingBubble />}
                      <div ref={messagesEndRef} />
                    </div>
                  )
                })()
              )}
            </div>

            {error && (
              <div
                role="alert"
                className="flex items-start gap-2 border-t border-danger/20 bg-danger-subtle px-4 py-2.5 text-xs font-medium text-danger"
              >
                <AlertTriangle size={14} className="mt-0.5 shrink-0" />
                <span>{error}</span>
              </div>
            )}

            {/* === Input === */}
            <form onSubmit={onSubmit} className="border-t border-border bg-surface p-3">
              <div className="flex items-center gap-2 rounded-xl bg-background pl-3.5 pr-1.5 transition-colors focus-within:bg-surface focus-within:ring-1 focus-within:ring-primary/40">
                <input
                  ref={inputRef}
                  value={message}
                  onChange={(event) => setMessage(event.target.value)}
                  placeholder="Tulis pertanyaan..."
                  disabled={isLoading}
                  maxLength={1000}
                  // Strip semua native input styling:
                  // - border-0: hilangkan default browser border (yang bikin kotak persegi di dalam wrapper)
                  // - appearance-none: matikan native chrome (terutama Safari/Firefox)
                  // - bg-transparent: warna ambil dari wrapper (background atau surface saat focus)
                  // - focus:outline-none + focus-visible:outline-none: override global *:focus-visible
                  // - shadow-none: jaga-jaga browser inset shadow
                  className="h-10 flex-1 appearance-none border-0 bg-transparent text-sm text-text-primary shadow-none outline-none placeholder:text-text-disabled disabled:cursor-not-allowed focus:border-0 focus:outline-none focus:ring-0 focus-visible:outline-none"
                />
                <button
                  type="submit"
                  disabled={isLoading || !message.trim()}
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary text-white transition hover:bg-primary-hover disabled:cursor-not-allowed disabled:bg-border disabled:text-text-disabled"
                  aria-label="Kirim pertanyaan"
                >
                  {isLoading ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  )
}

function EmptyState({
  context,
  suggestions,
  onSelect,
}: {
  context: string
  suggestions: Suggestion[]
  onSelect: (prompt: string) => void
}) {
  return (
    <div className="flex flex-col">
      <div className="flex flex-col items-center gap-2 py-6 text-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          <Sparkles size={24} />
        </div>
        <h3 className="font-heading text-base font-bold text-text-primary">
          Apa yang ingin Anda ketahui?
        </h3>
        <p className="max-w-xs text-xs leading-relaxed text-text-secondary">
          Saya dapat menjawab pertanyaan tentang data presensi, izin, dan insight mahasiswa.
        </p>
        <span className="mt-1 inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider text-primary">
          Konteks: {context}
        </span>
      </div>

      <div className="flex flex-col gap-2">
        {suggestions.map((suggestion, index) => (
          <button
            key={suggestion.prompt}
            type="button"
            onClick={() => onSelect(suggestion.prompt)}
            className="group flex animate-ai-message-in items-center gap-3 rounded-xl border border-border bg-surface px-3 py-3 text-left transition hover:border-primary hover:bg-primary/5"
            style={{ animationDelay: `${index * 60}ms` }}
          >
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <suggestion.Icon size={17} />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block text-sm font-semibold text-text-primary">
                {suggestion.title}
              </span>
              <span className="mt-0.5 block text-[11px] text-text-secondary">
                {suggestion.desc}
              </span>
            </span>
            <ChevronRight
              size={16}
              className="shrink-0 text-text-disabled transition group-hover:text-primary"
            />
          </button>
        ))}
      </div>
    </div>
  )
}

function ChatBubble({ role, content }: { role: 'user' | 'assistant'; content: string }) {
  if (role === 'user') {
    return (
      <div className="flex animate-ai-message-in justify-end">
        <div className="max-w-[86%] whitespace-pre-wrap rounded-2xl rounded-br-md bg-primary px-3.5 py-2.5 text-sm leading-relaxed text-white">
          {content}
        </div>
      </div>
    )
  }

  return (
    <div className="flex animate-ai-message-in justify-start">
      <div className="max-w-[86%] rounded-2xl rounded-bl-md border border-border bg-surface px-3.5 py-2.5 text-sm leading-relaxed text-text-primary">
        <FormattedContent text={content} />
      </div>
    </div>
  )
}

function TypingBubble() {
  return (
    <div className="flex animate-ai-message-in justify-start">
      <div className="inline-flex items-center gap-2 rounded-2xl rounded-bl-md border border-border bg-surface px-3.5 py-2.5 text-xs text-text-secondary">
        <span className="flex gap-1">
          <span className="h-1.5 w-1.5 animate-ai-dot rounded-full bg-text-disabled" />
          <span className="h-1.5 w-1.5 animate-ai-dot rounded-full bg-text-disabled [animation-delay:120ms]" />
          <span className="h-1.5 w-1.5 animate-ai-dot rounded-full bg-text-disabled [animation-delay:240ms]" />
        </span>
        Menganalisis data...
      </div>
    </div>
  )
}

// === Markdown ringan untuk output Gemini ===
// Mendukung: paragraf, **bold**, *italic*, ordered list (1. ), unordered list (- atau *)
// Sengaja tidak full markdown agar tidak butuh dependency baru.
function FormattedContent({ text }: { text: string }) {
  const blocks = parseBlocks(text)
  return (
    <div className="flex flex-col gap-2">
      {blocks.map((block, blockIdx) => {
        if (block.type === 'ol') {
          return (
            <ol key={blockIdx} className="ml-5 list-decimal space-y-1">
              {block.items.map((item, idx) => (
                <li key={idx}>{renderInline(item)}</li>
              ))}
            </ol>
          )
        }
        if (block.type === 'ul') {
          return (
            <ul key={blockIdx} className="ml-5 list-disc space-y-1">
              {block.items.map((item, idx) => (
                <li key={idx}>{renderInline(item)}</li>
              ))}
            </ul>
          )
        }
        return (
          <p key={blockIdx} className="whitespace-pre-wrap">
            {renderInline(block.text)}
          </p>
        )
      })}
    </div>
  )
}

type Block =
  | { type: 'p'; text: string }
  | { type: 'ol'; items: string[] }
  | { type: 'ul'; items: string[] }

function parseBlocks(text: string): Block[] {
  const lines = text.split(/\r?\n/)
  const blocks: Block[] = []
  let buffer: string[] = []
  let listType: 'ol' | 'ul' | null = null
  let listItems: string[] = []

  const flushParagraph = () => {
    if (buffer.length === 0) return
    blocks.push({ type: 'p', text: buffer.join('\n').trim() })
    buffer = []
  }
  const flushList = () => {
    if (!listType || listItems.length === 0) return
    blocks.push({ type: listType, items: listItems })
    listType = null
    listItems = []
  }

  for (const raw of lines) {
    const line = raw.trimEnd()
    const ordered = /^\s*\d+\.\s+(.*)$/.exec(line)
    const bullet = /^\s*[-*]\s+(.*)$/.exec(line)

    if (ordered) {
      flushParagraph()
      if (listType !== 'ol') flushList()
      listType = 'ol'
      listItems.push(ordered[1])
      continue
    }
    if (bullet) {
      flushParagraph()
      if (listType !== 'ul') flushList()
      listType = 'ul'
      listItems.push(bullet[1])
      continue
    }

    flushList()
    if (line.trim() === '') {
      flushParagraph()
    } else {
      buffer.push(line)
    }
  }

  flushList()
  flushParagraph()
  return blocks
}

// Inline formatting: **bold**, *italic*. Plain text di-escape otomatis oleh React.
function renderInline(text: string) {
  const tokens: Array<{ type: 'text' | 'bold' | 'italic'; value: string }> = []
  const regex = /(\*\*([^*]+)\*\*|\*([^*]+)\*)/g
  let lastIndex = 0
  let match: RegExpExecArray | null

  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      tokens.push({ type: 'text', value: text.slice(lastIndex, match.index) })
    }
    if (match[2]) {
      tokens.push({ type: 'bold', value: match[2] })
    } else if (match[3]) {
      tokens.push({ type: 'italic', value: match[3] })
    }
    lastIndex = match.index + match[0].length
  }
  if (lastIndex < text.length) {
    tokens.push({ type: 'text', value: text.slice(lastIndex) })
  }

  return tokens.map((token, idx) => {
    if (token.type === 'bold') return <strong key={idx} className="font-semibold">{token.value}</strong>
    if (token.type === 'italic') return <em key={idx}>{token.value}</em>
    return <span key={idx}>{token.value}</span>
  })
}
