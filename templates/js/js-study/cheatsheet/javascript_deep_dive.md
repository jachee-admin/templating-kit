# JavaScript Deep Dive (Beyond Quick‑Ref)

A practical tour of behavior and edge cases you’ll hit in real apps.

---

## 1) Numbers & Precision

JS uses IEEE‑754 double floats.

```js
0.1 + 0.2            // 0.30000000000000004
Number.isNaN(NaN)    // true
Object.is(0, -0)     // false (they differ)
parseInt("08", 10)   // 8  (always pass radix)
```

**Tip:** Compare floats within a tolerance:

```js
const eq = (a,b,eps=1e-10) => Math.abs(a-b) < eps;
```

---

## 2) Strings & Templates

```js
const who = "Jen";
`Hello ${who}, 2+2=${2+2}`;
"multi\nline";
String(42);  (42).toString();
```

---

## 3) Objects & Property Mechanics

Property descriptors & immutability are shallow by default.

```js
Object.defineProperty(obj, "x", { value: 1, writable: false });
Object.freeze(obj);   // shallow; nested objects still mutable
```

Enumeration order (own properties) is well‑defined: integer-like keys in ascending order, then string keys in insertion order, then Symbols.

---

## 4) Copying: Shallow vs Deep

```js
const a = { nested: { x:1 } };
const shallow = { ...a };
shallow.nested.x = 2;            // a.nested.x also changes
const deep = structuredClone(a); // modern deep clone
```

---

## 5) Arrays: Performance Notes

- Many methods create new arrays (`map`, `filter`, `slice`, `concat`).

- Mutating ones: `sort`, `splice`, `reverse`, `fill`, `copyWithin`.

- Prefer immutable updates for predictable state.
  
  ```js
  const sorted = [...arr].sort((a,b)=>a-b);
  const inserted = [...arr.slice(0,i), v, ...arr.slice(i)];
  ```

---

## 6) Maps, Sets, WeakMaps

```js
const m = new Map(); m.set(obj, 1); m.get(obj);
const s = new Set([1,2,2]);  // -> {1,2}
const wm = new WeakMap();    // keys held weakly, good for caches
```

---

## 7) `this` Binding Rules

```js
const o = { x: 42, reg(){return this.x;}, arr: () => this.x };
o.reg(); // 42
o.arr(); // undefined (arrow uses outer 'this')

const f = o.reg; f();           // undefined in strict mode
const bound = o.reg.bind({x:7}); bound(); // 7
```

Use arrow functions for callbacks (lexical `this`), regular methods for object behavior.

---

## 8) Closures (why hooks work)

```js
function makeCounter() {
  let n = 0;
  return { inc: () => ++n, get: () => n };
}
const c = makeCounter(); c.inc(); c.get(); // 1
```

---

## 9) Classes & Private Fields

```js
class Person {
  #secret = 123;             // private field
  static count = 0;          // static property
  constructor(name){ this.name = name; Person.count++; }
  get upper(){ return this.name.toUpperCase(); }
  rename(n){ this.name = n; }
  static tally(){ return Person.count; }
}
```

Inheritance:

```js
class Admin extends Person {
  constructor(name, level){ super(name); this.level = level; }
  rename(n){ super.rename(`ADMIN-${n}`); }
}
```

---

## 10) Modules & Dynamic Import

Top‑level await works in ESM:

```js
const { heavy } = await import("./heavy.js");
```

Interoperability with CommonJS (Node): prefer ESM; when mixing, be aware of default vs named import quirks.

---

## 11) Promises, Cancellation, Combinators

```js
const ac = new AbortController();
fetch("/api", { signal: ac.signal });
ac.abort(); // cancel
```

Combinators:

```js
await Promise.all([p1, p2]);        // fail-fast
await Promise.allSettled([p1, p2]); // always resolve with statuses
await Promise.race([p1, p2]);       // first settled wins
await Promise.any([p1, p2]);        // first fulfilled wins
```

Timeout wrapper:

```js
const timeout = (ms) => new Promise((_,rej) => setTimeout(()=>rej(new Error("Timeout")),ms));
await Promise.race([fetch(url), timeout(5000)]);
```

---

## 12) Event Loop: Microtasks vs Macrotasks

