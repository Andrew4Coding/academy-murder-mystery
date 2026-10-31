export class DecodeError extends Error {}

export interface Codec<T> {
  dec(json: unknown, path?: string): T;
  enc(value: T): unknown;
  optional?: boolean;
}

type Infer<C> = C extends Codec<infer T> ? T : never;

function fail(path: string, expected: string, got: unknown): never {
  throw new DecodeError(`${path || "$"}: expected ${expected}, got ${JSON.stringify(got)?.slice(0, 80)}`);
}

export const num: Codec<number> = {
  dec: (j, p = "") => (typeof j === "number" && Number.isFinite(j) ? j : fail(p, "number", j)),
  enc: (v) => v
};

export const int: Codec<number> = {
  dec: (j, p = "") => (typeof j === "number" && Number.isInteger(j) ? j : fail(p, "integer", j)),
  enc: (v) => v
};

export const str: Codec<string> = {
  dec: (j, p = "") => (typeof j === "string" ? j : fail(p, "string", j)),
  enc: (v) => v
};

export const bool: Codec<boolean> = {
  dec: (j, p = "") => (typeof j === "boolean" ? j : fail(p, "boolean", j)),
  enc: (v) => v
};

const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

export const uuid: Codec<string> = {
  dec: (j, p = "") => (typeof j === "string" && UUID_RE.test(j) ? j.toUpperCase() : fail(p, "uuid", j)),
  enc: (v) => v
};

const BASE64_RE = /^[A-Za-z0-9+/]*={0,2}$/;

export const data: Codec<Buffer> = {
  dec: (j, p = "") => (typeof j === "string" && BASE64_RE.test(j) ? Buffer.from(j, "base64") : fail(p, "base64", j)),
  enc: (v) => v.toString("base64")
};

export function optional<T>(inner: Codec<T>): Codec<T | undefined> {
  return {
    optional: true,
    dec: (j, p) => (j === undefined || j === null ? undefined : inner.dec(j, p)),
    enc: (v) => (v === undefined ? undefined : inner.enc(v))
  };
}

export function array<T>(inner: Codec<T>): Codec<T[]> {
  return {
    dec: (j, p = "") => (Array.isArray(j) ? j.map((x, i) => inner.dec(x, `${p}[${i}]`)) : fail(p, "array", j)),
    enc: (v) => v.map((x) => inner.enc(x))
  };
}

export function set<T>(inner: Codec<T>): Codec<Set<T>> {
  return {
    dec: (j, p = "") => (Array.isArray(j) ? new Set(j.map((x, i) => inner.dec(x, `${p}[${i}]`))) : fail(p, "array", j)),
    enc: (v) => [...v].map((x) => inner.enc(x))
  };
}

export function flatMap<K, V>(key: Codec<K>, value: Codec<V>): Codec<Map<K, V>> {
  return {
    dec: (j, p = "") => {
      if (!Array.isArray(j) || j.length % 2 !== 0) return fail(p, "flat key/value array", j);
      const out = new Map<K, V>();
      for (let i = 0; i < j.length; i += 2) {
        out.set(key.dec(j[i], `${p}[${i}]`), value.dec(j[i + 1], `${p}[${i + 1}]`));
      }
      return out;
    },
    enc: (v) => {
      const out: unknown[] = [];
      for (const [k, x] of v) out.push(key.enc(k), value.enc(x));
      return out;
    }
  };
}

export function rawEnum<const V extends readonly (string | number)[]>(values: V): Codec<V[number]> {
  return {
    dec: (j, p = "") => (values.includes(j as never) ? (j as V[number]) : fail(p, `one of ${values.join("|")}`, j)),
    enc: (v) => v
  };
}

type Fields = Record<string, Codec<any>>;
type StructOf<F extends Fields> = { [K in keyof F]: Infer<F[K]> };

export function struct<F extends Fields>(fields: F): Codec<StructOf<F>> {
  const names = Object.keys(fields);
  return {
    dec: (j, p = "") => {
      if (typeof j !== "object" || j === null || Array.isArray(j)) return fail(p, "object", j);
      const src = j as Record<string, unknown>;
      const out: Record<string, unknown> = {};
      for (const name of names) {
        const codec = fields[name]!;
        const raw = src[name];
        if ((raw === undefined || raw === null) && !codec.optional) fail(`${p}.${name}`, "a value", raw);
        out[name] = codec.dec(raw, `${p}.${name}`);
      }
      return out as StructOf<F>;
    },
    enc: (v) => {
      const out: Record<string, unknown> = {};
      for (const name of names) {
        const value = (v as Record<string, unknown>)[name];
        if (value === undefined) continue;
        const encoded = fields[name]!.enc(value);
        if (encoded !== undefined) out[name] = encoded;
      }
      return out;
    }
  };
}

type UnionOf<D extends Record<string, Fields>> = {
  [K in keyof D & string]: { case: K } & StructOf<D[K]>;
}[keyof D & string];

export function union<D extends Record<string, Fields>>(defs: D): Codec<UnionOf<D>> {
  const payloads = Object.fromEntries(Object.entries(defs).map(([name, f]) => [name, struct(f)]));
  return {
    dec: (j, p = "") => {
      if (typeof j !== "object" || j === null || Array.isArray(j)) return fail(p, "enum object", j);
      const keys = Object.keys(j);
      if (keys.length !== 1) return fail(p, "single-key enum object", j);
      const name = keys[0]!;
      const codec = payloads[name];
      if (!codec) return fail(p, `case in ${Object.keys(defs).join("|")}`, name);
      return { case: name, ...codec.dec((j as Record<string, unknown>)[name], `${p}.${name}`) } as UnionOf<D>;
    },
    enc: (v) => {
      const { case: name, ...rest } = v as Record<string, unknown> & { case: string };
      return { [name]: payloads[name]!.enc(rest) };
    }
  };
}

export function lazy<T>(make: () => Codec<T>): Codec<T> {
  let cached: Codec<T> | undefined;
  const get = () => (cached ??= make());
  return { dec: (j, p) => get().dec(j, p), enc: (v) => get().enc(v) };
}

export type { Infer };
