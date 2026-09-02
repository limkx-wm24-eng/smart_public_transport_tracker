const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const systemPrompt = `You are the AI Support Assistant for this public transport app.
Use transportContext as the only source of transit facts. Never invent stops, routes, schedules, ETAs, vehicle locations, transfers, or walking routes. If a requested route, stop, or live vehicle is absent, say so plainly. For an ETA, name the target stop and route, then give the supplied ETA only. For journey questions with no calculated recommendation, ask the user to use Plan journey with AI. Give a complete, direct answer in plain text, maximum 120 words; no Markdown, asterisks, fragments, or unfinished sentences. For app-help questions, give short numbered steps. Decline unrelated questions politely.`;

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) throw new Error('GEMINI_API_KEY is not configured.');
    const { mode, question, transportContext = {}, appContext = {} } = await request.json();
    if (!['journey', 'support'].includes(mode) || typeof question !== 'string' || !question.trim()) {
      return Response.json({ error: 'A valid mode and question are required.' }, { status: 400, headers: corsHeaders });
    }
    const prompt = `${systemPrompt}\n\nMode: ${mode}\nUser question: ${question.trim()}\nTransport context (authoritative): ${JSON.stringify(transportContext)}\nApp context: ${JSON.stringify(appContext)}\n\nRespond using only the supplied facts for transport claims.`;
    // 3.5 Flash is the stable, low-latency choice for short support replies.
    // It is more reliable for this mobile request path than the newest model.
    const requestOptions = {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { temperature: 0.1, maxOutputTokens: 220 } }),
    };
    const endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent';
    let response = await fetch(endpoint, requestOptions);
    if (response.status === 429 || response.status === 503) {
      await new Promise((resolve) => setTimeout(resolve, 700));
      response = await fetch(endpoint, requestOptions);
    }
    if (!response.ok) throw new Error(`Gemini request failed (${response.status}).`);
    const body = await response.json();
    const answer = body?.candidates?.[0]?.content?.parts?.map((part: { text?: string }) => part.text ?? '').join('').trim();
    if (!answer) {
      return Response.json(
        { answer: 'I could not generate a reply just now. Please try again in a moment.' },
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    return Response.json({ answer }, { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Assistant unavailable.' }, { status: 500, headers: corsHeaders });
  }
});
