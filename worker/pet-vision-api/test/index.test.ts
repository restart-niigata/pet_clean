import { describe, expect, it } from "vitest";

import {
  buildVisionPrompt,
  manualSmallMammalFallback,
  parseCommentsResult,
  parseReplyResult,
  parseVisionClassification,
  statePriorityInstruction,
  speciesMatchesSelected,
} from "../src/index";

describe("buildVisionPrompt", () => {
  it("asks the model to accept small or curled-up selected pets", () => {
    const prompt = buildVisionPrompt("ハムスター");
    expect(prompt).toContain("ハムスター");
    expect(prompt).toContain("curled-up");
    expect(prompt).toContain("Do not require the face or full body");
    expect(prompt).toContain("different species MUST be PET");
  });
});

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


describe("parseVisionClassification", () => {
  it("accepts a detected pet response", () => {
    expect(
      parseVisionClassification("PET|dog|0.91|lying on a blue cushion", "犬"),
    ).toEqual({
      petDetected: true,
      species: "犬",
      confidence: 0.91,
      comment: "lying on a blue cushion",
    });
  });

  it("normalizes a no-pet response", () => {
    expect(parseVisionClassification("NONE|0.88|empty room", "犬")).toEqual({
      petDetected: false,
      species: "",
      confidence: 0.88,
      comment: "",
    });
  });

  it("accepts a classification after model preamble and markdown", () => {
    expect(
      parseVisionClassification(
        "Here is the classification:\n**PET｜cat｜0.84｜sitting by a window**",
        "猫",
      ),
    ).toEqual({
      petDetected: true,
      species: "猫",
      confidence: 0.84,
      comment: "sitting by a window",
    });
  });

  it("rejects malformed output", () => {
    expect(() => parseVisionClassification("no result here", "犬")).toThrow(
      "AI classification had an invalid format",
    );
  });
});

describe("manualSmallMammalFallback", () => {
  it("lets an owner-confirmed small pet continue when vision says none", () => {
    const classification = parseVisionClassification(
      "NONE|1|frame too dark",
      "フクロモモンガ",
    );
    expect(
      manualSmallMammalFallback(classification, "フクロモモンガ"),
    ).toMatchObject({
      petDetected: true,
      species: "フクロモモンガ",
    });
  });

  it("does not bypass detection for dogs", () => {
    const classification = parseVisionClassification(
      "NONE|1|empty room",
      "犬",
    );
    expect(manualSmallMammalFallback(classification, "犬")).toBeNull();
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
