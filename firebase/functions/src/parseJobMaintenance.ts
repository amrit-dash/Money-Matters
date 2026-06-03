/**
 * Pure helpers for stuck parse-job detection and FCM sync nudges.
 * Used by the scheduled retryStuckParseJobs function (Phase 3).
 */

/** Pending jobs older than this are considered stuck (ms). */
export const STUCK_PENDING_MS = 2 * 60 * 60 * 1000;

/** Do not send more than one sync nudge per user per scheduler run. */
export const MAX_SYNC_NUDGES_PER_RUN = 20;

export interface ParseJobTimestamps {
  status: string;
  updatedAt: Date | null;
  stuckAt?: Date | null;
}

/**
 * True when a pending parse job has exceeded the stuck threshold.
 */
export function isStuckPendingJob(
  job: ParseJobTimestamps,
  nowMs: number,
  thresholdMs: number = STUCK_PENDING_MS,
): boolean {
  if (job.status !== "pending") return false;
  if (job.updatedAt == null) return false;
  return nowMs - job.updatedAt.getTime() >= thresholdMs;
}

/**
 * Whether we should set stuckAt on a job (first time only).
 */
export function shouldMarkStuck(job: ParseJobTimestamps): boolean {
  return job.status === "pending" && job.stuckAt == null;
}

/**
 * Extract uid from a collection-group document path:
 * users/{uid}/parse_jobs/{jobId}
 */
export function uidFromParseJobPath(path: string): string | null {
  const parts = path.split("/");
  const usersIdx = parts.indexOf("users");
  if (usersIdx === -1 || usersIdx + 1 >= parts.length) return null;
  return parts[usersIdx + 1] ?? null;
}

/**
 * Pick uids that should receive a sync nudge this run (deduped, capped).
 */
export function selectUidsForSyncNudge(
  uids: string[],
  max: number = MAX_SYNC_NUDGES_PER_RUN,
): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const uid of uids) {
    if (seen.has(uid)) continue;
    seen.add(uid);
    out.push(uid);
    if (out.length >= max) break;
  }
  return out;
}
