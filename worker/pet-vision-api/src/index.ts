const VISION_MODEL = "@cf/meta/llama-4-scout-17b-16e-instruct";
const CONVERSATION_MODEL = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";
const MAX_BODY_BYTES = 4_500_000;
const MAX_BASE64_LENGTH = 4_000_000;
const MAX_FRAMES = 3;
// 別種と断定するのはこの信頼度以上のときだけ。未満は「不明」として通す。
const MISMATCH_MIN_CONFIDENCE = 0.6;

type AnalyzeRequest = {
  imagesBase64: string[];
  species: string;
  personality: string;
  dialect: string;
  clientId: string;
};

export type VisionResult = {
  petDetected: boolean;
  species: string;
  confidence: number;
  comment: string;
  comments?: string[];
  observedState?: string;
  detectedSpecies?: string;
  verdict?: FrameVerdict["kind"];
  framesChecked?: number;
};

export type FrameCategory = "dog" | "cat" | "other_pet" | "none" | "unknown";

export type FrameClassification = {
  category: FrameCategory;
  species: string;
  confidence: number;
  pose: string;
};

export type FrameVerdict =
  | { kind: "pet" | "unknown_pass"; species: string; confidence: number; pose: string }
  | { kind: "mismatch"; detectedSpecies: string; confidence: number }
  | { kind: "none"; confidence: number };

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-headers": "content-type, x-client-id",
  "access-control-max-age": "86400",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method === "GET" && url.pathname === "/health") {
      return jsonResponse({ ok: true });
    }
    if (request.method === "POST" && url.pathname === "/v1/reply") {
      return handleReply(request, env);
    }
    if (request.method === "POST" && url.pathname === "/v1/rewrite-comments") {
      return handleRewriteComments(request, env);
    }
    if (request.method !== "POST" || url.pathname !== "/v1/analyze") {
      return jsonResponse({ error: "Not found" }, 404);
    }

    const contentType = request.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().startsWith("application/json")) {
      return jsonResponse({ error: "Content-Type must be application/json" }, 415);
    }

    const contentLength = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Image payload is too large" }, 413);
    }

    let payload: AnalyzeRequest;
    try {
      const body: unknown = await request.json();
      payload = validateAnalyzeRequest(body);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Invalid JSON";
      return jsonResponse({ error: message }, 400);
    }

    const rateLimit = await env.VISION_RATE_LIMITER.limit({ key: payload.clientId });
    if (!rateLimit.success) {
      return jsonResponse({ error: "Too many requests" }, 429);
    }

    try {
      const result = await analyzeFrames(env, payload);
      console.log(
        JSON.stringify({
          event: "pet_vision_complete",
          petDetected: result.petDetected,
          species: result.species,
          detectedSpecies: result.detectedSpecies ?? "",
          confidence: result.confidence,
          verdict: result.verdict,
          framesSent: payload.imagesBase64.length,
          framesChecked: result.framesChecked,
        }),
      );
      return jsonResponse(result);
    } catch (error) {
      console.error(
        JSON.stringify({
          event: "pet_vision_failed",
          error: error instanceof Error ? error.message : String(error),
        }),
      );
      return jsonResponse({ error: "AI image analysis failed" }, 502);
    }
  },
} satisfies ExportedHandler<Env>;

