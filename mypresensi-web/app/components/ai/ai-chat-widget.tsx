'use client'
// app/components/ai/ai-chat-widget.tsx
// Floating AI Chat untuk dashboard web admin/dosen.
// Client Component — hanya mengirim prompt, semua data query terjadi di Route Handler.

import { FormEvent, useRef, useState } from 'react'
import { Bot, Loader2, MessageCircle, Send, Sparkles, X } from 'lucide-react'

type ChatMessage = {
  id: string
  role: 'user' | 'assistant'
  content: string
}

const SUGGESTIONS = [
  'Siapa mahasiswa paling berisiko saat ini?',
  'Berapa pengajuan izin yang masih pending?',
  'Ringkas kondisi presensi 30 hari terakhir.',
]

export default function AiChatWidget() {
  const [open, setOpen] = useState(false)
  const [message, setMessage] = useState('')
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  async function sendMessage(text: string) {
    const trimmed = text.trim()
    if (!trimmed || isLoading) return

    setError(null)
    setMessage('')
    setIsLoading(true)

    const userMessage: ChatMessage = {
      id: crypto.randomUUID(),
      role: 'user',
      content: trimmed,
    }
    setMessages((current) => [...current, userMessage])

    try {
      const res = await fetch('/api/admin/ai/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: trimmed }),
      })

      const payload = await res.json() as { reply?: string; error?: string }
      if (!res.ok) throw new Error(payload.error ?? 'Asisten AI gagal menjawab.')

      setMessages((current) => [
        ...current,
        {
          id: crypto.randomUUID(),
          role: 'assistant',
          content: payload.reply ?? 'Maaf, saya belum menemukan jawaban.',
        },
      ])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Asisten AI sedang tidak tersedia.')
    } finally {
      setIsLoading(false)
      setTimeout(() => inputRef.current?.focus(), 50)
    }
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    void sendMessage(message)
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="fixed bottom-5 right-5 z-40 group inline-flex items-center gap-2 rounded-2xl bg-primary px-4 py-3 text-sm font-semibold text-white shadow-primary transition-all duration-200 hover:-translate-y-0.5 hover:bg-primary-hover focus:outline-none focus:ring-4 focus:ring-primary/25"
        aria-label="Buka Asisten AI"
      >
        <span className="relative flex h-8 w-8 items-center justify-center rounded-xl bg-white/15">
          <Sparkles size={17} />
          <span className="absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full bg-accent ring-2 ring-primary" />
        </span>
        <span className="hidden sm:inline">Asisten AI</span>
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-end justify-end bg-black/20 p-3 sm:p-5" role="dialog" aria-modal="true">
          <div className="flex h-[min(720px,calc(100vh-2rem))] w-full max-w-md flex-col overflow-hidden rounded-2xl border border-border bg-surface shadow-2xl">
            <div className="flex items-center justify-between border-b border-border bg-gradient-to-r from-primary to-primary-dark px-4 py-3 text-white">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/15">
                  <Bot size={20} />
                </div>
                <div>
                  <h2 className="font-heading text-sm font-bold">Asisten AI MyPresensi</h2>
                  <p className="text-xs text-white/75">Tanya data presensi, izin, dan insight dashboard.</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="rounded-lg p-2 text-white/80 transition hover:bg-white/10 hover:text-white focus:outline-none focus:ring-2 focus:ring-white/40"
                aria-label="Tutup Asisten AI"
              >
                <X size={18} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto bg-background/60 p-4">
              {messages.length === 0 ? (
                <div className="flex min-h-full flex-col items-center justify-center text-center">
                  <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
                    <MessageCircle size={24} />
                  </div>
                  <h3 className="font-heading text-base font-bold text-text-primary">Apa yang ingin Anda ketahui?</h3>
                  <p className="mt-1 max-w-xs text-sm text-text-secondary">
                    Saya bisa membantu merangkum data presensi, mahasiswa berisiko, dan pengajuan izin.
                  </p>
                  <div className="mt-5 flex flex-col gap-2 w-full">
                    {SUGGESTIONS.map((suggestion) => (
                      <button
                        key={suggestion}
                        type="button"
                        onClick={() => void sendMessage(suggestion)}
                        className="rounded-xl border border-border bg-surface px-3 py-2 text-left text-xs font-medium text-text-primary transition hover:border-primary/30 hover:bg-primary/5"
                      >
                        {suggestion}
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  {messages.map((item) => (
                    <div key={item.id} className={`flex ${item.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                      <div
                        className={`max-w-[85%] rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed shadow-sm ${
                          item.role === 'user'
                            ? 'bg-primary text-white rounded-br-md'
                            : 'bg-surface text-text-primary border border-border rounded-bl-md'
                        }`}
                      >
                        {item.content}
                      </div>
                    </div>
                  ))}
                  {isLoading && (
                    <div className="flex justify-start">
                      <div className="inline-flex items-center gap-2 rounded-2xl rounded-bl-md border border-border bg-surface px-3.5 py-2.5 text-sm text-text-secondary shadow-sm">
                        <Loader2 size={14} className="animate-spin" />
                        Menganalisis data...
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>

            {error && (
              <div className="border-t border-danger/20 bg-danger-subtle px-4 py-2 text-xs font-medium text-danger">
                {error}
              </div>
            )}

            <form onSubmit={onSubmit} className="flex items-center gap-2 border-t border-border bg-surface p-3">
              <input
                ref={inputRef}
                value={message}
                onChange={(event) => setMessage(event.target.value)}
                placeholder="Tulis pertanyaan..."
                disabled={isLoading}
                className="input-field flex-1"
                maxLength={1000}
              />
              <button
                type="submit"
                disabled={isLoading || !message.trim()}
                className="inline-flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-white transition hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-50"
                aria-label="Kirim pertanyaan"
              >
                {isLoading ? <Loader2 size={17} className="animate-spin" /> : <Send size={17} />}
              </button>
            </form>
          </div>
        </div>
      )}
    </>
  )
}
