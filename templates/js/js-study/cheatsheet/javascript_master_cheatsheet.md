# JavaScript — Master Cheat Sheet (Language‑Focused)

**For:** Full‑stack Next.js/Tailwind devs who want a deep, practical JS language reference.  
**Scope:** Core syntax, runtime behavior, modern features (ES2015+), patterns, and gotchas you’ll actually hit in production.

---

## 0) Everyday Quick‑Ref (90% of usage)

```js
// Declaring
const x = 1;           // prefer const
let y = 2;             // use let if you must reassign
// var -> function-scoped (avoid)

// Equality & nullish
if (a === b) { /* strict compare */ }
const name = user?.profile?.name ?? "Anon"; // safe access + default for null/undefined

// Arrays
const xs = [1,2,3];
xs.map(x => x * 2);
xs.filter(x => x > 1);
xs.reduce((sum, x) => sum + x, 0);
xs.find(x => x === 2);
xs.includes(2);
xs.flatMap(x => [x, x+10]);

// Objects
const user = { id: 1, name: "Ava" };
const { name, ...rest } = user;         // destructure + rest
const u2 = { ...user, active: true };   // spread copy

// Functions
const add = (a, b = 0) => a + b;        // default param + arrow
function fn(...args) { return args.length; } // rest param

// Async
const data = await fetch("/api").then(r => r.json()); // promise
// or
const r = await fetch("/api"); const data2 = await r.json();

// Errors
try { risky(); } catch (err) { console.error(err); }

// Modules (ESM)
export const PI = 3.14; export default function area(r){ return PI*r*r; }
import area, { PI } from "./math.js";
```

---

## 1) Types & Values

**Primitives:** `number`, `string`, `boolean`, `null`, `undefined`, `symbol`, `bigint`  
**Objects:** plain objects, arrays, functions, dates, maps/sets, etc.

```js
typeof 42            // "number"
typeof "hi"          // "string"
typeof null          // "object"  <-- historical quirk
typeof []            // "object"
Array.isArray([])    // true
typeof 10n           // "bigint"
typeof Symbol()      // "symbol"
```

**Truthy/Falsey (only these are falsey):** `false, 0, -0, 0n, "", null, undefined, NaN`

**Numbers:** IEEE‑754 floating point → watch for precision (`0.1 + 0.2 !== 0.3`).  
Use `Number.isNaN(x)` (not `isNaN`), and `Object.is(0, -0)` if you care about `-0`.

```js
Number("08")          // 8
parseInt("08", 10)    // 8  (always pass radix)
Number.isNaN(NaN)     // true
Object.is(0, -0)      // false
```

**Strings:** Template literals:

```js
const who = "Jen";
const msg = `Hello ${who}, 2 + 2 = ${2 + 2}`;
```

---

## 2) Variables, Scope, Hoisting

- `let` / `const` are **block‑scoped**; `var` is function‑scoped (avoid).  
- Function declarations are hoisted; arrow/function expressions are not.

```js
sayHi();               // ok
function sayHi(){}

nope();                // ReferenceError
const nope = () => {};
```

---

## 3) Objects & Arrays Deep‑Dive

**Create & access**

```js
const o = { a: 1, "str key": 2 };
o.a; o["str key"];
const key = "a"; o[key];      // computed access
```

**Destructuring & defaults**

```js
const { a = 0, b: aliasB = 5 } = { a: 1 };  // alias + default
const [first = 0, , third = 3] = [10, 20];  // skip + default
```

**Spread/Rest**

```js
const p = { x:1, y:2 };
const q = { ...p, y: 3 };     // copy + override
function f(a, ...rest) {}
```

**Object utilities**

```js
Object.keys(o); Object.values(o); Object.entries(o);
Object.fromEntries([["x",1],["y",2]]);     // { x:1, y:2 }
Object.hasOwn(o, "a");                     // own property check
Object.freeze(o);                           // make immutable (shallow)
```

**Array utilities you’ll use daily**

