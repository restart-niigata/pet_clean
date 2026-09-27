import { describe, expect, it } from "vitest";

import {
  buildVisionPrompt,
  decideFrame,
  parseCommentsResult,
  parseFrameClassification,
  parseReplyResult,
  poseToJapanese,
  statePriorityInstruction,
  speciesMatchesSelected,
  summarizeVerdicts,
  buildChatMessages,
  finalizeUtterance,
  imageMimeType,
  moodToJapanese,
  normalizePreset,
  parseObservation,
  poseKeyFromText,
  validateChatRequest,
  type ChatRequest,
  type FrameClassification,
  type FrameObservation,
} from "../src/index";

describe("species matching", () => {
  it("matches Japanese and English aliases of the selected species", () => {
    expect(speciesMatchesSelected("sugar glider", "フクロモモンガ")).toBe(true);
    expect(speciesMatchesSelected("犬", "dog")).toBe(true);
  });

  it("rejects a dog when the owner selected a sugar glider", () => {
    expect(speciesMatchesSelected("犬", "フクロモモンガ")).toBe(false);
  });

  it("accepts visually confusable small mammals as the selected pet", () => {
    expect(speciesMatchesSelected("ハムスター", "フクロモモンガ")).toBe(true);
    expect(speciesMatchesSelected("rabbit", "フェレット")).toBe(true);
    expect(speciesMatchesSelected("Chipmunk", "フクロモモンガ")).toBe(true);
    expect(speciesMatchesSelected("squirrel", "ウサギ")).toBe(true);
  });
});

describe("conversation output parsing", () => {
  it("parses a structured pet reply", () => {
    expect(parseReplyResult({ reply: "遊ぼうや！" })).toBe("遊ぼうや！");
  });

  it("requires the rewritten comment count", () => {
    expect(parseCommentsResult({ comments: ["ええ天気やな", "遊ぼうや"] }, 2)).toEqual([
      "ええ天気やな",
      "遊ぼうや",
    ]);
    expect(() => parseCommentsResult({ comments: ["一件だけ"] }, 2)).toThrow(
      "wrong number",
    );
  });

  it("makes a resting pose override active personality behavior", () => {
    const sleeping = statePriorityInstruction("横になって目を閉じている");
    expect(sleeping).toContain("眠そうな反応");
    expect(sleeping).toContain("起きた後");

    const lyingDown = statePriorityInstruction("クッションに伏せている");
    expect(lyingDown).toContain("くつろいだまま");
    expect(lyingDown).toContain("起き上がった後");
  });
});

const frame = (overrides: Partial<FrameClassification>): FrameClassification => ({
  category: "none",
  species: "",
  confidence: 0.9,
  pose: "",
  poseKey: "other",
  moodKey: "unknown",
  expression: "",
  ...overrides,
});

const observation = (overrides: Partial<FrameObservation> = {}): FrameObservation => ({
  pose: "lying down with eyes closed",
  poseKey: "sleeping",
  moodKey: "sleepy",
  expression: "eyes closed",
  ...overrides,
});

describe("buildVisionPrompt", () => {
  it("asks the model to accept partial, blurry, sleeping and dark pets", () => {
    const prompt = buildVisionPrompt("犬");
    expect(prompt).toContain("dog");
    expect(prompt).toContain("only partly visible");
    expect(prompt).toContain("blurry");
    expect(prompt).toContain("sleeping");
    expect(prompt).toContain("dim or dark lighting");
    expect(prompt).toContain('If you cannot tell, use "unknown"');
  });
});

describe("parseFrameClassification", () => {
  it("parses schema output from an object or a JSON string", () => {
    const expected = { category: "cat", species: "cat", confidence: 0.8, pose: "curled up" };
    const parsed = { ...expected, poseKey: "lying", moodKey: "unknown", expression: "" };
    expect(parseFrameClassification(expected)).toEqual(parsed);
    expect(parseFrameClassification(`Result: ${JSON.stringify(expected)}`)).toEqual(parsed);
  });

  it("clamps confidence and rejects unknown categories", () => {
    expect(parseFrameClassification({ category: "DOG", confidence: 3 })).toMatchObject({
      category: "dog",
      confidence: 1,
    });
    expect(() => parseFrameClassification({ category: "bird" })).toThrow("invalid category");
  });
});

