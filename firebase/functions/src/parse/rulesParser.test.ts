import {describe, it} from "node:test";
import assert from "node:assert/strict";

import {parseRawIngestRules, extractInstrumentLast4} from "./rulesParser";
import {matchPaymentSourceFromIngest, matchCategory} from "./paymentSourceMatch";

function sampleIngest(body: string, sender = "VK-HDFCBK") {
  return {
    id: "ingest-1",
    body,
    sender,
    receivedAt: new Date("2026-05-29T09:02:00.000Z"),
  };
}

describe("parseRawIngestRules", () => {
  it("AE4: parses HDFC debit with amount, merchant, and last-4", () => {
    const result = parseRawIngestRules(sampleIngest(
      "Rs.899 debited from A/c **4567 at ZUDIO on 29-05-26. Avl bal Rs.12,000.",
    ));

    assert.equal(result.classification, "transaction");
    assert.ok(result.candidate);
    assert.equal(result.candidate!.amount, 899);
    assert.equal(result.candidate!.merchant, "ZUDIO");
    assert.equal(result.candidate!.instrumentLast4, "4567");
    assert.equal(result.candidate!.type, "debit");
    assert.equal(result.candidate!.ambiguous, false);
  });

  it("AE3: classifies credit card bill due as billing reminder", () => {
    const result = parseRawIngestRules(sampleIngest(
      "Your HDFC Bank credit card bill due on 05-Jun. Min due Rs.500. Pay now.",
    ));

    assert.equal(result.classification, "billingReminder");
    assert.equal(result.candidate, undefined);
  });

  it("rejects loan-offer promo with credit verb", () => {
    const result = parseRawIngestRules(sampleIngest(
      "Congratulations! You are eligible for a pre-approved personal loan. " +
      "Get Rs.6,00,130 credited instantly to your A/c. Apply now! T&C apply.",
    ));

    assert.equal(result.classification, "promo");
    assert.equal(result.candidate, undefined);
  });

  it("AE8: flags UPI person payment as ambiguous", () => {
    const result = parseRawIngestRules(sampleIngest(
      "Rs.500 debited from A/c **1234 for UPI/AMRIT K/paytm/ on 29-05-26.",
    ));

    assert.equal(result.classification, "transaction");
    assert.equal(result.candidate!.merchant, "AMRIT K");
    assert.equal(result.candidate!.ambiguous, true);
  });

  it("parses Federal Bank UPI sent SMS", () => {
    const result = parseRawIngestRules(sampleIngest(
      "Rs 10.00 sent via UPI on 31-05-2026 at 02:50:52 to amrit.dash60-4@." +
      "Ref:615162984499.Not you? -Federal Bank",
      "manual-paste",
    ));

    assert.equal(result.classification, "transaction");
    assert.equal(result.candidate!.amount, 10);
    assert.equal(result.candidate!.merchant, "AMRIT.DASH60-4@");
    assert.equal(result.candidate!.ambiguous, true);
  });
});

describe("matchPaymentSourceFromIngest", () => {
  it("links by last4", () => {
    const match = matchPaymentSourceFromIngest({
      sender: "VK-HDFCBK",
      body: "Rs.899 debited from A/c **4567 at ZUDIO on 29-05-26.",
      instrumentLast4: "4567",
      merchant: "ZUDIO",
      sources: [{
        id: "card-zudio",
        name: "HDFC Credit",
        last4: "4567",
        senderHints: ["hdfcbk"],
        merchantHints: [],
        bodyPatterns: [],
      }],
    });
    assert.equal(match, "card-zudio");
  });
});

describe("matchCategory", () => {
  it("matches merchant rule", () => {
    const id = matchCategory("SWIGGY", [{
      id: "food",
      merchantRules: ["SWIGGY", "ZOMATO"],
    }]);
    assert.equal(id, "food");
  });
});

describe("extractInstrumentLast4", () => {
  it("extracts from Acct XX123", () => {
    assert.equal(
      extractInstrumentLast4(
        "ICICI Bank Acct XX123 debited for Rs 500.00 on 29-May-26;",
      ),
      "0123",
    );
  });
});
