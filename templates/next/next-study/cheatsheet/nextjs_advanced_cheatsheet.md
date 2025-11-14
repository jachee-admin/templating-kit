# Next.js App Router — Advanced Cheat Sheet (Graduate Edition)

Use this when you’re comfy with the basics. It focuses on **data caching**, **streaming**, **server actions at scale**, **parallel routes**, **Edge vs Node**, **middleware**, and **production hygiene**.

---

## 1) Rendering & Data Caching — the real knobs

### Route Segment Config (static vs dynamic)
At the file (page/layout) level:
```ts
// Always dynamic (no cache)
export const dynamic = "force-dynamic";

// Static but revalidate every N seconds (ISR)
export const revalidate = 60;

// Prefer Edge runtime where possible
export const runtime = "edge";        // or "nodejs"
```

### Fetch cache & tags
```ts
// Static (default): cached in prod, deduped per request
await fetch(url);

// Force no cache for this request
await fetch(url, { cache: "no-store" });

// Tag-based caching: revalidate by tag later
await fetch(url, { next: { tags: ["boards", `board:${id}`] } });
```

### Revalidation APIs
```ts
import { revalidatePath, revalidateTag } from "next/cache";

revalidatePath("/boards");        // refresh a route segment
revalidateTag("boards");          // refresh all fetch() calls tagged "boards"
```

### Opt-out inside server code
```ts
import { noStore } from "next/cache";
export async function getFreshStuff() {
  noStore();                       // disable all caching in this scope
  // ...do non-cached work
}
```

### Request memoization & dedupe
- Identical `fetch` (same URL/options) in one request is **deduped**.
- Use `Promise.all(...)` to run independent fetches concurrently.
- Wrap heavy pure functions with `cache(fn)` if you want memoization by args.

```ts
import { cache } from "react";
export const getUser = cache(async (id: string) => {
  // …DB/API call here
});
```

---

## 2) Streaming UI with Suspense

Server Components can stream HTML **in chunks**. Use `<Suspense>` to split slow parts.

```tsx
// app/boards/[id]/page.tsx
import { Suspense } from "react";
import BoardShell from "./BoardShell";         // fast
import ActivityStream from "./ActivityStream"; // slow

export default function Page({ params }: { params: { id: string } }) {
  return (
    <div>
      <BoardShell id={params.id} />
      <Suspense fallback={<div>Recent activity…</div>}>
        {/* This subtree renders later, streams in */}
        <ActivityStream id={params.id} />
      </Suspense>
    </div>
  );
}
```

`loading.tsx` is the **route-level** fallback; `<Suspense>` gives **in-page** control.

Shortcuts:
- Throw `notFound()` to trigger the nearest `not-found.tsx`.
- Use `redirect("/login")` for auth gating in server code.

---

## 3) Server Actions — production patterns

### (a) Validation + return state
```ts
// app/boards/[id]/actions.ts
"use server";
import { z } from "zod";
import { revalidatePath } from "next/cache";

const Schema = z.object({ title: z.string().min(1).max(120) });

export async function renameBoard(id: string, prevState: any, fd: FormData) {
  const parsed = Schema.safeParse({ title: fd.get("title") });
  if (!parsed.success) return { ok: false, errors: parsed.error.flatten() };

  // await db.boards.update({ id, title: parsed.data.title });
  revalidatePath(`/boards/${id}`);
  return { ok: true };
}
```

```tsx
// app/boards/[id]/page.tsx
import { useFormState, useFormStatus } from "react-dom";
import { renameBoard } from "./actions";

function SubmitBtn() {
  const { pending } = useFormStatus();
  return <button disabled={pending}>{pending ? "Saving…" : "Save"}</button>;
}

export default function Page({ params }: { params: { id: string } }) {
  const [state, action] = useFormState(
    (prev, fd) => renameBoard(params.id, prev, fd),
    { ok: false }
  );
  return (
    <form action={action}>
      <input name="title" />
      <SubmitBtn />
      {!state.ok && state.errors && <pre>{JSON.stringify(state.errors, null, 2)}</pre>}
    </form>
  );
}
```

