import {describe, it} from "node:test";
import assert from "node:assert/strict";

import {
  AUTO_APPLY_CATEGORY_CONFIDENCE,
  buildPrompt,
  isLikelyP2PPayment,
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
        categoryConfidence: 0.9,
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
        categoryConfidence: 0.9,
        suggestedCategoryId: "pet_care",
        suggestedCategoryName: "Pet Care",
        needsUserInput: false,
      },
      baseRequest,
    );
    assert.equal(result.categoryId, "food");
    assert.equal(result.suggestedCategoryId, null);
  });

  it("routes low-confidence category to inbox", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "food",
        categoryConfidence: 0.55,
        needsUserInput: false,
      },
      baseRequest,
    );
    assert.equal(result.categoryId, null);
    assert.equal(result.needsUserInput, true);
  });

  it("auto-applies high-confidence merchant category", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "groceries",
        subcategoryId: "quick_delivery",
        merchantNormalized: "Zepto",
        categoryConfidence: 0.92,
        needsUserInput: false,
      },
      {
        ...baseRequest,
        categoryIds: ["groceries", "food", "bills", "transfer"],
        subcategoryTaxonomy: {groceries: ["quick_delivery", "supermarket"]},
        merchant: "zepto-stores@ybl",
        smsBody: "Rs 450 debited. Paid to ZEPTO via UPI",
      },
    );
    assert.equal(result.categoryId, "groceries");
    assert.equal(result.subcategoryId, "quick_delivery");
    assert.ok(
      (result.categoryConfidence ?? 0) >= AUTO_APPLY_CATEGORY_CONFIDENCE,
    );
    assert.equal(result.needsUserInput, false);
  });

  it("routes P2P person payment to inbox without food category", () => {
    const request: ClassifyRequest = {
      ...baseRequest,
      merchant: "P2A",
      smsBody: "Rs 500 paid to NIZAM M via UPI ref 123",
    };
    assert.equal(isLikelyP2PPayment(request), true);
    const result = parseClassifyResponse(
      {
        categoryId: "food",
        categoryConfidence: 0.95,
        userNotes: "lunch with friend",
        needsUserInput: false,
      },
      request,
    );
    assert.equal(result.categoryId, null);
    assert.equal(result.needsUserInput, true);
    assert.equal(result.userNotes, null);
  });

  it("allows userDescription path to set category and notes", () => {
    const result = parseClassifyResponse(
      {
        categoryId: "groceries",
        categoryConfidence: 0.95,
        userNotes: "milk and curd on Zepto",
        shoppingItems: ["milk", "curd"],
        needsUserInput: false,
      },
      {
        ...baseRequest,
        categoryIds: ["groceries", "food", "bills", "transfer"],
        userDescription: "milk, curd, dahi on Zepto — groceries",
      },
    );
    assert.equal(result.categoryId, "groceries");
    assert.equal(result.userNotes, "milk and curd on Zepto");
    assert.deepEqual(result.shoppingItems, ["milk", "curd"]);
  });
});