Execution order within a tick:

1) Run all synchronous code
2) Flush **microtasks** (Promise then/catch/finally, queueMicrotask)
3) Run one **macrotask** (setTimeout, setInterval, I/O)

```js
console.log("A");
queueMicrotask(()=>console.log("micro"));
setTimeout(()=>console.log("macro"));
Promise.resolve().then(()=>console.log("then"));
console.log("B");
// A B micro then macro (microtask queue order may vary slightly with env)
```

---

## 13) Iterables, Generators, Async Generators

```js
const iterable = {
  *[Symbol.iterator]() { yield 1; yield 2; }
};
for (const n of iterable) {}

async function* stream(){ yield 1; yield 2; }
for await (const n of stream()) {}
```

---

## 14) Symbols & Well‑Known Symbols

```js
const tag = Symbol("tag");
obj[tag] = 123;     // non‑colliding property key

// Make a class iterable:
class Bag {
  constructor(...items){ this.items = items; }
  *[Symbol.iterator](){ yield* this.items; }
}
```

---

## 15) Dates, Time Zones, Intl

- `new Date("2025-09-01")` parses in local time for bare dates (browser), but may vary; prefer ISO with timezone or use a library.
- Use `Intl.DateTimeFormat` and `Intl.NumberFormat` for display.
- Avoid manual locale formatting.

```js
new Intl.DateTimeFormat("en-US",{ dateStyle:"medium", timeStyle:"short"}).format(new Date());
```

---

## 16) JSON, Serialization & Cloning

- `JSON.stringify` drops functions/undefined/symbols; Dates become ISO strings.
- Modern deep clone: `structuredClone(obj)` keeps Maps/Sets/TypedArrays/Date.

---

## 17) Regex Tips

- Always anchor if you expect full‑string match: `/^...\$/`.
- Use non‑capturing groups `(?: )` when you don’t need captures.
- Flags: `i` case‑insensitive, `g` global, `m` multiline, `s` dotAll, `u` unicode.

```js
/^(?:\+1\s?)?\d{3}-\d{3}-\d{4}$/u.test("555-123-4567");
```

---

## 18) Performance & Memory

- Debounce user typing; throttle scroll/resize handlers.
- Avoid creating new functions inside tight loops when hot.
- Use **WeakMap** to cache metadata without preventing GC.

```js
export const debounce = (fn, ms=300) => { let t; return (...a)=>{ clearTimeout(t); t=setTimeout(()=>fn(...a), ms); }; };
export const throttle = (fn, ms=300) => { let t=0; return (...a)=>{ const n=Date.now(); if(n-t>=ms){ t=n; fn(...a); } }; };
```

---

## 19) Error Handling Patterns

- Throw **Error** instances (not strings).

- Add `cause` for chained errors (Node 16+/modern runtimes):
  
  ```js
  try { risky(); }
  catch (e) { throw new Error("Failed to save", { cause: e }); }
  ```

- Normalize user‑facing messages; log technical details elsewhere.

---

## 20) Cookbook Extras

```js
// Safe JSON parse
export const safeJson = (s) => { try { return JSON.parse(s); } catch { return null; } };

// Group by key
export const groupBy = (arr, key) =>
  arr.reduce((acc, it) => ((acc[it[key]] ??= []).push(it), acc), {});

// Memoize (args by JSON)
export const memo = (fn) => {
  const cache = new Map();
  return (...args) => {
    const k = JSON.stringify(args);
    if (cache.has(k)) return cache.get(k);
    const v = fn(...args); cache.set(k, v); return v;
  };
};

// Once
export const once = (fn) => {
  let done = false, val;
  return (...args) => done ? val : (done = true, val = fn(...args));
};
```

---

## 21) Modern Features to Lean On

- Optional chaining `?.`, nullish coalescing `??`, logical assignment `||= &&= ??=`
- Private class fields `#x`
- `Promise.allSettled`, `Promise.any`
- Top‑level `await` (ESM)
- `structuredClone`, `Object.hasOwn`, `Array.prototype.at`, `flat`, `flatMap`

---

**Final advice:** Prefer simple data/logic, copy before mutating, make async flows explicit (`async/await`), and keep your mental model of the event loop sharp.