### (b) Auth context inside actions
Use server helpers rather than passing tokens from the client.
```ts
import { cookies, headers } from "next/headers";
export async function action(fd: FormData) {
  const cookieStore = cookies();            // read auth cookies
  const hdrs = headers();                   // read request headers
  // derive user session here
}
```

### (c) After-mutation refresh
Prefer **tags** for broader invalidation (dashboards, feeds). Keep `revalidatePath` for surgical updates.

---

## 4) Route Handlers — advanced

### Edge vs Node
```ts
export const runtime = "edge";              // web-standard APIs only
export const preferredRegion = "iad1";      // deployment hint (Vercel)
```

### Streaming responses
```ts
// app/api/stream/route.ts
export async function GET() {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode("hello "));
      setTimeout(() => {
        controller.enqueue(new TextEncoder().encode("world"));
        controller.close();
      }, 500);
    },
  });
  return new Response(stream, { headers: { "content-type": "text/plain" } });
}
```

### File uploads (multipart)
```ts
export async function POST(req: Request) {
  const form = await req.formData();
  const file = form.get("file") as File;
  // const buf = await file.arrayBuffer(); // then store to S3/etc
  return new Response(null, { status: 204 });
}
```

### Cookies & headers
```ts
import { NextResponse } from "next/server";
export async function GET() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set("seen", "1", { httpOnly: true, path: "/" });
  res.headers.set("x-demo", "yes");
  return res;
}
```

---

## 5) Parallel & Intercepting Routes (pro-level routing)

### Parallel routes (named slots)
```
app/(app)/layout.tsx
app/(app)/@feed/page.tsx
app/(app)/@sidebar/page.tsx
```
Layout renders `{children}`, `{feed}`, `{sidebar}`. Each slot loads independently.

```tsx
// app/(app)/layout.tsx
export default function Layout({ children, feed, sidebar }: any) {
  return (
    <div className="grid">
      <aside>{sidebar}</aside>
      <main>{children}</main>
      <section>{feed}</section>
    </div>
  );
}
```

Use `default.tsx` in a slot folder to provide a fallback UI.

### Intercepting routes (overlay modals)
Open content “over” the current page without full navigation.
```
app/photos/page.tsx
app/(.)photos/[id]/page.tsx   // intercepts into current view as a modal
```
Conventions:
- `(.)` intercept from the same level
- `(..)` from one level up
- `(...)` from the root

---

## 6) Middleware — targeted, fast guards

File at project root: `middleware.ts`
```ts
import { NextResponse } from "next/server";

export function middleware(req: Request) {
  // Example: block bots or force auth on /dashboard/*
  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/api/:path*"],
};
```

Tips:
- Keep it **small** (Edge runs on every request it matches).
- Use it for redirects, locale, AB-testing, headers—**not** for DB-heavy logic.

---

## 7) Performance & Bundles

### Keep JS small
- Default to **Server Components**. Promote to client only what needs interactivity.
- Split heavy client-only libs with `next/dynamic`:
```tsx
const HeavyChart = dynamic(() => import("./HeavyChart"), { ssr: false });
```
- Avoid importing server-only code into client files.

### Analyze bundles
- Use a bundle analyzer plugin or Vercel’s Analyze tab to spot big chunks.
- Watch for accidental `import "* as sdk"` in client files.

### Images & fonts
- `next/image` with `remotePatterns` for external hosts.
- `next/font` self-hosts Google fonts; no layout shift, fewer requests.

---

## 8) Observability & Errors

### instrumentation.ts (OpenTelemetry hooks)
```
app/instrumentation.ts
```
Export `register()` to initialize tracing/logging before the app runs.

### Error boundaries
- `error.tsx` at segment scope; use `reset()` for retry.
- Use an error-logging service in `error.tsx` or inside server code to capture context.