describe("decideFrame", () => {
  it("accepts the selected species", () => {
    expect(decideFrame(frame({ category: "dog", species: "dalmatian" }), "犬")).toMatchObject({
      kind: "pet",
      species: "犬",
    });
  });

  it("passes unknown frames instead of rejecting them", () => {
    expect(decideFrame(frame({ category: "unknown", confidence: 0.3 }), "猫")).toMatchObject({
      kind: "unknown_pass",
      species: "猫",
    });
  });

  it("reports a confident different species", () => {
    expect(decideFrame(frame({ category: "dog", confidence: 0.9 }), "猫")).toEqual({
      kind: "mismatch",
      detectedSpecies: "犬",
      confidence: 0.9,
    });
  });

  it("passes a low-confidence different species as unknown", () => {
    expect(decideFrame(frame({ category: "dog", confidence: 0.4 }), "猫").kind).toBe(
      "unknown_pass",
    );
  });

  it("rejects none for dogs but lets small mammals continue", () => {
    expect(decideFrame(frame({ category: "none" }), "犬").kind).toBe("none");
    expect(decideFrame(frame({ category: "none" }), "フクロモモンガ")).toMatchObject({
      kind: "unknown_pass",
      species: "フクロモモンガ",
    });
  });

  it("treats confusable small mammals as the selected pet", () => {
    expect(
      decideFrame(frame({ category: "other_pet", species: "hamster" }), "フクロモモンガ"),
    ).toMatchObject({ kind: "pet", species: "フクロモモンガ" });
  });
});

describe("summarizeVerdicts", () => {
  it("accepts when any frame found the pet", () => {
    expect(
      summarizeVerdicts([
        { kind: "none", confidence: 0.9 },
        { kind: "pet", species: "犬", confidence: 0.8, observation: observation() },
      ]),
    ).toMatchObject({
      petDetected: true,
      species: "犬",
      observedState: "横になっている、目を閉じて眠っている",
      poseKey: "sleeping",
      moodKey: "sleepy",
      mood: "眠いのかも",
      expression: "eyes closed",
      verdict: "pet",
      framesChecked: 2,
    });
  });

  it("reports a mismatch only when no frame passed", () => {
    expect(
      summarizeVerdicts([
        { kind: "none", confidence: 0.9 },
        { kind: "mismatch", detectedSpecies: "犬", confidence: 0.9 },
      ]),
    ).toMatchObject({ petDetected: false, detectedSpecies: "犬", verdict: "mismatch" });
  });

  it("returns no pet when every frame is empty", () => {
    expect(summarizeVerdicts([{ kind: "none", confidence: 0.7 }])).toMatchObject({
      petDetected: false,
      verdict: "none",
    });
  });
});

describe("poseToJapanese", () => {
  it("maps resting poses to phrases the reply constraints understand", () => {
    expect(poseToJapanese("curled up asleep")).toBe("丸まっている、目を閉じて眠っている");
    expect(statePriorityInstruction(poseToJapanese("lying on back"))).toContain("体を横たえる");
    expect(poseToJapanese("")).toBe("画面に映っている");
  });
});

describe("observation parsing", () => {
  it("keeps valid keys and falls back to the pose text", () => {
    expect(
      parseObservation({ pose: "sitting up", pose_key: "SITTING", mood_key: "curious", expression: "ears forward" }),
    ).toEqual({ pose: "sitting up", poseKey: "sitting", moodKey: "curious", expression: "ears forward" });
    expect(parseObservation({ pose: "curled up asleep", pose_key: "flying", mood_key: "angry" })).toMatchObject({
      poseKey: "sleeping",
      moodKey: "unknown",
    });
    expect(poseKeyFromText("standing by the door")).toBe("standing");
    expect(poseKeyFromText("")).toBe("other");
  });

  it("describes moods without asserting them", () => {
    expect(moodToJapanese("sleepy")).toBe("眠いのかも");
    expect(moodToJapanese("unknown")).toBe("");
  });

  it("detects PNG frames by their base64 signature", () => {
    expect(imageMimeType("iVBORw0KGgoAAAA")).toBe("image/png");
    expect(imageMimeType("/9j/4AAQ")).toBe("image/jpeg");
  });
});

const chatBody = (overrides: Record<string, unknown> = {}) => ({
  clientId: "123e4567-e89b-42d3-a456-426614174000",
  kind: "reply",
  message: "おやつ食べる？",
  persona: {
    petName: "ポチ",
    species: "犬",
    preset: "ツンデレ",
    firstPerson: "おれ",
    ending: "ワン",
    ownerCall: "ご主人",
    dialect: "標準語",
  },
  state: { pose: "座っている", mood: "遊びたい気分なのかも", expression: "tail up" },
  history: [
    { role: "owner", content: "ただいま" },
    { role: "pet", content: "べつに待ってないワン", kind: "reply" },
  ],
  ...overrides,
});

