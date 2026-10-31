interface Entry {
  failures: number;
  level: number;
  lockedUntil: number;
  lastFailure: number;
}

export class IpLimiter {
  static readonly maxFailures = 5;
  static readonly baseLock = 30;
  static readonly maxLock = 900;
  static readonly decayAfter = 1800;

  private entries = new Map<string, Entry>();

  constructor(private now: () => number) {}

  retryAfter(ip: string): number {
    const entry = this.entries.get(ip);
    if (!entry) return 0;
    return Math.max(0, Math.ceil(entry.lockedUntil - this.now()));
  }

  isLocked(ip: string): boolean {
    return this.retryAfter(ip) > 0;
  }

  recordFailure(ip: string): void {
    const now = this.now();
    let entry = this.entries.get(ip);
    if (entry && now - entry.lastFailure > IpLimiter.decayAfter && now >= entry.lockedUntil) {
      entry = undefined;
    }
    entry ??= { failures: 0, level: 0, lockedUntil: 0, lastFailure: now };
    entry.failures += 1;
    entry.lastFailure = now;
    if (entry.failures >= IpLimiter.maxFailures) {
      entry.lockedUntil = now + Math.min(IpLimiter.baseLock * 2 ** entry.level, IpLimiter.maxLock);
      entry.level += 1;
      entry.failures = 0;
    }
    this.entries.set(ip, entry);
    this.prune(now);
  }

  recordSuccess(ip: string): void {
    const entry = this.entries.get(ip);
    if (entry) entry.failures = 0;
  }

  private prune(now: number): void {
    if (this.entries.size < 5000) return;
    for (const [ip, entry] of this.entries) {
      if (now - entry.lastFailure > IpLimiter.decayAfter && now >= entry.lockedUntil) this.entries.delete(ip);
    }
  }
}