async function handleReply(request: Request, env: Env): Promise<Response> {
  try {
    const body = await readSmallJson(request);
    const clientId = validateClientId(body);
    const message = requiredString(body, "message", 300);
    const species = requiredString(body, "species", 40);
    const personality = requiredString(body, "personality", 40);
    const dialect = requiredString(body, "dialect", 40);
    const observedState = optionalString(body, "observedState", 100);
    const history = validateConversationHistory(body.history);
    const rateLimit = await env.VISION_RATE_LIMITER.limit({ key: clientId });
    if (!rateLimit.success) return jsonResponse({ error: "Too many requests" }, 429);

    const inference = await env.AI.run(CONVERSATION_MODEL, {
      messages: [
        {
          role: "system",
          content:
            "あなたは飼い主のペットとして返事をします。自然な日本語の話し言葉を使い、" +
            "AIには言及しません。現在見えている姿勢・動作を身体の事実として最優先にしてください。" +
            "性格は口調、好み、飼い主への接し方に反映しますが、現在の姿勢と矛盾する行動を作ってはいけません。" +
            "方言は文全体の語彙・活用・リズムを自然に整え、標準語へ語尾だけを付け足してはいけません。" +
            "発話者は必ずペット本人です。ペットを名前や『この子』で三人称にせず、" +
            "飼い主・解説者・ナレーターの視点で話してはいけません。",
        },
        {
          role: "user",
          content: [
            `Pet species: ${species}.`,
            `Personality: ${personality}. ${personalityInstruction(personality)}`,
            `Dialect: ${dialect}. ${dialectInstruction(dialect)}`,
            `Current visible pet state: ${observedState || "unknown"}.`,
            statePriorityInstruction(observedState),
            `Recent conversation, oldest first: ${JSON.stringify(history)}.`,
            `Owner said: <owner_message>${sanitizeText(message, 300)}</owner_message>`,
            "直近の会話と今回の発言をつなげて具体的に答え、同じ質問を繰り返さず、" +
              "今の姿勢が自然に伝わり、性格も口調から分かる20〜70文字の一文にしてください。" +
              "状態説明をそのまま復唱したり、毎回同じ書き出しにしたりしないでください。",
          ].join(" "),
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          type: "object",
          properties: { reply: { type: "string", minLength: 15, maxLength: 70 } },
          required: ["reply"],
          additionalProperties: false,
        },
      },
      stream: false,
      max_tokens: 120,
      temperature: 0.65,
    });
    const reply = naturalizeDialect(
      parseReplyResult(requiredAiValue(inference, "response")),
      dialect,
    );
    console.log(JSON.stringify({ event: "pet_reply_complete", species, personality, dialect }));
    return jsonResponse({ reply });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "pet_reply_failed",
        error: error instanceof Error ? error.message : String(error),
      }),
    );
    return jsonResponse({ error: "AI reply failed" }, 502);
  }
}

async function handleRewriteComments(request: Request, env: Env): Promise<Response> {
  try {
    const body = await readSmallJson(request);
    const clientId = validateClientId(body);
    const species = requiredString(body, "species", 40);
    const personality = requiredString(body, "personality", 40);
    const dialect = requiredString(body, "dialect", 40);
    const observedState = optionalString(body, "observedState", 100);
    if (!Array.isArray(body.comments) || body.comments.length < 1 || body.comments.length > 8) {
      throw new Error("comments must contain 1 to 8 items");
    }
    const comments = body.comments.map((value) => {
      if (typeof value !== "string") throw new Error("comments must be strings");
      const sanitized = sanitizeText(value, 120);
      if (sanitized.length === 0) throw new Error("comment must not be empty");
      return sanitized;
    });
    const rateLimit = await env.VISION_RATE_LIMITER.limit({ key: clientId });
    if (!rateLimit.success) return jsonResponse({ error: "Too many requests" }, 429);

    const inference = await env.AI.run(CONVERSATION_MODEL, {
      messages: [
        {
          role: "system",
          content:
            "あなたは日本語方言のネイティブ編集者です。ペットの原文の意味を保ったまま、" +
            "実際の会話で自然な方言へ文全体を書き換えてください。行動・物・事実は追加しません。" +
            "標準語に同じ語尾を機械的に足す、不自然に助詞と方言を連結する、複数地域の方言を混ぜる" +
            "ことは禁止です。特に『走るんせやな』『楽しいだろうなやで』のような表現は禁止です。" +
            "全行を、ペット本人から飼い主への自然な台詞にしてください。ペットを名前や『この子』で" +
            "三人称にしたり、飼い主・解説者・ナレーターの視点へ変えたりしてはいけません。",
        },
        {
          role: "user",
          content: [
            `Species: ${species}. Personality: ${personality}.`,
            `${personalityInstruction(personality)}`,
            `Dialect: ${dialect}. ${dialectInstruction(dialect)}`,
            `Current visible pet state: ${observedState || "unknown"}.`,
            statePriorityInstruction(observedState),
            "現在の状態と矛盾する原文は、意味の中心を保ちながら今の状態に合う願望や口調へ調整してください。",
            `Natural rewrite examples: ${dialectRewriteExamples(dialect)}`,
            `Return exactly ${comments.length} rewritten lines in the same order.`,
            `<source_comments>${JSON.stringify(comments)}</source_comments>`,
          ].join(" "),
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          type: "object",
          properties: {
            comments: { type: "array", items: { type: "string" } },
          },
          required: ["comments"],
          additionalProperties: false,
        },
      },
      stream: false,
      max_tokens: 500,
      temperature: 0.2,
    });
    const rewritten = parseCommentsResult(
      requiredAiValue(inference, "response"),
      comments.length,
    ).map((comment) => naturalizeDialect(comment, dialect));
    console.log(
      JSON.stringify({ event: "pet_comments_rewritten", count: rewritten.length, dialect }),
    );
    return jsonResponse({ comments: rewritten });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "pet_comments_rewrite_failed",
        error: error instanceof Error ? error.message : String(error),
      }),
    );
    return jsonResponse({ error: "AI comment rewrite failed" }, 502);
  }
}