describe("validateChatRequest", () => {
  it("accepts a reply with persona, state and history", () => {
    const chat = validateChatRequest(chatBody());
    expect(chat.kind).toBe("reply");
    expect(chat.persona).toMatchObject({ preset: "ツンデレ", firstPerson: "おれ", ownerCall: "ご主人" });
    expect(chat.history).toHaveLength(2);
  });

  it("requires a message only for replies", () => {
    expect(() => validateChatRequest(chatBody({ message: undefined }))).toThrow("message");
    expect(validateChatRequest(chatBody({ kind: "monologue", message: undefined })).message).toBe("");
  });

  it("rejects unknown kinds and long histories", () => {
    expect(() => validateChatRequest(chatBody({ kind: "shout" }))).toThrow("kind");
    const history = Array.from({ length: 21 }, () => ({ role: "owner", content: "やあ" }));
    expect(() => validateChatRequest(chatBody({ history }))).toThrow("at most 20");
  });

  it("falls back to defaults and strips prompt delimiters from persona fields", () => {
    const chat = validateChatRequest(
      chatBody({ persona: { species: "猫", preset: "謎", ownerCall: "<ご主人>", firstPerson: "" } }),
    );
    expect(chat.persona).toMatchObject({ preset: "甘えん坊", ownerCall: "ご主人", firstPerson: "ぼく" });
    expect(normalizePreset("おっとり")).toBe("のんびり");
  });
});

describe("buildChatMessages", () => {
  const base = validateChatRequest(chatBody());

  it("puts the persona, state and safety rules in the system prompt", () => {
    const [system] = buildChatMessages(base);
    expect(system?.role).toBe("system");
    for (const text of ["ポチ", "一人称は「おれ」", "「ワン」", "ツンデレ", "ご主人", "座っている", "断定せず", "動物病院"]) {
      expect(system?.content).toContain(text);
    }
  });

  it("maps history to chat roles and ends with the owner's message", () => {
    const messages = buildChatMessages(base);
    expect(messages.map((m) => m.role)).toEqual(["system", "user", "assistant", "user"]);
    expect(messages.at(-1)?.content).toContain("おやつ食べる？");
  });

  it("keeps monologues from addressing the owner", () => {
    const chat: ChatRequest = {
      ...base,
      kind: "monologue",
      message: "",
      state: { ...base.state, previousPose: "寝ている" },
      history: [{ role: "pet", content: "ねむい", kind: "monologue" }],
    };
    const messages = buildChatMessages(chat);
    expect(messages[1]?.content).toBe("（ひとりごと）ねむい");
    expect(messages.at(-1)?.content).toContain("話しかけず");
    expect(messages.at(-1)?.content).toContain("「寝ている」から「座っている」");
  });

  it("asks greetings to address the owner first", () => {
    const messages = buildChatMessages({ ...base, kind: "greet", message: "" });
    expect(messages.at(-1)?.content).toContain("自分からご主人に話しかける");
  });
});

describe("finalizeUtterance", () => {
  const chat = validateChatRequest(chatBody());

  it("strips quotes and monologue markers", () => {
    expect(finalizeUtterance({ utterance: "「べつにいらないワン」" }, chat)).toBe("べつにいらないワン");
    expect(finalizeUtterance('{"utterance":"（ひとりごと）ねむいな"}', chat)).toBe("ねむいな");
  });

  it("repairs an unnatural hedge and removes addressee cues from monologues", () => {
    const monologue = { ...chat, kind: "monologue" as const, message: "" };
    expect(finalizeUtterance({ utterance: "ほら、眠いな気がする" }, monologue)).toBe(
      "眠い気がする",
    );
  });

  it("replaces unhedged health claims", () => {
    expect(finalizeUtterance({ utterance: "おなかが痛いワン" }, chat)).toContain("動物病院");
    expect(finalizeUtterance({ utterance: "痛いところはないかも" }, chat)).toBe("痛いところはないかも");
  });

  it("rejects empty output", () => {
    expect(() => finalizeUtterance({ utterance: "" }, chat)).toThrow("empty utterance");
  });
});
