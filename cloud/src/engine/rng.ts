import { randomBytes } from "node:crypto";

export interface Rng {
  next(): bigint;
}

const MASK = (1n << 64n) - 1n;

export class SeededGenerator implements Rng {
  private state: bigint;

  constructor(seed: bigint | number) {
    this.state = BigInt.asUintN(64, BigInt(seed));
  }

  next(): bigint {
    this.state = (this.state + 0x9e3779b97f4a7c15n) & MASK;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK;
    return z ^ (z >> 31n);
  }
}

export class SystemRng implements Rng {
  next(): bigint {
    return randomBytes(8).readBigUInt64LE();
  }
}

function nextBelow(rng: Rng, upperBound: bigint): bigint {
  const tmp = (MASK % upperBound) + 1n;
  const range = tmp === upperBound ? 0n : tmp;
  let product = rng.next() * upperBound;
  while ((product & MASK) < range) {
    product = rng.next() * upperBound;
  }
  return product >> 64n;
}

export function randomInt(rng: Rng, upperExclusive: number): number {
  return Number(nextBelow(rng, BigInt(upperExclusive)));
}

export function shuffled<T>(items: readonly T[], rng: Rng): T[] {
  const out = [...items];
  let amount = out.length;
  let index = 0;
  while (amount > 1) {
    const offset = randomInt(rng, amount);
    amount -= 1;
    const a = out[index]!;
    out[index] = out[index + offset]!;
    out[index + offset] = a;
    index += 1;
  }
  return out;
}