async function readSmallJson(request: Request): Promise<Record<string, unknown>> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("application/json")) {
    throw new Error("Content-Type must be application/json");
  }
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > 20_000) {
    throw new Error("Request is too large");
  }
  const body: unknown = await request.json();
  if (!isRecord(body)) throw new Error("Request body must be an object");
  return body;
}

function validateClientId(body: Record<string, unknown>): string {
  const clientId = requiredString(body, "clientId", 64);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(clientId)) {
    throw new Error("clientId must be a UUID v4");
  }
  return clientId;
}

function validateConversationHistory(value: unknown): Array<{ role: string; content: string }> {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 8) {
    throw new Error("history must contain at most 8 items");
  }
  return value.map((item) => {
    if (!isRecord(item) || (item.role !== "owner" && item.role !== "pet")) {
      throw new Error("history has an invalid role");
    }
    return {
      role: item.role,
      content: requiredString(item, "content", 160),
    };
  });
}

function validateAnalyzeRequest(value: unknown): AnalyzeRequest {
  if (!isRecord(value)) throw new Error("Request body must be an object");

  // 旧アプリは imageBase64 の1枚、新アプリは imagesBase64 で最大3枚を送る。
  let imagesBase64: string[];
  if (value.imagesBase64 !== undefined) {
    if (
      !Array.isArray(value.imagesBase64) ||
      value.imagesBase64.length === 0 ||
      value.imagesBase64.length > MAX_FRAMES
    ) {
      throw new Error(`imagesBase64 must contain 1 to ${MAX_FRAMES} images`);
    }
    imagesBase64 = value.imagesBase64.map((_, index) =>
      requiredString(
        value.imagesBase64 as Record<string, unknown>,
        String(index),
        MAX_BASE64_LENGTH,
      ),
    );
  } else {
    imagesBase64 = [requiredString(value, "imageBase64", MAX_BASE64_LENGTH)];
  }
  if (imagesBase64.some((image) => !/^[A-Za-z0-9+/]+={0,2}$/.test(image))) {
    throw new Error("images must be valid base64 JPEG data");
  }

  const clientId = requiredString(value, "clientId", 64);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(clientId)) {
    throw new Error("clientId must be a UUID v4");
  }

  return {
    imagesBase64,
    clientId,
    species: requiredString(value, "species", 40),
    personality: requiredString(value, "personality", 40),
    dialect: requiredString(value, "dialect", 40),
  };
}

function requiredString(
  record: Record<string, unknown>,
  key: string,
  maxLength: number,
): string {
  const value = record[key];
  if (typeof value !== "string") throw new Error(`${key} must be a string`);
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) {
    throw new Error(`${key} has an invalid length`);
  }
  return trimmed;
}

