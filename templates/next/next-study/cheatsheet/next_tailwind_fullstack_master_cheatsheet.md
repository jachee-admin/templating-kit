# Full‑Stack Next.js + Tailwind Cheat Sheet (Master Edition)

Role POV: Principal web engineer shipping production apps. This sheet prioritizes **what you’ll use daily** as a full‑stack Next.js + Tailwind developer (App Router era).

---

## 0) 90% Use‑Cases: Quick Reference

```ts
// ROUTE FOLDER
// app/boards/[id]/page.tsx
export const dynamic = "force-dynamic";             // always fresh (editor views)
export const revalidate = 60;                       // ISR (lists/dashboards)

// DATA FETCH (server) with tags
await fetch(url, { next: { tags: ["boards", `board:${id}`] } });

// AFTER MUTATION (server action / API)
import { revalidatePath, revalidateTag } from "next/cache";
revalidatePath(`/boards/${id}`);                    // surgical
revalidateTag("boards");                            // broad

// SERVER ACTION (no custom API needed)
"use server";
export async function save(fd: FormData) { /* mutate DB */ }

// PAGE USING ACTION (server component)
import { save } from "./actions";
export default function Page() {
  return <form action={save}>{/* inputs */}<button>Save</button></form>;
}

// CLIENT ISLAND (interactivity)
"use client";
import { useState } from "react";
export default function Widget({ data }: { data: any }) {
  const [n, setN] = useState(0);
  return <button onClick={() => setN(n + 1)}>{n}</button>;
}

// ROUTE HANDLER (API)
/* app/api/boards/route.ts */
import { NextResponse } from "next/server";
export async function GET() { return NextResponse.json({ ok: true }); }
export async function POST(req: Request) { const body = await req.json(); return NextResponse.json(body, { status: 201 }); }

// MIDDLEWARE (project root)
/* middleware.ts */
import { NextResponse } from "next/server";
export const config = { matcher: ["/dashboard/:path*"] };
export function middleware() { return NextResponse.next(); }
```

---

## 1) App Router Routing (app/)

- `layout.tsx` — persistent wrapper (providers, nav) for a segment.
- `page.tsx` — actual page at that path.
- `loading.tsx` — instant skeleton during server streaming.
- `error.tsx` (client) — error boundary with `{ error, reset }`.
- `route.ts` — HTTP handlers at that path (`GET/POST/...`).
- `template.tsx` — like layout but re‑runs per navigation.
- Dynamic segments: `[id]/page.tsx` → `/route/123`.
- Prebuild routes:  
  ```ts
  export async function generateStaticParams() { return ids.map(id => ({ id })); }
  ```
- Not found / redirect:  
  ```ts
  import { notFound, redirect } from "next/navigation";
  ```

**Metadata** (SEO):
```ts
export async function generateMetadata() {
  return { title: "Title", description: "Desc", openGraph: { images: ["/og.png"] } };
}
```

---

## 2) Server vs Client Components

- **Server (default):** fetch data, touch secrets, zero client JS. Stream HTML.
- **Client:** add **`"use client"`** at file top for hooks, events, browser APIs.

**Pattern:** server page fetches → passes **plain props** to tiny, focused client “islands”.

---

## 3) Data Fetching, Caching & Freshness

- Route‑level:
  ```ts
  export const dynamic = "force-dynamic";  // no cache
  export const revalidate = 60;            // ISR
  export const runtime = "edge" | "nodejs";
  ```
- Fetch‑level:
  ```ts
  await fetch(url, { cache: "no-store" });             // bypass cache
  await fetch(url, { next: { tags: ["tag1"] } });      // tag for later invalidation
  ```
- Invalidate:
  ```ts
  revalidatePath("/route");   // precise
  revalidateTag("tag1");      // broad
  ```
- Disable caching in a helper:
  ```ts
  import { noStore } from "next/cache"; noStore();
  ```
- Request dedupe/memoize:
  ```ts
  import { cache } from "react"; export const getUser = cache(async (id) => {...});
  ```

---

## 4) Server Actions (forms → server)

- Mark function file with `"use server"`.
- Call via `<form action={action}>` (no client JS required).
- Use `useFormStatus()` for pending state; `useFormState()` for returning errors.
- Validate with **Zod**; revalidate affected routes/tags after mutation.

```ts
// actions.ts
"use server";
import { z } from "zod"; import { revalidatePath } from "next/cache";
const Schema = z.object({ title: z.string().min(1).max(120) });
export async function rename(prev: any, fd: FormData) {
  const p = Schema.safeParse({ title: fd.get("title") });
  if (!p.success) return { ok:false, errors:p.error.flatten() };
  // await db.update(...)
  revalidatePath("/boards");
  return { ok:true };
}
```

---

## 5) Route Handlers (APIs)

- File: `app/api/.../route.ts`.
- Use Web platform types (`Request`, `Response`). For cookies/headers, prefer Next helpers:
  ```ts
  import { cookies, headers } from "next/headers";
  const session = cookies().get("sb:token");
  ```
- Streaming responses (SSE / streams) and multipart uploads supported.
- Choose runtime per route: `export const runtime = "edge"` for low‑latency; Node for DB drivers/heavy libs.

---

## 6) Auth (Supabase/NextAuth patterns)

- **Never** expose service keys on the client.
- Server: build a request‑scoped client using cookies/headers to read the session.
- With Supabase + RLS, policy‑gate data by `auth.uid()`; keep profile table keyed to `auth.users(id)`.
- Client reads minimal session state; fetch sensitive data on the server.

**RLS policy shape (owner‑only):**
```sql
create policy "owner_read" on public.dashboards for select using (user_id = auth.uid());
create policy "owner_write" on public.dashboards for all using (user_id = auth.uid()) with check (user_id = auth.uid());
```

