/* Fine Print web demo: the only server-side step. It holds the Gemini key and the prompts, and
   does exactly what the app's GeminiExtractor does: classify a document, or tag and quote the
   clauses in one chunk. It never judges anything. Every quote is checked against the document
   in the visitor's browser, and verdicts come from the cited rule packs there.

   Nothing is stored: no cache, no logs of document text. Each request is rate-limited per visitor. */

import { ALL_PARAMETER_NAMES, DOCUMENT_TYPES, DOCUMENT_TYPE_INSTRUCTIONS, PROMPT_VERSION, SPECS,
  extractionInstructions, typesFor } from "./catalog.js";

const MODEL = "gemini-3-flash-preview";
const ALLOWED_ORIGINS = ["https://lekanlawal1.github.io", "http://localhost:8790", "http://127.0.0.1:8790"];
const MAX_CHUNK = 45_000;          // characters; the page splits documents well under this
const SAMPLE = 3_000;              // characters used to classify (Prompts.sample)

const TYPE_SCHEMA = {
  type: "OBJECT",
  properties: { type: { type: "STRING", enum: DOCUMENT_TYPES }, confidence: { type: "NUMBER" } },
  required: ["type", "confidence"],
};
const CLAUSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    clauses: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          type: { type: "STRING", enum: SPECS.map((s) => s.type) },
          quote: { type: "STRING" },
          parameters: {
            type: "ARRAY",
            items: { type: "OBJECT", properties: { name: { type: "STRING", enum: ALL_PARAMETER_NAMES }, value: { type: "NUMBER" } },
              required: ["name", "value"] },
          },
        },
        required: ["type", "quote"],
      },
    },
  },
  required: ["clauses"],
};

function cors(origin) {
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin",
  };
}
const json = (body, status, origin) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...cors(origin) } });

class Truncated extends Error {}

async function gemini(env, system, prompt, schema) {
  const body = {
    system_instruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { temperature: 0, responseMimeType: "application/json", responseSchema: schema,
      thinkingConfig: { thinkingLevel: "low" } },
  };
  let last = "Gemini did not answer";
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
      body: JSON.stringify(body) });
    if (res.status === 429 || res.status >= 500) {
      last = `Gemini returned HTTP ${res.status}`;
      await new Promise((r) => setTimeout(r, 1500 * 2 ** attempt));
      continue;
    }
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`Gemini returned HTTP ${res.status}`);
    if (data.promptFeedback?.blockReason) throw new Error(`Gemini declined this text (${data.promptFeedback.blockReason})`);
    const cand = data.candidates?.[0];
    if (!cand) throw new Error("Gemini returned an empty answer");
    if (cand.finishReason === "MAX_TOKENS") throw new Truncated();
    const text = (cand.content?.parts || []).filter((p) => !p.thought).map((p) => p.text || "").join("");
    try { return JSON.parse(text); } catch { throw new Error("Gemini's answer wasn't valid structured output"); }
  }
  throw new Error(last);
}

// Same filtering as GeminiExtractor.convert: known type, parameters this type declares, finite and >= 0.
function convert(c) {
  const spec = SPECS.find((s) => s.type === c.type);
  if (!spec || typeof c.quote !== "string") return null;
  const allowed = new Set(spec.parameters.map(([n]) => n));
  const params = {};
  for (const p of c.parameters || []) if (allowed.has(p.name) && Number.isFinite(p.value) && p.value >= 0) params[p.name] = p.value;
  return { type: c.type, quote: c.quote, params };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: cors(origin) });
    if (url.pathname === "/health") return json({ ok: true, model: MODEL, prompt: PROMPT_VERSION }, 200, origin);
    if (request.method !== "POST" || !["/classify", "/extract"].includes(url.pathname)) return json({ error: "not found" }, 404, origin);
    if (!ALLOWED_ORIGINS.includes(origin)) return json({ error: "This service only answers the Fine Print demo page." }, 403, origin);

    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const { success } = await env.RATE_LIMITER.limit({ key: ip });
    if (!success) return json({ error: "Too many requests in a minute. Wait a moment and try again." }, 429, origin);

    let body;
    try { body = await request.json(); } catch { return json({ error: "Send JSON." }, 400, origin); }
    try {
      if (url.pathname === "/classify") {
        const text = String(body.text || "").slice(0, SAMPLE);
        if (text.trim().length < 40) return json({ error: "Paste a little more of the document." }, 400, origin);
        const r = await gemini(env, DOCUMENT_TYPE_INSTRUCTIONS, `Document (beginning):\n${text}`, TYPE_SCHEMA);
        // scopes: which clause types count for each document type, so the page's scope check
        // uses the same list as the prompt instead of keeping its own copy
        return json({ type: DOCUMENT_TYPES.includes(r.type) ? r.type : "unknown",
          confidence: Math.min(Math.max(Number(r.confidence) || 0, 0), 1),
          scopes: Object.fromEntries(DOCUMENT_TYPES.map((t) => [t, typesFor(t)])) }, 200, origin);
      }
      const chunk = String(body.chunk || "");
      const documentType = DOCUMENT_TYPES.includes(body.documentType) ? body.documentType : "unknown";
      if (!chunk.trim() || chunk.length > MAX_CHUNK) return json({ error: "That section is empty or too long." }, 400, origin);
      try {
        const r = await gemini(env, extractionInstructions(documentType), `Document type: ${documentType}\n\nDocument text:\n${chunk}`, CLAUSE_SCHEMA);
        return json({ clauses: (r.clauses || []).map(convert).filter(Boolean) }, 200, origin);
      } catch (err) {
        if (err instanceof Truncated) return json({ truncated: true }, 200, origin);   // the page splits the chunk and retries
        throw err;
      }
    } catch (err) {
      return json({ error: err.message || "Something went wrong." }, 502, origin);
    }
  },
};