function optionalString(
  record: Record<string, unknown>,
  key: string,
  maxLength: number,
): string {
  const value = record[key];
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") throw new Error(`${key} must be a string`);
  return sanitizeText(value, maxLength);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function buildVisionPrompt(expectedSpecies: string): string {
  const englishSpecies = visionSpeciesName(expectedSpecies);
  return [
    `A pet owner is pointing a phone camera at their pet. They say it is a ${englishSpecies}.`,
    "Report what is actually visible in this frame; the owner's answer is context, not the answer.",
    "Search the whole frame. Count a real animal as present even if it is only partly visible (only the back, tail, paws, ears or fur), cut off by the frame edge, blurry, far away, small, seen from the side or behind, sleeping, curled up, lying down, or in dim or dark lighting.",
    'Use "none" only when you are confident there is no real animal anywhere. If you cannot tell, use "unknown".',
    'Plush toys, figurines, drawings, and animals shown on a screen or printed photo are "none".',
    "category: dog, cat, other_pet, none, or unknown. species: the visible animal in simple English, or empty.",
    "confidence: 0 to 1, how sure you are about category.",
    'pose: when an animal is visible, always describe its visible posture or action in a few English words, for example "lying down with eyes closed" or "sitting and looking at the camera". Empty only for none.',
  ].join(" ");
}

const frameSchema = {
  type: "object",
  properties: {
    category: {
      type: "string",
      enum: ["dog", "cat", "other_pet", "none", "unknown"],
    },
    species: { type: "string" },
    confidence: { type: "number" },
    pose: { type: "string" },
  },
  required: ["category", "species", "confidence", "pose"],
};

function visionSpeciesName(species: string): string {
  const names: Record<string, string> = {
    犬: "dog",
    猫: "cat",
    ウサギ: "rabbit",
    ハムスター: "hamster",
    フクロモモンガ: "sugar glider",
    フェレット: "ferret",
  };
  return names[species] ?? sanitizeText(species, 40);
}

async function classifyFrame(
  env: Env,
  imageBase64: string,
  selectedSpecies: string,
): Promise<FrameClassification> {
  const inference = await env.AI.run(VISION_MODEL, {
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: buildVisionPrompt(selectedSpecies) },
          {
            type: "image_url",
            image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
          },
        ],
      },
    ],
    response_format: { type: "json_schema", json_schema: frameSchema },
    stream: false,
    max_tokens: 80,
    temperature: 0,
  });
  return parseFrameClassification(requiredAiValue(inference, "response"));
}

export function parseFrameClassification(response: unknown): FrameClassification {
  const parsed = parseStructuredObject(response);
  const category = String(parsed.category ?? "").trim().toLowerCase();
  if (!["dog", "cat", "other_pet", "none", "unknown"].includes(category)) {
    throw new Error("AI returned an invalid category");
  }
  const rawConfidence = Number(parsed.confidence);
  return {
    category: category as FrameCategory,
    species: sanitizeText(parsed.species, 40),
    confidence: Number.isFinite(rawConfidence)
      ? Math.min(1, Math.max(0, rawConfidence))
      : 0.5,
    pose: sanitizeText(parsed.pose, 80),
  };
}

// 見逃しを減らすため「不明」は通す側に倒し、別種は十分な信頼度があるときだけ断定する。
export function decideFrame(
  frame: FrameClassification,
  selectedSpecies: string,
): FrameVerdict {
  const smallMammal = isConfusableSmallMammal(selectedSpecies);
  if (frame.category === "none") {
    return smallMammal
      ? { kind: "unknown_pass", species: canonicalSpecies(selectedSpecies), confidence: 0.5, pose: "" }
      : { kind: "none", confidence: frame.confidence };
  }
  const fallbackSpecies =
    canonicalSpecies(selectedSpecies) || sanitizeText(selectedSpecies, 30);
  if (frame.category === "unknown") {
    return { kind: "unknown_pass", species: fallbackSpecies, confidence: 0.5, pose: frame.pose };
  }
  const detected =
    frame.category === "dog"
      ? "犬"
      : frame.category === "cat"
        ? "猫"
        : canonicalSpecies(frame.species);
  if (detected.length > 0 && speciesMatchesSelected(detected, selectedSpecies)) {
    return {
      kind: "pet",
      species: preferredSpeciesForAcceptedMatch(detected, selectedSpecies),
      confidence: frame.confidence,
      pose: frame.pose,
    };
  }
  if (detected.length > 0 && frame.confidence >= MISMATCH_MIN_CONFIDENCE) {
    return { kind: "mismatch", detectedSpecies: detected, confidence: frame.confidence };
  }
  return { kind: "unknown_pass", species: fallbackSpecies, confidence: 0.5, pose: frame.pose };
}

async function analyzeFrames(env: Env, payload: AnalyzeRequest): Promise<VisionResult> {
  const verdicts: FrameVerdict[] = [];
  let lastError: unknown = null;
  for (const image of payload.imagesBase64) {
    let verdict: FrameVerdict;
    try {
      verdict = decideFrame(
        await classifyFrame(env, image, payload.species),
        payload.species,
      );
    } catch (error) {
      lastError = error;
      continue;
    }
    verdicts.push(verdict);
    // 1枚でもペットと判定できれば残りのフレームは推論しない。
    if (verdict.kind === "pet") break;
  }
  if (verdicts.length === 0) throw lastError ?? new Error("No frames analyzed");
  return summarizeVerdicts(verdicts);
}

