import {describe, it} from "node:test";
import assert from "node:assert/strict";

import {
  buildPrompt,
  parseClassifyResponse,
  resolveSelectedCategory,
  type ClassifyRequest,
} from "./classifyTransaction.schema";

describe("buildPrompt", () => {
  it("includes user-selected category when provided", () => {
    const prompt = buildPrompt({
      categoryIds: ["food", "transfer"],
      selectedCategoryId: "transfer",
      smsBody: "Rs 500 paid to NIZAM M via UPI",
      merchant: "nizam@ybl",
    });
    assert.match(prompt, /User pre-selected categoryId: transfer/);
    assert.match(prompt, /NIZAM M/);
  });

  it("accepts hintCategoryId alias", () => {
    const prompt = buildPrompt({
      categoryIds: ["food", "transfer"],
      hintCategoryId: "transfer",
    });
    assert.match(prompt, /User pre-selected categoryId: transfer/);
    assert.equal(
      resolveSelectedCategory({hintCategoryId: "transfer"}),
      "transfer",
    );
  });

  it("lists subcategory taxonomy", () => {
    const prompt = buildPrompt({
      categoryIds: ["bills"],
      subcategoryTaxonomy: {bills: ["internet", "rent", "electricity"]},
    });
    assert.match(prompt, /bills: internet, rent, electricity/);
  });
});

describe("parseClassifyResponse", () => {
  const baseRequest: ClassifyRequest = {
    categoryIds: ["food", "bills", "transfer"],
    subcategoryTaxonomy: {
      bills: ["internet", "rent", "electricity"],
      transfer: [],
    },
  };

  it("respects user-selected category", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "food",
        merchantNormalized: "Nizam M",
        needsUserInput: false,
      },
      {...baseRequest, selectedCategoryId: "transfer"},
    );
    assert.equal(result.categoryId, "transfer");
    assert.equal(result.merchantNormalized, "Nizam M");
  });

  it("respects hintCategoryId alias over AI category", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "food",
        needsUserInput: false,
      },
      {...baseRequest, hintCategoryId: "transfer"},
    );
    assert.equal(result.categoryId, "transfer");
  });

  it("allows AI override when needsUserInput is true", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "food",
        needsUserInput: true,
        userNotes: "This is a restaurant charge, not a transfer.",
      },
      {...baseRequest, selectedCategoryId: "transfer"},
    );
    assert.equal(result.categoryId, "food");
    assert.equal(result.needsUserInput, true);
  });

  it("validates subcategory against taxonomy", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "bills",
        subcategoryId: "electricity",
        needsUserInput: false,
      },
      baseRequest,
    );
    assert.equal(result.subcategoryId, "electricity");
  });

  it("rejects invalid subcategory", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "bills",
        subcategoryId: "delivery",
        needsUserInput: false,
      },
      baseRequest,
    );
    assert.equal(result.subcategoryId, null);
  });

  it("autofills transferTo from merchant for transfers", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "transfer",
        merchantNormalized: "Nizam M",
        needsUserInput: false,
      },
      baseRequest,
    );
    assert.equal(result.transferTo, "Nizam M");
  });

  it("returns suggested category when categoryId is null", () => {
    const result = parseClassifyResponse(
      {
        categoryId: null,
        suggestedCategoryId: "pet_care",
        suggestedCategoryName: "Pet Care",
        needsUserInput: true,
      },
      baseRequest,
    );
    assert.equal(result.categoryId, null);
    assert.equal(result.suggestedCategoryId, "pet_care");
    assert.equal(result.suggestedCategoryName, "Pet Care");
    assert.equal(result.needsUserInput, true);
  });

  it("clears suggested category when categoryId is set", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "food",
        suggestedCategoryId: "pet_care",
        suggestedCategoryName: "Pet Care",
        needsUserInput: false,
      },
      baseRequest,
    );
    assert.equal(result.categoryId, "food");
    assert.equal(result.suggestedCategoryId, null);
  });
});
