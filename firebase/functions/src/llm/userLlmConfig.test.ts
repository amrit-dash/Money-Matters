import {describe, it} from "node:test";
import assert from "node:assert/strict";

import {resolveApiKeyForProvider, resolveModelForProvider} from "./userLlmConfig";
import type {StoredUserLlmConfig} from "./userLlmConfig";

function stored(
  partial: Partial<StoredUserLlmConfig> & Pick<StoredUserLlmConfig, "provider">,
): StoredUserLlmConfig {
  return {
    enabled: false,
    apiKeys: {},
    models: {},
    apiKey: null,
    model: null,
    baseUrl: null,
    updatedAt: null,
    ...partial,
  };
}

describe("resolveApiKeyForProvider", () => {
  it("prefers inline request key", () => {
    const config = stored({
      provider: "gemini",
      apiKeys: {gemini: "stored-gem"},
    });
    assert.equal(
      resolveApiKeyForProvider("grok", "inline-xai", config),
      "inline-xai",
    );
  });

  it("uses per-provider map entry", () => {
    const config = stored({
      provider: "gemini",
      apiKeys: {gemini: "gem", grok: "xai"},
    });
    assert.equal(resolveApiKeyForProvider("grok", null, config), "xai");
  });

  it("does not use another provider legacy apiKey", () => {
    const config = stored({
      provider: "gemini",
      apiKey: "gem-only",
      apiKeys: {},
    });
    assert.equal(resolveApiKeyForProvider("grok", null, config), null);
  });

  it("falls back to legacy apiKey when provider matches", () => {
    const config = stored({
      provider: "gemini",
      apiKey: "gem-only",
      apiKeys: {},
    });
    assert.equal(resolveApiKeyForProvider("gemini", null, config), "gem-only");
  });
});

describe("resolveModelForProvider", () => {
  it("prefers per-provider models map", () => {
    assert.equal(
      resolveModelForProvider("grok", {grok: "grok-4.3"}, "grok-2-latest"),
      "grok-4.3",
    );
  });

  it("falls back to legacy model then default", () => {
    assert.equal(
      resolveModelForProvider("grok", {}, "grok-2-latest"),
      "grok-2-latest",
    );
    assert.equal(resolveModelForProvider("grok", {}, null), "grok-4.3");
  });
});