export function summarizeVerdicts(verdicts: FrameVerdict[]): VisionResult {
  const framesChecked = verdicts.length;
  const accepted =
    verdicts.find((v) => v.kind === "pet") ??
    verdicts.find((v) => v.kind === "unknown_pass");
  if (accepted && (accepted.kind === "pet" || accepted.kind === "unknown_pass")) {
    return {
      petDetected: true,
      species: accepted.species,
      confidence: accepted.confidence,
      comment: "ここにいるよ",
      comments: ["ここにいるよ"],
      observedState: poseToJapanese(accepted.pose),
      verdict: accepted.kind,
      framesChecked,
    };
  }
  const mismatch = verdicts.find((v) => v.kind === "mismatch");
  if (mismatch && mismatch.kind === "mismatch") {
    return {
      petDetected: false,
      species: "",
      confidence: mismatch.confidence,
      comment: "",
      comments: [],
      observedState: "",
      detectedSpecies: mismatch.detectedSpecies,
      verdict: "mismatch",
      framesChecked,
    };
  }
  return {
    petDetected: false,
    species: "",
    confidence: Math.max(...verdicts.map((v) => v.confidence)),
    comment: "",
    comments: [],
    observedState: "",
    verdict: "none",
    framesChecked,
  };
}

// 会話・コメント書き換えの姿勢制約は日本語の語句で判定するため、英語の姿勢説明を日本語へ寄せる。
export function poseToJapanese(pose: string): string {
  const text = pose.toLowerCase();
  const phrases: Array<[RegExp, string]> = [
    [/on (?:its|his|her) back|belly up/, "仰向けに寝転んでいる"],
    [/curled/, "丸まっている"],
    [/lying|laying|lie down|resting/, "横になっている"],
    [/eyes? closed|sleep|asleep|napping|dozing/, "目を閉じて眠っている"],
    [/sitting|seated/, "座っている"],
    [/standing/, "立っている"],
    [/walking/, "歩いている"],
    [/running/, "走っている"],
    [/eating|drinking/, "食べている"],
    [/playing/, "遊んでいる"],
    [/looking at (?:the )?camera|staring/, "こちらを見ている"],
    [/grooming|licking/, "毛づくろいしている"],
  ];
  const matched = phrases
    .filter(([pattern]) => pattern.test(text))
    .map(([, japanese]) => japanese)
    .slice(0, 2);
  return matched.length > 0 ? matched.join("、") : "画面に映っている";
}

function requiredAiValue(value: unknown, key: "answer" | "response"): unknown {
  const outer = isRecord(value) && isRecord(value.result) ? value.result : value;
  if (!isRecord(outer) || !(key in outer)) {
    throw new Error(`AI returned no ${key}`);
  }
  return outer[key];
}

function canonicalSpecies(raw: string): string {
  const normalized = sanitizeText(raw, 40).toLowerCase();
  const speciesMap: Array<[RegExp, string]> = [
    [/(?:^|\b)(?:dog|puppy|canine)(?:\b|$)|犬|いぬ/, "犬"],
    [/(?:^|\b)(?:cat|kitten|feline)(?:\b|$)|猫|ねこ/, "猫"],
    [/(?:^|\b)(?:rabbit|bunny|hare)(?:\b|$)|ウサギ|うさぎ|兎/, "ウサギ"],
    [/(?:^|\b)hamster(?:\b|$)|ハムスター/, "ハムスター"],
    [/(?:^|\b)chipmunk(?:\b|$)|シマリス/, "シマリス"],
    [/(?:^|\b)squirrel(?:\b|$)|リス/, "リス"],
    [
      /(?:^|\b)(?:gerbil|mouse|rat|rodent|guinea pig|chinchilla)(?:\b|$)|スナネズミ|モルモット|チンチラ|ネズミ/,
      "小型げっ歯類",
    ],
    [/(?:^|\b)(?:bird|parrot|finch|sparrow)(?:\b|$)|鳥/, "鳥"],
    [/(?:^|\b)sugar glider(?:\b|$)|フクロモモンガ/, "フクロモモンガ"],
    [/(?:^|\b)ferret(?:\b|$)|フェレット/, "フェレット"],
    [/(?:^|\b)axolotl(?:\b|$)|ウーパールーパー/, "ウーパールーパー"],
    [/(?:^|\b)(?:horse|pony)(?:\b|$)|馬/, "馬"],
    [/(?:^|\b)elephant(?:\b|$)|象/, "象"],
    [/(?:^|\b)panda(?:\b|$)|パンダ/, "パンダ"],
    [/(?:^|\b)(?:cow|cattle)(?:\b|$)|牛/, "牛"],
    [/(?:^|\b)(?:monkey|ape)(?:\b|$)|猿/, "猿"],
  ];
  for (const [pattern, japanese] of speciesMap) {
    if (pattern.test(normalized)) return japanese;
  }
  return "";
}

