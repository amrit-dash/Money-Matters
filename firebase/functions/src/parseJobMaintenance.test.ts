import {describe, it} from "node:test";
import assert from "node:assert/strict";

import {
  isStuckPendingJob,
  MAX_SYNC_NUDGES_PER_RUN,
  selectUidsForSyncNudge,
  shouldMarkStuck,
  STUCK_PENDING_MS,
  uidFromParseJobPath,
} from "./parseJobMaintenance";

describe("isStuckPendingJob", () => {
  const now = Date.parse("2026-06-03T12:00:00Z");

  it("returns false for done jobs", () => {
    assert.equal(
      isStuckPendingJob(
        {status: "done", updatedAt: new Date(now - STUCK_PENDING_MS - 1)},
        now,
      ),
      false,
    );
  });

  it("returns false when pending but within threshold", () => {
    assert.equal(
      isStuckPendingJob(
        {status: "pending", updatedAt: new Date(now - 30 * 60 * 1000)},
        now,
      ),
      false,
    );
  });

  it("returns true when pending beyond threshold", () => {
    assert.equal(
      isStuckPendingJob(
        {status: "pending", updatedAt: new Date(now - STUCK_PENDING_MS - 1)},
        now,
      ),
      true,
    );
  });

  it("returns false when updatedAt is missing", () => {
    assert.equal(
      isStuckPendingJob({status: "pending", updatedAt: null}, now),
      false,
    );
  });
});

describe("shouldMarkStuck", () => {
  it("marks first-time stuck pending jobs", () => {
    assert.equal(
      shouldMarkStuck({status: "pending", updatedAt: new Date(), stuckAt: null}),
      true,
    );
  });

  it("skips when stuckAt already set", () => {
    assert.equal(
      shouldMarkStuck({
        status: "pending",
        updatedAt: new Date(),
        stuckAt: new Date(),
      }),
      false,
    );
  });
});

describe("uidFromParseJobPath", () => {
  it("extracts uid from parse_jobs path", () => {
    assert.equal(
      uidFromParseJobPath("users/abc123/parse_jobs/job456"),
      "abc123",
    );
  });

  it("returns null for invalid paths", () => {
    assert.equal(uidFromParseJobPath("parse_jobs/job456"), null);
  });
});

describe("selectUidsForSyncNudge", () => {
  it("dedupes and caps uids", () => {
    const uids = ["a", "b", "a", "c", "d", "e"];
    const selected = selectUidsForSyncNudge(uids, 3);
    assert.deepEqual(selected, ["a", "b", "c"]);
  });

  it("defaults to MAX_SYNC_NUDGES_PER_RUN", () => {
    const many = Array.from({length: 50}, (_, i) => `uid-${i}`);
    assert.equal(
      selectUidsForSyncNudge(many).length,
      MAX_SYNC_NUDGES_PER_RUN,
    );
  });
});