```js
arr.slice(1, 3);           // non-mutating
arr.splice(1, 1);          // mutates
arr.concat([4,5]);         // new array
arr.flat(2);               // flatten depth=2
arr.every(fn); arr.some(fn);
arr.sort((a,b) => a-b);    // beware: mutates; copy first: [...arr].sort(...)
```

**Maps/Sets (when keys aren’t strings)**  

```js
const m = new Map(); m.set(obj, 1); m.get(obj);
const s = new Set([1,2,2]); // {1,2}
```

**WeakMap/WeakSet** → keys don’t prevent GC (good for caches).

---

## 4) Functions, `this`, Closures

**Forms:**

```js
function decl(a,b){ return a+b; }            // declaration (hoisted)
const expr = function(a,b){ return a+b; };   // expression
const arrow = (a,b) => a+b;                  // arrow (lexical this)
```

**`this` rules (core):**

- Regular methods: `obj.method()` → `this === obj`
- Standalone functions: `this` is `undefined` (strict) or global (sloppy)
- Arrow functions: **no own `this`**; use the surrounding `this`

```js
const obj = {
  x: 42,
  m(){ return this.x; },          // 42
  a: () => this.x                 // usually undefined here
};
obj.m(); obj.a();

const bound = obj.m.bind({ x: 7 }); bound(); // 7
```

**Closures:** inner functions capture outer variables (basis for React hooks).  

```js
function makeCounter(){ let n = 0; return () => ++n; }
const c = makeCounter(); c(); c(); // 1, 2
```

---

## 5) Modules (ESM) & Dynamic Import

```js
// math.js
export const PI = 3.14;
export default function area(r){ return PI * r * r; }

// use
import area, { PI } from "./math.js";

// dynamic import (code-splitting)
const { heavy } = await import("./heavy.js");
```

Top‑level `await` works in ES modules (Node/modern bundlers).

---

## 6) Classes & Prototypes

**Prototype chain:** methods are looked up via `__proto__`.  
**Class syntax:** sugar over prototypes.

```js
class Person {
  #secret = 123;                     // private field
  static species = "H. sapiens";     // static
  constructor(name){ this.name = name; }
  get upper() { return this.name.toUpperCase(); }
  say(){ return `Hi ${this.name}`; }
  static kind(){ return Person.species; }
}
class Admin extends Person {
  constructor(name, level){ super(name); this.level = level; }
}
```

Use classes sparingly; functions + objects are often simpler.

---

## 7) Promises, Async/Await, Event Loop

**Promises & combinators**

```js
const p = fetch("/api").then(r => r.json());
const [a, b] = await Promise.all([p1, p2]);        // fail-fast
const r = await Promise.allSettled([p1, p2]);      // never throws
const first = await Promise.race([p1, p2]);        // first settled
const ok = await Promise.any([p1, p2]);            // first fulfilled
```

**`async/await`**

```js
async function load() {
  try {
    const r = await fetch("/api");
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return await r.json();
  } catch (err) {
    // handle/log
    throw err;
  }
}
```

**Event loop order (know this):**

```js
console.log("A");
setTimeout(() => console.log("B"));           // macrotask
Promise.resolve().then(() => console.log("C")); // microtask
console.log("D");
// A D C B
```

**Timeout wrapper**

```js
const withTimeout = (p, ms=5000) =>
  Promise.race([p, new Promise((_,rej) => setTimeout(() => rej(new Error("Timeout")), ms))]);
```

---

## 8) Iterables, Generators & Async Generators

```js
function* seq(){ yield 1; yield 2; }
for (const n of seq()) {}

async function* stream(){ yield 1; yield 2; }
for await (const n of stream()) {}
```

Make your objects iterable by adding `[Symbol.iterator]`.

---

## 9) Symbols, BigInt

```js
const tag = Symbol("tag");      // unique key
const id = 9007199254740993n;   // BigInt (no mixing with Number without conversion)
```

---

## 10) Dates, Intl, URL, RegExp

```js
// Dates
const d = new Date();
d.toISOString();                        // "2025-09-01T..."
// Intl
new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(1234.5);
// URL
const u = new URL("/path?x=1", "https://site.com"); u.searchParams.get("x"); // "1"
// RegExp
/^\d{4}-\d{2}-\d{2}$/.test("2025-09-01"); // true
```

