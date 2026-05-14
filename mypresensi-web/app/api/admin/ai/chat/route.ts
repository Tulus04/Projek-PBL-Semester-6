// app/api/admin/ai/chat/route.ts
// Endpoint AI Chat web admin/dosen — auth cookie + role guard + rate limit + audit.
// SECURITY: prompt user tidak disimpan mentah di audit log.

import { NextRequest } from 'next/server'
import { generateText } from 'ai'
import { google } from '@ai-sdk/google'
import { z } from 'zod'
import { requireRole } from '@/lib/auth-guard'
import { logAudit } from '@/lib/audit-logger'
import { ADMIN_SYSTEM_PROMPT } from '@/lib/ai/prompts'
import { buildWebAiContext, checkAiRateLimit, type WebAiRole } from '@/lib/ai/tools'

const ChatSchema = z.object({
  message: z.string().trim().min(1, 'Pertanyaan tidak boleh kosong.').max(1000, 'Pertanyaan maksimal 1000 karakter.'),
})

export async function POST(req: NextRequest) {
  try {
    if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
      return Response.json(
        { error: 'AI belum dikonfigurasi. Tambahkan GOOGLE_GENERATIVE_AI_API_KEY di .env.local.' },
        { status: 503 }
      )
    }

    const currentUser = await requireRole(['admin', 'dosen'])
    const parsed = ChatSchema.safeParse(await req.json())

    if (!parsed.success) {
      return Response.json(
        { error: parsed.error.issues[0]?.message ?? 'Format pertanyaan tidak valid.' },
        { status: 400 }
      )
    }

    const rateLimit = await checkAiRateLimit(currentUser.id, '/api/admin/ai/chat')
    if (!rateLimit.allowed) {
      return Response.json({ error: rateLimit.message }, { status: 429 })
    }

    const role = currentUser.role as WebAiRole
    const context = await buildWebAiContext({ userId: currentUser.id, role })
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null

    const result = await generateText({
      model: google('gemini-2.5-flash'),
      system: `${ADMIN_SYSTEM_PROMPT}\n\n${context}`,
      prompt: parsed.data.message,
      temperature: 0.2,
      maxOutputTokens: 700,
    })

    await logAudit({
      action: 'ai_chat',
      userId: currentUser.id,
      ipAddress,
      details: {
        surface: 'web',
        role,
        prompt_length: parsed.data.message.length,
        response_length: result.text.length,
        user_agent: req.headers.get('user-agent') ?? null,
      },
    })

    return Response.json({ reply: result.text })
  } catch (error) {
    console.error('[AI_CHAT_WEB]', error)
    return Response.json(
      { error: 'Asisten AI sedang tidak tersedia. Silakan coba lagi sebentar.' },
      { status: 500 }
    )
  }
}
