import {describe, it} from "node:test";
import assert from "node:assert/strict";

import {
  buildOpenAiCompatibleClassifyBody,
  filterGrokChatModelIds,
} from "./providers";
import type {ProviderCredentials} from "./providers";

const grokCreds: ProviderCredentials = {
  provider: "grok",
  apiKey: "test-key",
  model: "grok-4.3",
};

describe("filterGrokChatModelIds", () => {
  it("drops vision, image, and embedding models", () => {
    const filtered = filterGrokChatModelIds([
      "grok-4.3",
      "grok-2-vision-1212",
      "grok-image-gen",
      "grok-embed-v1",
      "grok-4-fast-non-reasoning",
    ]);
    assert.deepEqual(filtered, ["grok-4.3", "grok-4-fast-non-reasoning"]);
  });
});

describe("buildOpenAiCompatibleClassifyBody", () => {
  it("uses max_completion_tokens and reasoning_effort for Grok", () => {
    const body = buildOpenAiCompatibleClassifyBody(grokCreds, {
      merchant: "Zepto",
      smsBody: "debited",
    });
    assert.equal(body.model, "grok-4.3");
    assert.equal(body.max_completion_tokens, 2048);
    assert.equal(body.reasoning_effort, "low");
    assert.equal(body.max_tokens, undefined);
    assert.deepEqual(body.response_format, {type: "json_object"});
  });

  it("uses max_tokens for non-Grok OpenAI-compatible providers", () => {
    const body = buildOpenAiCompatibleClassifyBody(
      {provider: "mistral", apiKey: "k", model: "mistral-small-latest"},
      {},
    );
    assert.equal(body.max_tokens, 512);
    assert.equal(body.max_completion_tokens, undefined);
    assert.equal(body.reasoning_effort, undefined);
  });
});
