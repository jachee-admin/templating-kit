#JavaScript Language Guide (Concise)

## Declarations

```js
const x = 1;   // default
let y = 2;     // reassignable
// var = function-scoped (avoid)
```

## Equality & Defaults

```js
a === b                          // strict equality (always prefer)
const name = user?.name ?? "Anon";  // optional chaining + nullish coalescing
```

## Arrays

```js
arr.map(f)        // transform -> new array
arr.filter(f)     // keep some -> new array
arr.reduce(fn, i) // fold into one value
arr.find(f)       // first match | undefined
arr.includes(v)   // membership
arr.flat(1)       // flatten 1 level
arr.flatMap(f)    // map + flatten
[...arr].sort(cmp)// non-mutating sort
```

---

## Objects

```js
// Destructure + rest
const { id, ...rest } = obj;

// Spread copy + override
const merged = { ...obj, active: true };

// Key/value utilities
Object.keys(o);    // → ["k1", "k2"]
Object.values(o);  // → [v1, v2]
Object.entries(o); // → [["k1", v1], ["k2", v2]]
Object.fromEntries([["x",1],["y",2]]); // → {x:1, y:2}
```

### Pro Trick: Transform objects via entries

```js
// Remove keys
const safe = Object.fromEntries(
  Object.entries(user).filter(([k]) => k !== "password")
);

// Change values
const taxed = Object.fromEntries(
  Object.entries(prices).map(([k,v]) => [k, v * 1.1])
);

// Rename keys
const renamed = Object.fromEntries(
  Object.entries(obj).map(([k,v]) =>
    k === "fname" ? ["firstName", v] :
    k === "lname" ? ["lastName", v] :
    [k, v]
  )
);
```

### Shallow Copy (spread, fine for flat data)

```js
const arrCopy = [...arr];          // copy array
const objCopy = { ...obj };        // copy object
```

⚠️ Nested objects/arrays are **still shared** (same references).

---

### Deep Copy (full clone)

```js
// Modern (safe)
const deep = structuredClone(obj);

// Old hack (loses funcs, Dates, undefined, Symbol)
const deep = JSON.parse(JSON.stringify(obj));

// Library (robust)
import cloneDeep from "lodash/cloneDeep.js";
const deep = cloneDeep(obj);
```

---

### Why it matters

```js
const original = { id: 1, profile: { name: "John" } };
const shallow = { ...original };

shallow.profile.name = "Jane";
console.log(original.profile.name); // "Jane" (changed!)
```

- **Spread = shallow**: cheap, fine for flat stuff.

- **structuredClone / cloneDeep = deep**: needed when nested data must not leak changes.

## Functions

```js
function f(a=0, ...rest) { return rest.length; }  // defaults + rest
const g = (x) => x * 2;                           // arrow
// Arrow has lexical this; avoid for methods using 'this'
```

## Async / Promises

```js
const r = await fetch("/api");
if (!r.ok) throw new Error(`HTTP ${r.status}`);
const data = await r.json();

const [a, b] = await Promise.all([p1, p2]); // parallel
```

## Errors

```js
try { risky(); }
catch (e) { console.error(e); }
```

## Modules (ESM)

```js
// math.js
export const PI = 3.14;
export default function area(r){ return PI*r*r; }

// use
import area, { PI } from "./math.js";
```

## Operators

```js
value ?? fallback      // null/undefined only
a ||= 1;               // if (!a) a = 1;
b &&= 2;               // if (b) b = 2;
c ??= 3;               // if (c == null) c = 3;
const v = obj?.deep?.prop; // optional chaining
```

## Dates, Intl, URL

```js
new Date().toISOString();
new Intl.NumberFormat("en-US",{style:"currency",currency:"USD"}).format(1234.5);
new URL("/p?x=1","https://site.com").searchParams.get("x"); // "1"
```

## ⚠️ Arrow Function Gotchas

```js
// 1. No own `this`
const obj = {
  val: 10,
  regular() { console.log(this.val); }, 
  arrow: () => console.log(this.val)
};

obj.regular(); // 10  ✅ this = obj
obj.arrow();   // undefined ❌ arrow reuses outer `this`

// 2. No own `arguments`
function normal(a,b) {
  const arrow = () => console.log(arguments);
  arrow(1,2,3);
}
normal("x","y");
// → ["x","y"] (from parent) ❌ not [1,2,3]

// Use rest to capture args
const arrowArgs = (...args) => console.log(args);
arrowArgs(1,2,3); // [1,2,3] ✅
```

**Rule**:

- Arrow = no `this`, no `arguments` (they’re inherited from outer scope).

- Great for short callbacks; avoid for object methods or when you need real `arguments`.

## Copy vs Mutate

```js
const sorted = [...arr].sort((a,b)=>a-b);  // copy before sort
const updated = { ...obj, name: "New" };   // copy before change
```

## Falsy Values (7)

`false, 0, -0, 0n, "", null, undefined, NaN`

## Gotchas

- `typeof null === "object"` (quirk)

- `NaN !== NaN` → use `Number.isNaN(x)`

- Always pass radix: `parseInt("08", 10)`

- JSON → no funcs/undefined/Symbols; Dates → strings

- Arrow fns have no `this`/`arguments`

## Event Loop Order

```js
console.log("A");
setTimeout(()=>console.log("B"));             // macrotask
Promise.resolve().then(()=>console.log("C")); // microtask
console.log("D");
// A D C B
```