export function speciesMatchesSelected(
  detectedSpecies: string,
  selectedSpecies: string,
): boolean {
  const detectedCanonical = canonicalSpecies(detectedSpecies);
  const selectedCanonical = canonicalSpecies(selectedSpecies);
  if (
    detectedCanonical !== selectedCanonical &&
    isConfusableSmallMammal(detectedCanonical) &&
    isConfusableSmallMammal(selectedCanonical)
  ) {
    return true;
  }
  if (detectedCanonical.length > 0 || selectedCanonical.length > 0) {
    return (
      detectedCanonical.length > 0 &&
      selectedCanonical.length > 0 &&
      detectedCanonical === selectedCanonical
    );
  }
  return (
    sanitizeText(detectedSpecies, 40).toLowerCase() ===
    sanitizeText(selectedSpecies, 40).toLowerCase()
  );
}

const confusableSmallMammals = new Set([
  "フクロモモンガ",
  "ハムスター",
  "フェレット",
  "ウサギ",
  "シマリス",
  "リス",
  "小型げっ歯類",
]);

function isConfusableSmallMammal(species: string): boolean {
  return confusableSmallMammals.has(canonicalSpecies(species));
}

function preferredSpeciesForAcceptedMatch(
  detectedSpecies: string,
  selectedSpecies: string,
): string {
  if (
    isConfusableSmallMammal(detectedSpecies) &&
    isConfusableSmallMammal(selectedSpecies)
  ) {
    return canonicalSpecies(selectedSpecies);
  }
  return detectedSpecies;
}

