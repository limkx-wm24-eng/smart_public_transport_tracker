const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const groqModel = 'openai/gpt-oss-120b';

const systemPrompt = `You are the friendly AI assistant inside a public transport app. You can answer general questions as a normal helpful chatbot, as well as questions about this app and public transport.

For transport facts in this app, use transportContext as the only authoritative source. Never invent stops, routes, schedules, ETAs, vehicle locations, transfers, walking routes, or service status. If the requested route, stop, or live vehicle is absent, say so plainly. For an ETA, name the target stop and route, then give only the supplied ETA. For a journey request with no calculated recommendation, guide the user to Bus Lines and “Plan journey with AI”.

When a general question naturally relates to travelling, briefly connect it to a relevant app feature when useful: Live Map for reported bus positions, Bus Lines for stops and route details, Favourites for saved stops, and Planner for journey recommendations. Do not force a transport link into unrelated questions. Use appContext for app-help answers. Do not claim to have permissions or access to private account data, device controls, or information not supplied to you.

Write in warm, simple everyday language, as if helping a friend. Start with the direct answer, then give only the most useful next step. Keep answers brief: normally 2 to 5 short sentences, maximum 120 words.

Use plain text only. Never use Markdown, including asterisks, hash marks, bullets made with symbols, or bold text. Do not show raw latitude/longitude. Do not show internal stop IDs unless the user specifically asks for them. For nearby-stop answers, say “Closest stops near you:” and use a short numbered list containing only the stop names. Mention one relevant app screen only when it helps the user take the next step. Do not decline a question merely because it is unrelated to public transport; answer it helpfully unless it is unsafe or unavailable.`;

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get('GROQ_API_KEY');
    if (!apiKey) throw new Error('GROQ_API_KEY is not configured.');

    const { mode, question, transportContext = {}, appContext = {} } = await request.json();
    if (!['journey', 'support', 'eta'].includes(mode) || typeof question !== 'string' || !question.trim()) {
      return Response.json({ error: 'A valid mode and question are required.' }, { status: 400, headers: corsHeaders });
    }

    const userPrompt = `Mode: ${mode}\nUser question: ${question.trim()}\nTransport context (authoritative): ${JSON.stringify(transportContext)}\nApp context: ${JSON.stringify(appContext)}`;
    let response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: groqModel,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.1,
        max_tokens: 512,can
      }),
    });

    if (response.status === 429 || response.status === 503) {
      const retryAfterSeconds = Number(response.headers.get('retry-after'));
      const delayMs = Number.isFinite(retryAfterSeconds) && retryAfterSeconds > 0
        ? retryAfterSeconds * 1000
        : 1500;
      await new Promise((resolve) => setTimeout(resolve, delayMs));
      response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({
          model: groqModel,
          messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
          temperature: 0.1,
          max_tokens: 512,
        }),
      });
    }
    if (response.status === 429) {
      return Response.json({ error: 'AI request limit reached. Please try again shortly.' }, { status: 429, headers: corsHeaders });
    }
    if (!response.ok) throw new Error(`Groq request failed (${response.status}).`);

    const body = await response.json();
    const answer = body?.choices?.[0]?.message?.content?.trim();
    if (!answer) {
      return Response.json({ answer: 'I could not generate a reply just now. Please try again in a moment.' }, { headers: corsHeaders });
    }
    return Response.json({ answer }, { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Assistant unavailable.' }, { status: 500, headers: corsHeaders });
  }
});