---

## 11) Errors & Custom Errors

```js
class AppError extends Error {
  constructor(msg, code){ super(msg); this.name = "AppError"; this.code = code; }
}
try { throw new AppError("Bad input", 400); }
catch (e) { if (e instanceof AppError) console.error(e.code); }
```

Always throw **Error** instances (not strings).

---

## 12) JSON, Cloning, Immutability

```js
JSON.stringify({ a:1 });                // to JSON
JSON.parse('{"a":1}');                  // from JSON

// Deep clone (modern)
const copy = structuredClone(obj);      // keeps Dates/Maps/Sets etc.
// Fallback (loses Dates/Funcs): JSON.parse(JSON.stringify(obj))
```

Prefer **immutable updates** (copy + change) to avoid accidental shared state.

---

## 13) Logical & Nullish Operators

```js
// Nullish coalescing: only default on null/undefined
const n = value ?? 0;

// Optional chaining
const city = user?.address?.city;

// Logical assignment
a ||= 1;   // if (!a) a = 1;
b &&= 2;   // if (b) b = 2;
c ??= 3;   // if (c == null) c = 3;
```

---

## 14) Performance Patterns

**Debounce / Throttle**

```js
export function debounce(fn, ms=300){
  let t; return (...args)=>{ clearTimeout(t); t=setTimeout(()=>fn(...args), ms); };
}
export function throttle(fn, ms=300){
  let t=0; return (...args)=>{ const now=Date.now(); if(now-t>=ms){ t=now; fn(...args);} };
}
```

**Copy before mutating**

```js
const sorted = [...arr].sort((a,b)=>a-b);
const updated = { ...obj, name: "New" };
```

---

## 15) Common Gotchas (read twice)

- `==` does coercion → **use `===`**.  
- `NaN !== NaN` → use `Number.isNaN(x)`.  
- `typeof null === "object"` (quirk).  
- `parseInt("08")` → always pass radix: `parseInt("08", 10)`.  
- Array methods like `sort`, `splice` **mutate**; copy first if needed.  
- Arrow functions don’t have their own `this`/`arguments`.  
- Don’t rely on property enumeration order (unless spec guarantees it for your case).  
- JSON can’t serialize functions/undefined/symbols; dates become strings.

---

## 16) Cookbook Snippets

```js
// Safe JSON parse
export const safeJson = (s) => { try { return JSON.parse(s); } catch { return null; } };

// Group by key
export const groupBy = (arr, key) =>
  arr.reduce((acc, item) => ((acc[item[key]] ??= []).push(item), acc), {});

// Memoize (simple)
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

## 17) Modern Features to Know (usable today)

- Optional chaining `?.` & nullish coalescing `??`  
- Logical assignment `||=`, `&&=`, `??=`  
- `Promise.allSettled`, `Promise.any`  
- Private class fields `#field` and static blocks  
- Top‑level `await` (ESM)  
- `structuredClone`, `Object.hasOwn`, `Array.prototype.at`, `flat`, `flatMap`

---

## 18) Minimal Interop with TypeScript (handy when projects use TS)

```ts
type User = { id: string; name?: string };
function greet(u: User): string { return `Hi ${u.name ?? "Anon"}`; }
function sum(a: number, b: number = 0): number { return a + b; }
```

Even if you write JS, understanding these signatures helps when reading TS code in Next.js apps.

---

## 19) Practice Ideas (apply immediately)

- Rewrite loops with `map/filter/reduce`.  
- Add `safeJson` where you parse unknown responses.  
- Replace a noisy effect with a **debounced** handler.  
- Write a **timeout wrapper** around a slow fetch.  
- Use **optional chaining** throughout to remove defensive `&&` ladders.

---

### Final Mental Model

**Server or client, JS is JS.** Keep data immutable unless mutation is intentional; prefer small pure functions; know the event loop; embrace promises with `async/await`; copy before mutating; reach for modern language features; and always measure before “optimizing.”

— End —
