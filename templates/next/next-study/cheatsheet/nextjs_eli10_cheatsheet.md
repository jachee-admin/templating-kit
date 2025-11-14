# Next.js App Router — ELI10 Cheat Sheet (for Vision Boards)

This is a **plain-English** guide. Copy–paste the snippets and put the files where shown. If you can create folders and files, you can build pages. 🙂

---

## 0) Project quick start
```bash
# In an empty repo folder
pnpm create next-app@latest . --ts --eslint --app --import-alias "@/*"
pnpm dev   # visit http://localhost:3000
```

> Already have a project? Great—skip the scaffold step.

---

## 1) How routing works (the map)
Inside the **`app/`** folder, each folder becomes a URL. These special files matter:

- `layout.tsx` — the **wrapper** (nav/sidebar) for a section
- `page.tsx` — the **actual page** people see at that URL
- `loading.tsx` — shows while data is loading (a “skeleton”)
- `error.tsx` — friendly error screen with a **Try again** button
- `route.ts` — an **API** at that path (handles GET/POST/etc)

**Example tree → URLs**
```
app/
  page.tsx                  → "/"
  dashboard/
    page.tsx                → "/dashboard"
  boards/
    [id]/
      page.tsx              → "/boards/123"  (123 is the id)
```

---

## 2) Server vs Client (who runs the code?)
- **Server Component** (default): runs on the server. Good for reading from databases/APIs. No browser-only stuff here.
- **Client Component**: add **`"use client"`** at the **very first line** of the file to use React hooks (`useState`) and browser APIs (`window`, canvas/Konva).

**Simple rule:** Fetch data on the **server**, pass it as props to a **small client component** that handles clicks and UI.

---

## 3) Build your first page
Create `app/hello/page.tsx`:

```tsx
export default function Page() {
  return <h1>Hello Next.js 👋</h1>;
}
```

Visit `http://localhost:3000/hello`

---

## 4) Add a layout (a wrapper that stays on screen)
Create `app/layout.tsx` (this wraps ALL pages unless you add deeper layouts too):

```tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header>My App</header>
        <main>{children}</main>
      </body>
    </html>
  );
}
```

---

## 5) Make a client component (“island”)
Create `app/hello/Counter.tsx`:

```tsx
"use client"; // must be the very first line

import { useState } from "react";

export default function Counter() {
  const [n, setN] = useState(0);
  return (
    <div>
      <p>Count: {n}</p>
      <button onClick={() => setN(n + 1)}>+1</button>
    </div>
  );
}
```

Use it in the page: `app/hello/page.tsx`
```tsx
import Counter from "./Counter";

export default function Page() {
  return (
    <div>
      <h1>Hello Next.js 👋</h1>
      <Counter />
    </div>
  );
}
```

---

## 6) Loading + Error screens (nice UX for free)
Create `app/hello/loading.tsx`:
```tsx
export default function Loading() {
  return <div>Loading…</div>; // simple skeleton
}
```

Create `app/hello/error.tsx`:
```tsx
"use client";
export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div>
      <p>Oops: {error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

---

## 7) A tiny API without Express (Route Handler)
Create `app/api/ping/route.ts`:
```ts
import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({ pong: true });
}
```
Visit `/api/ping` → you’ll see JSON.  
You can also add a `POST(req: Request)` function here.

---

## 8) Server Actions (save data without writing API boilerplate)
Add a server file `app/demo/actions.ts`:
```ts
"use server";
import { revalidatePath } from "next/cache";

export async function saveName(formData: FormData) {
  const name = String(formData.get("name") ?? "");
  // TODO: write to your DB here
  console.log("Saving name:", name);
  revalidatePath("/demo"); // refresh the page’s data
}
```

Use it in `app/demo/page.tsx`:
```tsx
import { saveName } from "./actions";

export default function Page() {
  return (
    <form action={saveName}>
      <input name="name" placeholder="Type your name" />
      <button type="submit">Save</button>
    </form>
  );
}
```

> No `"use client"` needed. Forms can post straight to server actions.

---

## 9) Control caching / freshness
- Always fresh page (no cache):
  ```ts
  export const dynamic = "force-dynamic";
  ```
- Refresh page every 60 seconds:
  ```ts
  export const revalidate = 60;
  ```
- One fetch that should never use cache:
  ```ts
  await fetch(url, { cache: "no-store" });
  ```

Use **fresh** for live editors (like your Konva BoardEditor), and **revalidate** for dashboards/lists that can be slightly old.

---

## 10) Middleware (runs before routes)
File at project root: `middleware.ts` (not inside `app/`):
```ts
import { NextResponse } from "next/server";

export function middleware() {
  // example: force HTTPS or add headers
  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*"], // only run on these paths
};
```

---

## 11) Environment variables
- **Client can read only** `NEXT_PUBLIC_*` variables.
- Secrets (DB keys, API keys) go on the **server** only (`process.env.MY_KEY`).

---

## 12) PWA quick start
- Add `public/manifest.json` and icons.
- Register a service worker that caches **public assets only** (no private data).
- Run Lighthouse (Chrome DevTools → Lighthouse) to check “Installable”.

---

## 13) Common errors (and fast fixes)
- **“Invalid hook call”** → You used a hook in a file without `"use client"`, or nested hooks in a wrong place. Add `"use client"` at the top, or move the hook to a client file.
- **Middleware not running** → You put it in `app/middleware.ts`. It belongs at the **project root** as `middleware.ts` (or `src/middleware.ts`).
- **Env var undefined on client** → Prefix it with `NEXT_PUBLIC_` and restart dev server.
- **404 for a page** → File is not named `page.tsx` or the folder path is wrong.
- **Server action not triggered** → Ensure the function file has `"use server"` and your form uses `action={yourAction}`.

---

## 14) Where this helps in Vision Boards
- The **editor page**: keep it a **Server Page** that fetches the board, then pass the data into a **client Konva component** (your “island”). Add `loading.tsx` for instant feel.
- **Saving**: use a **server action** for simple updates (title, metadata), call `revalidatePath("/boards/[id]")` after saving.
- **Dashboards list**: add `export const revalidate = 60` to keep it zippy without hitting the DB on every request.

---

## Copy–paste snippets (quick reference)

**Fresh page (no cache)**
```ts
export const dynamic = "force-dynamic";
```

**Revalidate every minute**
```ts
export const revalidate = 60;
```

**Client component header**
```tsx
"use client";
```

**Error boundary**
```tsx
"use client";
export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return <button onClick={reset}>Try again</button>;
}
```

**Route Handler (GET)**
```ts
import { NextResponse } from "next/server";
export async function GET() { return NextResponse.json({ ok: true }); }
```

**Server Action**
```ts
"use server";
export async function action(fd: FormData) { /* save */ }
```

You’ve got this. Build one tiny route at a time.
