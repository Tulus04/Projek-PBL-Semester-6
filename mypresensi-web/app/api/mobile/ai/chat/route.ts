// app/api/mobile/ai/chat/route.ts
// Endpoint AI Chat mobile mahasiswa — Bearer auth + rate limit + audit eksplisit.
// SECURITY: hanya return data mahasiswa yang sedang login, prompt user tidak disimpan mentah.

import { NextRequest } from 'next/server'
import { generateText } from 'ai'
import { google } from '@ai-sdk/google'
import { z } from 'zod'
import { authenticateRequest, errorResponse } from '../../_lib/auth'
import { logAudit } from '@/lib/audit-logger'
import { MOBILE_SYSTEM_PROMPT } from '@/lib/ai/prompts'
import { buildMobileAiContext, checkAiRateLimit } from '@/lib/ai/tools'

const ChatSchema = z.object({
  message: z.string().trim().min(1, 'Pertanyaan tidak boleh kosong.').max(1000, 'Pertanyaan maksimal 1000 karakter.'),
})

export async function POST(req: NextRequest) {
  try {
    if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
      return errorResponse('AI belum dikonfigurasi. Hubungi admin prodi.', 503)
    }

    const { user, error, status } = await authenticateRequest(req)
    if (error || !user) return errorResponse(error ?? 'Sesi tidak valid.', status)

    const parsed = ChatSchema.safeParse(await req.json())
    if (!parsed.success) {
      return errorResponse(parsed.error.issues[0]?.message ?? 'Format pertanyaan tidak valid.', 400)
    }

    const rateLimit = await checkAiRateLimit(user.id, '/api/mobile/ai/chat')
    if (!rateLimit.allowed) return errorResponse(rateLimit.message ?? 'Terlalu banyak permintaan.', 429)

    const context = await buildMobileAiContext({ userId: user.id })
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null

    const result = await generateText({
      model: google('gemini-2.5-flash'),
      system: `${MOBILE_SYSTEM_PROMPT}\n\n${context}`,
      prompt: parsed.data.message,
      temperature: 0.25,
      maxOutputTokens: 650,
    })

    await logAudit({
      action: 'ai_chat',
      userId: user.id,
      ipAddress,
      details: {
        surface: 'mobile',
        role: 'mahasiswa',
        prompt_length: parsed.data.message.length,
        response_length: result.text.length,
        user_agent: req.headers.get('user-agent') ?? null,
      },
    })

    return Response.json({ reply: result.text })
  } catch (err) {
    console.error('[AI_CHAT_MOBILE]', err)
    return errorResponse('Asisten AI sedang tidak tersedia. Silakan coba lagi sebentar.', 500)
  }
}