---

## 7) Forms & Validation

- Simple forms → **Server Actions**.
- Rich forms → **react-hook-form** + **@hookform/resolvers/zod** + Zod schema.
- Return structured errors and render near inputs.
- Prevent double‑submits with `useFormStatus().pending`.

```ts
import { z } from "zod";
export const BoardSchema = z.object({ title: z.string().min(1), color: z.string().optional() });
```

---

## 8) TailwindCSS Essentials

- Mobile‑first; responsive prefixes: `sm: md: lg: xl:`
- State variants: `hover:` `focus:` `active:` `disabled:` `aria-checked:`
- Dark mode: `dark:` (set class on `<html class="dark">` or media).
- Layout: `flex`, `grid`, `gap-*`, `place-*`, `w-*, h-*`, `min-h-screen`.
- Spacing/typography: `p-* m-* text-* leading-* tracking-*`.
- Utilities you’ll use daily: `rounded-* border shadow-* ring-*`.
- Compose classes with **clsx** and **tailwind-merge** to avoid conflicts.

```ts
// utils/cn.ts
import { clsx } from "clsx"; import { twMerge } from "tailwind-merge";
export const cn = (...args: any[]) => twMerge(clsx(args));
```

**Common patterns:**
```tsx
<button className="inline-flex items-center gap-2 rounded-md bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500">
  Save
</button>
```

- Plugins worth enabling: `@tailwindcss/forms` `@tailwindcss/typography` `@tailwindcss/aspect-ratio` `@tailwindcss/line-clamp`.

---

## 9) Performance & Bundles

- Prefer Server Components; keep client “islands” small.
- Code‑split heavy client libs:  
  ```tsx
  import dynamic from "next/dynamic";
  const Konva = dynamic(() => import("./KonvaEditor"), { ssr: false });
  ```
- Use `next/image` with proper `sizes`. Use `next/font` to self‑host fonts.
- Avoid unnecessary `useEffect`; derive state from props when possible.
- Memoize only when profiling shows benefit (`useMemo`, `useCallback`).

---

## 10) Accessibility (a11y) & UX

- Semantic HTML first (`<button>`, `<nav>`, `<main>`, `<label for>`).
- Visible focus styles (`focus:outline-none focus:ring-2 ...`).
- Sufficient color contrast; don’t remove hover/focus affordances.
- Keyboard navigation and ARIA only when necessary.
- Provide loading skeletons (`loading.tsx`) and retry affordances (`error.tsx -> reset()`).

---

## 11) Images, Fonts & Metadata

- `next/image` for optimization; allow remote hosts via `next.config` if needed.
- `next/font` for Google/local fonts (no layout shift):
  ```ts
  import { Inter } from "next/font/google"; const inter = Inter({ subsets:["latin"] });
  <body className={inter.className}>...</body>
  ```
- Open Graph/Twitter cards via `generateMetadata`.
- Add `sitemap.xml` and `robots.txt` (static or generated routes).

---

## 12) Middleware & Edge

- `middleware.ts` at project root (or `src/`), use sparingly (fast checks, redirects, headers).
- Scope with `export const config = { matcher: [...] }`.
- Edge runtime for auth gates, AB tests, lightweight rewrites.

---

## 13) PWA Basics

- `public/manifest.json` + icons.
- Register a Service Worker thoughtfully; avoid caching authenticated HTML/API responses in shared caches.
- Use Lighthouse to verify “Installable” and perf.

---

## 14) Testing & Tooling

- **ESLint** (`next/core-web-vitals`) + **Prettier** + `prettier-plugin-tailwindcss`.
- **Vitest/Jest** for units; **Testing Library** for React; **Playwright** for e2e.
- Husky + lint‑staged pre‑commit.
- Env vars:
  - Client‑readable → `NEXT_PUBLIC_*`
  - Secrets → server only (`process.env.MY_KEY`)
  - Local dev → `.env.local`

---

## 15) Error Handling & Observability

- Catch and normalize server errors; surface friendly messages.
- Log context in Route Handlers / Actions (request id, user id).
- Consider Sentry or similar for prod error tracking.

---

## 16) Useful Snippets

**Debounce**
```ts
export function debounce<T extends (...a: any[]) => void>(fn: T, ms = 300) {
  let t: any; return (...args: Parameters<T>) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}
```

**Fetch wrapper (server)**
```ts
export async function j(url: string, init?: RequestInit) {
  const res = await fetch(url, init);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}
```

**Guarded classNames**
```ts
<button className={cn("btn", isActive && "bg-blue-600", disabled && "opacity-50")} />
```

**Safe JSON parse**
```ts
export const safeJson = <T>(s: string): T | null => { try { return JSON.parse(s) as T; } catch { return null; } };
```

---

## 17) Recommended Libraries (pragmatic)

- **Validation:** `zod`
- **Forms:** `react-hook-form` + `@hookform/resolvers/zod`
- **Class merging:** `clsx` + `tailwind-merge`
- **State (when needed):** `zustand` (simple), `jotai` (atomic)
- **HTTP (optional client):** `swr` or `@tanstack/react-query` (if you lean client‑data heavy)

---

## 18) Mental Model Recap

1. **Server‑first**: fetch/compute on the server; ship **tiny** client islands.
2. **Control freshness** with route config + fetch tags; revalidate after writes.
3. **Actions over custom APIs** for CRUD forms; validate; revalidate.
4. **Tailwind** for speed; compose with `cn()` helper; keep focus styles.
5. **Measure** (bundle, perf) and **observe** (errors) early.

— End —
