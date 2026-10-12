import { handleMacroRequest } from '../../lib/macro-api.mjs';

const MAX_BODY_BYTES = 10_000;

export default async (req) => {
    if (req.method !== 'POST') {
        return Response.json({ error: 'Method not allowed.' }, { status: 405 });
    }

    const raw = await req.text();
    if (raw.length > MAX_BODY_BYTES) {
        return Response.json({ error: 'Request too large.' }, { status: 413 });
    }

    let body;
    try {
        body = JSON.parse(raw);
    } catch {
        return Response.json({ error: 'Invalid JSON.' }, { status: 400 });
    }

    const result = await handleMacroRequest(body, process.env.ANTHROPIC_API_KEY);
    return Response.json(result.body, { status: result.status });
};

export const config = {
    path: '/api/chat',
    // Per-IP cap, enforced by Netlify before the function runs (requests over it get a 429).
    rateLimit: {
        windowLimit: 20,
        windowSize: 60,
        aggregateBy: ['ip', 'domain'],
    },
};