### Web Vitals
Implement `export function reportWebVitals(metric) { ... }` in `app` root if needed.

---

## 9) Auth + RLS (Supabase-friendly shape)

- **Never** expose service-role keys to the client.
- Server: create a server-side Supabase client per request using cookies/headers.
- Use **RLS** to enforce “user can access only their own rows”.
- In server actions/route handlers, read `cookies()` to derive the session, and pass the user id to queries.
- Invalidate with **tags** (`boards`, `board:{id}`) after mutations.

**RLS policy pattern (owner-only):**
```sql
create policy "owner-read" on public.dashboards
for select using (user_id = auth.uid());
create policy "owner-write" on public.dashboards
for all using (user_id = auth.uid()) with check (user_id = auth.uid());
```

---

## 10) SEO & Metadata

### Per-page metadata
```ts
export async function generateMetadata({ params }) {
  const board = await getBoard(params.id);
  return {
    title: `${board.title} — Vision Boards`,
    description: board.summary,
    openGraph: { images: [board.cover_url] },
  };
}
```
Place in `page.tsx` or `layout.tsx` route segment. Set a global `metadataBase` in root layout for absolute URLs.

---

## 11) PWA at scale

- Cache **public/static** assets with a “stale-while-revalidate” strategy.
- **Do not cache** authenticated HTML/API responses in a shared cache.
- Version your SW and clean old caches to avoid bloat.
- Test installability + offline paths with Lighthouse & real devices.

---

## 12) Deployment notes

- Edge runtime is great for auth checks, light APIs, and low latency.
- Node runtime for heavy libs (DB drivers, image processing).
- Prefer **ISR + tags** over full-path revalidation for feeds and lists.
- Make 404s/redirects explicit to help prerendering.

---

## Copy‑Paste Cookbook

**1) Tag a fetch + revalidate it later**
```ts
// read
await fetch(url, { next: { tags: ["boards"] } });

// write
import { revalidateTag } from "next/cache";
revalidateTag("boards");
```

**2) Not found / redirect**
```ts
import { notFound, redirect } from "next/navigation";
if (!board) notFound();
if (!session) redirect("/login");
```

**3) Client island with dynamic import**
```tsx
"use client";
import dynamic from "next/dynamic";
const KonvaEditor = dynamic(() => import("./KonvaEditor"), { ssr: false });
export default function EditorIsland(props: any) { return <KonvaEditor {...props} />; }
```

**4) Middleware auth gate**
```ts
export const config = { matcher: ["/dashboard/:path*"] };
export function middleware(req: any) {
  // If no auth cookie -> redirect
  return NextResponse.next();
}
```

**5) Stream from a Route Handler (text/event-stream pattern)**
```ts
export async function GET() {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    start(c) {
      c.enqueue(encoder.encode("data: hello\n\n"));
      c.close();
    },
  });
  return new Response(stream, {
    headers: { "content-type": "text/event-stream", "cache-control": "no-store" },
  });
}
```

**6) Form progressive enhancement**
```tsx
"use client";
import { useFormStatus } from "react-dom";
function Submit() { const { pending } = useFormStatus(); return <button disabled={pending}>{pending ? "Saving…" : "Save"}</button>; }
```

**7) Memoize heavy pure function**
```ts
import { cache } from "react";
export const expensive = cache(async (a: number, b: number) => a + b);
```

---

## Final mental model

- **Server-first.** Fetch/compute on the server; ship tiny client islands.
- **Control freshness** with `revalidate`, `dynamic`, `noStore`, and **tags**.
- **Stream** slow parts with Suspense to keep the app snappy.
- **Actions** = forms to server; validate, mutate, then revalidate.
- **Edge for fast glue**, Node for heavy libs.
- **RLS + middleware** for safety; never trust the client.
- **Measure bundles**, keep the client lean, and log errors with context.

— End —
