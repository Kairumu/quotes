import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";

export interface SentenceInput {
  id: string;
  text: string;
}

/**
 * Sends all sentences in a single Anthropic request and returns a map of
 * sentenceId → translatedText. Provides whole-chunk context for quality.
 */
export async function translateSentences(
  sentences: SentenceInput[],
  sourceLang: string,
  targetLang: string,
  apiKey: string
): Promise<Record<string, string>> {
  const client = new Anthropic({ apiKey });

  const sentenceMap: Record<string, string> = {};
  for (const s of sentences) {
    sentenceMap[s.id] = s.text;
  }

  const langHint =
    sourceLang === "auto"
      ? "the source language (auto-detect)"
      : sourceLang;

  const prompt =
    `Translate each sentence below from ${langHint} to ${targetLang}.\n` +
    `Return ONLY a valid JSON object where every key is an exact sentence ID ` +
    `from the input and every value is the translated sentence text.\n` +
    `Do not include markdown, code fences, explanations, or any extra text — ` +
    `only the raw JSON object.\n\n` +
    `Sentences:\n${JSON.stringify(sentenceMap, null, 2)}`;

  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 8192,
    messages: [{ role: "user", content: prompt }],
  });

  const block = response.content[0];
  if (block.type !== "text") {
    throw new Error(`Unexpected LLM response block type: ${block.type}`);
  }

  // Strip markdown code fences if the model wraps the JSON
  const raw = block.text
    .trim()
    .replace(/^```(?:json)?\s*\n?/, "")
    .replace(/\n?```\s*$/, "");

  let result: Record<string, string>;
  try {
    result = JSON.parse(raw) as Record<string, string>;
  } catch {
    logger.error("translateSentences: failed to parse LLM JSON response", { raw });
    throw new Error("LLM returned invalid JSON");
  }

  return result;
}
