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
  type FrameClassification,
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
    expect(parseFrameClassification(expected)).toEqual(expected);
    expect(parseFrameClassification(`Result: ${JSON.stringify(expected)}`)).toEqual(expected);
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
        { kind: "pet", species: "犬", confidence: 0.8, pose: "lying down with eyes closed" },
      ]),
    ).toMatchObject({
      petDetected: true,
      species: "犬",
      observedState: "横になっている、目を閉じて眠っている",
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
