// Shared by the Netlify function and the local Express server.
// Clients only send meal text; the server decides the model, limits, and prompt,
// so the endpoint can't be used as a general-purpose Claude proxy.

export const MODEL = 'claude-haiku-5-5';

export const LIMITS = {
    description: 500,
    request: 300,
    name: 100,
    macroMax: 20000,
};

const MACRO_KEYS = ['calories', 'protein', 'carbs', 'fat', 'fiber'];

const GUIDANCE = 'The user wants a reasonable ballpark, not lab precision. ' +
    'Assume typical portions unless they say otherwise, and round to whole numbers.';

function fail(status, error) {
    return { status, body: { error } };
}

function cleanText(value, max) {
    if (typeof value !== 'string') return null;
    const text = value.trim();
    if (!text || text.length > max) return null;
    return text;
}

function cleanMacros(value) {
    if (!value || typeof value !== 'object') return null;
    const macros = {};
    for (const key of MACRO_KEYS) {
        const n = Number(value[key] ?? 0);
        if (!Number.isFinite(n) || n < 0 || n > LIMITS.macroMax) return null;
        macros[key] = n;
    }
    return macros;
}

function schema({ includeName, includeExplanation }) {
    const properties = {};
    const required = [];
    if (includeName) {
        properties.name = { type: 'string' };
        required.push('name');
    }
    for (const key of MACRO_KEYS) {
        properties[key] = { type: 'number' };
        required.push(key);
    }
    if (includeExplanation) {
        properties.explanation = { type: 'string' };
        required.push('explanation');
    }
    return { type: 'object', properties, required, additionalProperties: false };
}

/** Validates the client payload and turns it into a prompt + output schema. */
function buildTask(body) {
    if (!body || typeof body !== 'object') return { error: fail(400, 'Invalid request.') };

    if (body.type === 'estimate') {
        const description = cleanText(body.description, LIMITS.description);
        if (!description) {
            return { error: fail(400, `Describe the meal in 1-${LIMITS.description} characters.`) };
        }
        return {
            prompt: `Estimate the nutrition for this meal: "${description}"\n\n${GUIDANCE} Give it a short, plain meal name.`,
            schema: schema({ includeName: true, includeExplanation: false }),
        };
    }

    if (body.type === 'adjust') {
        const request = cleanText(body.request, LIMITS.request);
        if (!request) {
            return { error: fail(400, `Keep adjustments to 1-${LIMITS.request} characters.`) };
        }
        const macros = cleanMacros(body.macros);
        if (!macros) return { error: fail(400, 'Invalid macro values.') };
        const name = typeof body.name === 'string' ? body.name.trim().slice(0, LIMITS.name) : '';

        return {
            prompt: `Meal: ${name || 'Unnamed meal'}
Current estimate:
- Calories: ${macros.calories}
- Protein: ${macros.protein}g
- Carbs: ${macros.carbs}g
- Fat: ${macros.fat}g
- Fiber: ${macros.fiber}g

User adjustment: "${request}"

Recalculate the macros with this adjustment. ${GUIDANCE} In explanation, tell the user in one short sentence what changed, speaking to them as "you".`,
            schema: schema({ includeName: false, includeExplanation: true }),
        };
    }

    return { error: fail(400, 'Unknown request type.') };
}

/**
 * Handles an estimate/adjust request.
 * Returns { status, body } where body is either the macro result or { error }.
 */
export async function handleMacroRequest(body, apiKey) {
    const task = buildTask(body);
    if (task.error) return task.error;

    if (!apiKey) {
        console.error('ANTHROPIC_API_KEY is not set');
        return fail(500, 'The estimate service is not configured.');
    }

    let response;
    try {
        response = await fetch('https://api.anthropic.com/v1/messages', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
            },
            body: JSON.stringify({
                model: MODEL,
                max_tokens: 4000,
                output_config: {
                    effort: 'low',
                    format: { type: 'json_schema', schema: task.schema },
                },
                messages: [{ role: 'user', content: task.prompt }],
            }),
            signal: AbortSignal.timeout(45000),
        });
    } catch (err) {
        console.error('Anthropic request failed:', err);
        return fail(502, 'The estimate service is unavailable. Try again.');
    }

    if (!response.ok) {
        console.error('Anthropic error', response.status, await response.text().catch(() => ''));
        if (response.status === 429 || response.status === 529) {
            return fail(503, 'The estimate service is busy. Try again in a minute.');
        }
        return fail(502, 'The estimate service is unavailable. Try again.');
    }

    const message = await response.json();
    if (message.stop_reason === 'refusal') {
        return fail(422, "Couldn't estimate that meal. Try describing it differently.");
    }

    try {
        if (message.stop_reason === 'max_tokens') throw new Error('Output truncated');
        const text = (message.content || [])
            .filter(block => block.type === 'text')
            .map(block => block.text)
            .join('');
        const result = JSON.parse(text);
        const macros = cleanMacros(result);
        if (!macros) throw new Error('Out-of-range macros');

        const out = { ...macros };
        if (typeof result.name === 'string') out.name = result.name.slice(0, LIMITS.name);
        if (typeof result.explanation === 'string') out.explanation = result.explanation;
        return { status: 200, body: out };
    } catch (err) {
        console.error('Unreadable model output:', err);
        return fail(502, 'Got an unexpected response. Try again.');
    }
}
