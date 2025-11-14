# JavaScript Learning Cheat Sheet — ELI10 → Intermediate (Next.js-Friendly)

This is a **hands-on** guide you can keep open while coding. Learn the small pieces first, then combine them.

---

## 0) Quick setup
- Install Node.js (LTS). In a project: `pnpm init -y` (or `npm init -y`).
- Run a file: `node script.js`.
- Log anything: `console.log(value)`.

---

## 1) Values & variables
```js
// Prefer const; use let if you need to reassign; avoid var.
const x = 10;          // constant binding
let y = 5;             // can change: y = 6

// Primitive types: number, string, boolean, null, undefined, symbol, bigint
const n = 42;          // number (integers & floats)
const s = "hello";     // string (use backticks for interpolation)
const flag = true;
const nope = null;     // "no value on purpose"
let missing;           // undefined
```

**Template literals** (backticks) for nice strings:
```js
const name = "Jen";
console.log(`Hi ${name}, 2+2=${2+2}`);
```

---

## 2) Objects & arrays
```js
const user = { id: 1, name: "Ava" };     // object (key-value)
const nums = [1, 2, 3];                  // array (ordered list)

// Read/update
console.log(user.name);      // "Ava"
user.name = "Eve";

// Add/remove array items
nums.push(4);        // [1,2,3,4]
nums.pop();          // back to [1,2,3]
nums.unshift(0);     // [0,1,2,3]
nums.shift();        // [1,2,3]
```

**Copy vs reference** (important!):
```js
const a = { v: 1 };
const b = a;            // b references the same object as a
b.v = 2;                // a.v is now 2 as well!

const clone = { ...a }; // shallow copy
clone.v = 3;            // a.v stays 2
```

---

## 3) Destructuring, rest & spread (bread-and-butter)
```js
const person = { id: 1, name: "Eve", age: 30 };
const { name, age } = person;          // object destructure
const arr = [10, 20, 30];
const [first, , third] = arr;          // array destructure

const extended = { ...person, active: true };    // spread
const all = [0, ...arr, 40];                     // spread arrays

function sum(...nums) {                           // rest
  return nums.reduce((a, b) => a + b, 0);
}
```

---

## 4) Functions
```js
// Function declaration
function add(a, b) { return a + b; }

// Arrow function (short & binds 'this' differently; see §9)
const mul = (a, b) => a * b;

// Default params
function greet(name = "friend") {
  return `Hi ${name}`;
}
```

---

## 5) Control flow
```js
if (x > 10) {
  // ...
} else if (x === 10) {
  // ...
} else {
  // ...
}

for (let i = 0; i < 3; i++) { /* 0,1,2 */ }

for (const n of [1,2,3]) { /* values */ }   // arrays
for (const k in {a:1,b:2}) { /* keys */ }   // objects

// Ternary (quick if/else)
const label = x > 0 ? "positive" : "non-positive";
```

---

## 6) Array helpers (functional style you’ll use daily)
```js
const nums = [1, 2, 3, 4];

nums.map(n => n * 2);           // [2,4,6,8]   (transform)
nums.filter(n => n % 2 === 0);  // [2,4]       (keep some)
nums.find(n => n > 2);          // 3           (first match)
nums.some(n => n > 3);          // true        (any?)
nums.every(n => n > 0);         // true        (all?)
nums.reduce((acc, n) => acc + n, 0); // 10     (fold into one value)
```

---

## 7) Truthy/falsey & equality
```js
// Falsey: false, 0, -0, 0n, "", null, undefined, NaN
if ("") console.log("won't run");
if ("hello") console.log("will run");

// Use === (strict equality) instead of == (loose) to avoid weird coercion.
0 == ""    // true (weird)
0 === ""   // false (correct)
```

**Nullish coalescing** & **optional chaining**:
```js
const val = user.nickname ?? "Anon";   // use default only if null/undefined
const city = user.address?.city;       // safely read nested property or get undefined
```

---

## 8) Scope & hoisting (often-confusing bits)
- `let`/`const` are **block-scoped**; `var` is function-scoped (avoid it).
- Function declarations are hoisted; `const f = () => {}` is not callable before its line.

```js
sayHi();           // ok (function hoisted)
function sayHi(){ console.log("hi"); }

// notHoisted();   // ❌ ReferenceError
const notHoisted = () => console.log("nope");
```

---

## 9) `this` & arrow functions
- Arrow functions **do not** have their own `this`; they use the surrounding `this`.
- Regular functions get `this` from **how** they’re called.

```js
const obj = {
  val: 42,
  reg() { console.log(this.val); },     // 42 (called as obj.reg())
  arr: () => console.log(this.val),     // likely undefined (arrow uses outer this)
};
```