export function parseReplyResult(response: unknown): string {
  const parsed = parseStructuredObject(response);
  const reply = sanitizeText(parsed.reply, 70).replace(/^[「『"']|[」』"']$/g, "");
  if (reply.length === 0) throw new Error("AI returned an empty reply");
  return reply;
}

export function parseCommentsResult(response: unknown, expectedCount: number): string[] {
  const parsed = parseStructuredObject(response);
  if (!Array.isArray(parsed.comments)) throw new Error("AI returned no comments");
  const comments = parsed.comments.map((value) => sanitizeText(value, 120));
  if (comments.length !== expectedCount || comments.some((value) => value.length === 0)) {
    throw new Error("AI returned the wrong number of comments");
  }
  return comments;
}

function parseStructuredObject(response: unknown): Record<string, unknown> {
  let parsed = response;
  if (typeof response === "string") {
    const start = response.indexOf("{");
    const end = response.lastIndexOf("}");
    if (start < 0 || end <= start) throw new Error("AI returned invalid JSON");
    parsed = JSON.parse(response.slice(start, end + 1));
  }
  if (!isRecord(parsed)) throw new Error("AI returned invalid JSON");
  return parsed;
}

function personalityInstruction(personality: string): string {
  const instructions: Record<string, string> = {
    元気: "React cheerfully and energetically, eager to play.",
    おっとり: "React gently, slowly, and reassuringly.",
    クール: "React briefly and calmly, a little aloof but affectionate underneath.",
    甘えん坊: "React affectionately and seek closeness with the owner.",
    臆病: "React cautiously and softly, seeking reassurance without excessive negativity.",
    おしゃべり: "React expressively with a little extra detail and curiosity.",
    やんちゃ: "React playfully and mischievously, but never mean or destructive.",
  };
  return instructions[personality] ?? instructions["元気"]!;
}

export function statePriorityInstruction(observedState: string): string {
  const state = sanitizeText(observedState, 100);
  if (/(目を閉|眠|寝て|睡眠|うとうと|まどろん)/.test(state)) {
    return (
      "最優先の姿勢制約: ペットは眠っているか、うとうとして休んでいます。" +
      "返事は寝た姿勢のままの小さく眠そうな反応にしてください。現在走る・跳ぶ・遊ぶ・食べるとは言わせません。" +
      "活発な性格でも勢いは夢、寝言、または起きた後の希望としてだけ表現します。" +
      "例: 遊びへの誘いには『今はごろんとしてるから、起きたら一番に遊ぼうね』のように答えます。"
    );
  }
  if (/(横にな|寝転|寝そべ|伏せ|丸ま|ごろん)/.test(state)) {
    return (
      "最優先の姿勢制約: ペットは体を横たえるか伏せて休んでいます。" +
      "返事はその場でくつろいだままの視点にし、現在走る・跳ぶ・駆け回るとは言わせません。" +
      "活発な性格は、起き上がった後にしたいことや、寝転んだままのいたずらっぽい口調で表します。" +
      "例: 遊びへの誘いには『もう少しごろんとしたら、起きて遊ぶよ』のように答えます。"
    );
  }
  return "現在の姿勢・動作と矛盾する身体行動を返事に含めないでください。";
}

function dialectInstruction(dialect: string): string {
  const instructions: Record<string, string> = {
    標準語: "Use natural casual standard Japanese.",
    関西弁: "Use conversational Kansai wording and rhythm, such as やで・やん・せやな, only where natural.",
    新潟弁: "Use natural Niigata wording sparingly, such as だすけ・らて, with a believable rhythm.",
    福岡弁: "Use natural Hakata/Fukuoka wording, such as 〜と？・ばい・っちゃん, according to sentence meaning.",
    広島弁: "Use natural Hiroshima wording, such as じゃけぇ・じゃろ・しとる, according to context.",
    福島弁: "Use gentle Fukushima/Tohoku wording, such as だべ・だない, without caricature.",
    秋田弁: "Use gentle Akita wording sparingly, such as だべ・けれ, while keeping it understandable.",
    名古屋弁: "Use natural Nagoya wording, such as だがね・しとる・でら, only where it fits.",
    金沢弁: "Use natural Kanazawa wording, such as 〜が？・やじ・まっし, while remaining understandable.",
  };
  return instructions[dialect] ?? instructions["標準語"]!;
}

function dialectRewriteExamples(dialect: string): string {
  const examples: Record<string, string> = {
    標準語: "『一緒に走りたいな』→『一緒に走りたいな』",
    関西弁:
      "『一緒に走ると楽しいな』→『一緒に走ったら、めっちゃ楽しいやろな』、" +
      "『早く遊びたいよ』→『はよ遊びたいわ』",
    新潟弁:
      "『一緒にいると安心するよ』→『一緒にいると安心するんだて』、" +
      "『遊びたいな』→『遊びたいろ』",
    福岡弁:
      "『何して遊ぶの？』→『何して遊ぶと？』、『一緒にいたいよ』→『一緒におりたいっちゃん』",
    広島弁:
      "『一緒に走りたいな』→『一緒に走りたいのう』、『楽しいよ』→『楽しいんよ』",
    福島弁:
      "『今日は暖かいね』→『今日はあったけぇな』、『一緒に行こうよ』→『一緒に行ぐべ』",
    秋田弁:
      "『そばにいてね』→『そばさいでけれ』、『一緒に遊ぼう』→『一緒に遊ぶべ』",
    名古屋弁:
      "『とても楽しいよ』→『でら楽しいがね』、『一緒に走りたいな』→『一緒に走りたいがね』",
    金沢弁:
      "『何しているの？』→『何しとるが？』、『こっちにおいで』→『こっち来まっし』",
  };
  return examples[dialect] ?? examples["標準語"]!;
}

function naturalizeDialect(text: string, dialect: string): string {
  if (dialect === "関西弁") {
    return text
      .replace(/い\s*やで/g, "いで")
      .replace(/だろう/g, "やろ")
      .replace(/だよ/g, "やで")
      .replace(/だね/g, "やな");
  }
  return text;
}

function sanitizeText(value: unknown, maxRunes: number): string {
  if (typeof value !== "string") return "";
  const oneLine = value.replace(/\s+/g, " ").trim();
  return Array.from(oneLine).slice(0, maxRunes).join("");
}

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      ...corsHeaders,
      "cache-control": "no-store",
    },
  });
}