In modern React/Next.js, prefer **arrow functions** for callbacks; for object methods that rely on `this`, use method syntax (`reg() {}`) or avoid `this` entirely.

---

## 10) Modules (import/export)
**moduleA.js**
```js
export const PI = 3.14;
export default function area(r) { return PI * r * r; }
```
**moduleB.js**
```js
import area, { PI } from "./moduleA.js";
```

- **Default export** → `import anyName from ...`
- **Named export** → `import { ExactName } from ...`

In Next.js/TS use ESM (no `.js` extension in TS imports).

---

## 11) Async: Promises & `async/await`
```js
// Promise style
fetch("/api/ping")
  .then(res => res.json())
  .then(data => console.log(data))
  .catch(err => console.error(err));

// async/await style (cleaner)
async function load() {
  try {
    const res = await fetch("/api/ping");
    const data = await res.json();
    console.log(data);
  } catch (err) {
    console.error(err);
  }
}
```

Run tasks in parallel:
```js
const [u, posts] = await Promise.all([getUser(), getPosts()]);
```

**Event loop tip:** `await` breaks tasks into microtasks; long loops block the UI—batch or chunk work if needed.

---

## 12) Errors
```js
try {
  risky();
} catch (err) {
  console.error(err.message);
} finally {
  // always runs (cleanup)
}
```

Create custom errors:
```js
class AppError extends Error {
  constructor(msg) { super(msg); this.name = "AppError"; }
}
```

---

## 13) DOM basics (browser)
```js
const btn = document.querySelector("#save");
btn.addEventListener("click", () => alert("saved!"));
document.getElementById("title").textContent = "Hello";
```

In **React**, you rarely touch the DOM directly; use component state/props.

---

## 14) Handy patterns for web apps
```js
// Guard: only run if value exists
if (!value) return;

// Early return to reduce nesting
if (!isLoggedIn) return redirectToLogin();

// Safe JSON parse
const safe = (s) => { try { return JSON.parse(s); } catch { return null; } };

// Debounce: wait for user to finish typing
function debounce(fn, ms=300){
  let t; return (...args)=>{ clearTimeout(t); t=setTimeout(()=>fn(...args), ms); };
}
```

---

## 15) Common gotchas (read this twice)
- Use `===`, not `==`.
- `NaN` is **not** equal to itself (`NaN !== NaN`); check with `Number.isNaN(x)`.
- `parseInt("08")` → pass a radix: `parseInt("08", 10)`.
- Floating point imprecision: `0.1 + 0.2 !== 0.3`; compare within a tolerance.
- Don’t mutate arrays/objects you don’t own—use copies (`...spread`).

---

## 16) Small JS → TS mapping (since Next.js uses TS)
```ts
// Basic typing
function add(a: number, b: number): number { return a + b; }

type User = { id: string; name?: string };  // ? = optional
function greet(u: User) { return `Hi ${u.name ?? "Anon"}`; }

// Union & narrowing
function toStr(x: number | string) {
  return typeof x === "number" ? String(x) : x;
}
```

---

## 17) Mini exercises (10–15 min total)
1) Write `double(nums)` that returns a **new** array with all values doubled (don’t mutate).
2) Write `pick(obj, keys)` that returns a **new object** with only those keys.
3) Use `fetch` to GET `/api/ping`, then log `data.pong`.
4) Rewrite a `.then(...).catch(...)` flow using `async/await` + `try/catch`.
5) Given `const a = { nested: { x: 1 } }`, make a **deep copy** and change `x` to 2 without touching `a`.

---

## 18) Tiny cookbook

**Deep clone (simple objects only):**
```js
const clone = JSON.parse(JSON.stringify(obj)); // beware: loses Dates/Funcs/BigInt
```

**Random ID:**
```js
const id = Math.random().toString(36).slice(2);
```

**Group by key:**
```js
const groupBy = (arr, key) =>
  arr.reduce((acc, item) => {
    const k = item[key];
    (acc[k] ||= []).push(item);
    return acc;
  }, {});
```

**Format money (USD):**
```js
const fmt = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });
fmt.format(1234.5); // "$1,234.50"
```

**Date → YYYY-MM-DD:**
```js
const d = new Date();
const iso = d.toISOString().slice(0, 10);
```

---

## 19) Learning path (keep it simple)
1) Variables/types, arrays/objects, destructuring/spread.
2) Functions, map/filter/reduce.
3) Truthy/falsey, equality, scope, hoisting.
4) Async/await + fetch; error handling.
5) Modules; Node vs browser basics.
6) Optional: small TS types for your Next.js app.

You’ll use these every day in Next.js. Practice by changing one of your Vision Boards components to use **map/filter**, then add a tiny **fetch** call to a `/api/ping` Route Handler and log the result.

— End —
