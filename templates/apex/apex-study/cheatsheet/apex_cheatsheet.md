# Oracle APEX Cheatsheet — All-Around (Builder, SQL, PL/SQL, UI, REST)

> Notion-friendly Markdown. Works across common APEX versions (Universal Theme). Keep it handy while building apps.

---

## APEX mental model (fast)

* **APEX = metadata** in DB + **runtime engine** (via ORDS).
* **App** → **Pages** → each page has **Regions**, **Items** (page items), **Buttons**, **Processes**, **Computations**, **Validations**, **Dynamic Actions**.
* **Shared Components**: Navigation, Auth, LOVs, Templates, Static Files, Build Options, etc.
* **Session State** = per-user state of page items (lives in DB).

---

## Page URL anatomy (deep link anything)

```
f?p=APP_ID:PAGE:SESSION:REQUEST:DEBUG:CLEARCACHE:ITEM_NAMES:ITEM_VALUES:PRINTER_FRIENDLY
```

Common tricks:

* `f?p=&APP_ID.:1:&SESSION.` → go to page 1 in same app & session.
* Clear cache for page(s): `...:RP` (reset pagenumbers) or `...::1` (clear page 1).
* Set items: `...:P1_ID,P1_MODE:42,EDIT`.
* Debug: `...:YES`.
* Safer URL creation: `APEX_PAGE.GET_URL` or `APEX_UTIL.PREPARE_URL`.

---

## Must-know substitution & bind variables

### Substitution strings (in HTML/Attributes/Static text)

| Substitution                  | Meaning                             |
| ----------------------------- | ----------------------------------- |
| `&APP_ID.`                    | Application ID                      |
| `&APP_ALIAS.`                 | Application alias                   |
| `&APP_USER.`                  | Authenticated user                  |
| `&APP_PAGE_ID.`               | Current page number                 |
| `&APP_SESSION.` / `&SESSION.` | Session                             |
| `&DEBUG.`                     | YES/NO                              |
| `&REQUEST.`                   | Current request (often button name) |
| `&APP_FILES.`                 | Virtual path to app static files    |

### Bind variables (in SQL/PLSQL)

| Bind                               | Meaning          |
| ---------------------------------- | ---------------- |
| `:APP_ID`, `:APP_USER`, `:REQUEST` | Globals          |
| `:Pnn_ITEM`                        | Page item value  |
| `:APEX$ROW_STATUS`                 | In IG DML: I/U/D |

---

## Interactive Report / Grid / Faceted Search

* **Interactive Report (IR)**: ad-hoc report, one per page. Saved reports, highlighting, aggregates.

* **Interactive Grid (IG)**: spreadsheet-like editing.
  
  * Needs **Primary Key** or ROWID.
  * Enable **Row Processing** (Automatic Row Processing (DML)) for CRUD.
  * For custom DML, use Process Point **Processing** with `:APEX$ROW_STATUS`.

* **Faceted Search**: declarative filters over LOVs/columns.

---

## Forms & DML (the 80/20)

* **Automatic Row Fetch** (Before Header) + **Automatic Row Processing (DML)** (Processing) with **Primary Key item** (e.g., `P10_ID`) → instant form.
* Create buttons **CREATE/SAVE/DELETE**; set **Request** appropriately and **Server-side Conditions** (e.g., `Request = CREATE`).
* To “redirect back”: set **Branch** after processing: `Page = &P10_RETURN_PAGE.` or use `&APP_PAGE_ID.` logic.

---

## Dynamic Actions (client logic without JS)

* **Event** (e.g., Change on `P10_STATUS`)
* **True Action** (e.g., Show/Hide/Set Value/Execute JS/Refresh Region)
* **When** (selector/item), **Client-side Condition** (Item = value)
* Use **Set Value → SQL Statement** with `Items to Submit` to pull server values.
* To throttle requests, add **Fire on Initialization** (No) and prefer **Debounce** with JS (advanced).

---

## Validations, Computations, Processes

* **Validation**: at **Processing** point; types: Item not null, Regex, SQL/PLSQL Function returning Boolean, etc.
* **Computation**: set item values at points like **Before Header** or **After Submit**.
* **Process**: PL/SQL to run at **Processing**; guard with **Server-side Conditions** (e.g., `Request = SAVE`).

---

## LOVs (Lists of Values)

* Use **Shared LOVs** for reuse; return **stable keys** (IDs), display labels.

* SQL LOV pattern:
  
  ```sql
  select dname as display_value, deptno as return_value
  from dept order by 1
  ```

* **Cascading LOV**: set **Parent Items**, **Items to Submit**, and **Cascading Parent Items** on child.

---

## Authentication & Authorization

* **Auth Schemes**: App Builder contains built-ins (APEX Accounts, OpenID Connect, custom).
* **Authorization Schemes**: PL/SQL function returning Boolean, or SQL expression.
* Apply at **Page/Region/Button/Process** level.
* **Session State Protection (SSP)**: enable **Page Access Protection = Arguments Must Have Checksum** for pages accepting URL items; per-item **Checksum Required** for sensitive items.

---

## Universal Theme (UT) quick wins

* Use **Template Options** (Spacing, Icons, Cards, Badges).
* **Theme Roller** for colors/branding; save as **Style**.
* Regions: **Cards** (list), **Report** (tabular), **Media List**, **Timeline**.
* Icons: `fa-...` classes in icon attributes.
* Add responsive layout with **Grid** (Column span / Breakpoints).

---

## Static & Shared Files

* **Upload** to **Application Static Files** or **Workspace Static Files**.
* Reference with `#APP_FILES#my.js` or `#WORKSPACE_FILES#logo.png`.
* For CSS/JS per page: **Page → CSS/JS** sections (File URLs or Inline).

---

## APEX APIs you’ll use constantly

```plsql
-- Session state
APEX_UTIL.SET_SESSION_STATE('P10_STATUS', 'OPEN');
v := APEX_UTIL.GET_SESSION_STATE('P10_STATUS');

-- URL building
v_url := APEX_UTIL.PREPARE_URL('f?p='||:APP_ID||':10:'||:APP_SESSION||'::NO::P10_ID:42');
v_url := APEX_PAGE.GET_URL(p_page => 10, p_items => 'P10_ID', p_values => '42');

-- Messages & errors
APEX_ERROR.ADD_ERROR(
  p_message => 'Invalid combo', p_display_location => APEX_ERROR.C_INLINE_IN_NOTIFICATION);

-- Debug
APEX_DEBUG.ENABLE;
APEX_DEBUG.MESSAGE('x=%s y=%s', x, y);

-- Collections (session-scoped in-memory tables)
APEX_COLLECTION.CREATE_COLLECTION('BASKET');
APEX_COLLECTION.ADD_MEMBER('BASKET', p_c001 => 'SKU123', p_n001 => 2);

-- JSON
APEX_JSON.INITIALIZE_CLOB_OUTPUT;
APEX_JSON.OPEN_OBJECT; APEX_JSON.WRITE('a', 1); APEX_JSON.CLOSE_OBJECT;
v_clob := APEX_JSON.GET_CLOB_OUTPUT;

-- Web service (REST)
v_resp := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
  p_url => 'https://api.example.com/x', p_http_method => 'GET');

-- Parse uploads (CSV/XLSX/JSON/XML)
FOR r IN (SELECT * FROM TABLE(APEX_DATA_PARSER.PARSE(p_content => :BLOB, p_file_name => :FNAME))) LOOP ... END LOOP;

-- Export data (CSV/XLSX/PDF) 
APEX_DATA_EXPORT.export(
  p_format => APEX_DATA_EXPORT.c_format_xlsx,
  p_query  => 'select * from emp');
```

---

## File uploads (BLOBs) patterns

* Use **File Browse** item → **Storage Type** = **Table APEX\_APPLICATION\_TEMP\_FILES** (default) or custom BLOB column.

* To move from temp to table:
  
  ```plsql
  INSERT INTO docs(id, filename, mime_type, blob_content)
  SELECT :P10_ID, filename, mime_type, blob_content
  FROM APEX_APPLICATION_TEMP_FILES
  WHERE name = :P10_FILE;
  APEX_UTIL.DELETE_FILE(:P10_FILE);
  ```

---

## Security quick checklist

* Pages that accept URL items → **Checksum required**.
* Never string-concat user input into SQL; **bind variables**.
* Use **Authorization Scheme** at page/region/button/process.
* Disable **Unrestricted file types**; use MIME/type checks.
* Hide ≠ Secure: always authorize server-side.
* Enable **Browser cache** appropriately for sensitive pages (No-cache).

---

## Performance & observability

* **Advisor**: App → Utilities → Advisor.
* **Debug**: Toolbar → Debug; or `&DEBUG.=YES` in URL, read **APEX\_DEBUG\_MESSAGES**.
* **Activity views**: `APEX_WORKSPACE_ACTIVITY_LOG`, `APEX_ACTIVITY_LOG`, `APEX_TEAM_DEV_*`.
* Reduce page weight: fewer regions, lazy load via **Dynamic Actions → Refresh**.
* Prefer **single SQL** over PL/SQL loops; IG with too many client features can lag—prune columns, turn off heavy options.

---

## REST & ORDS quick path

* Define **REST Data Source** → use **Web Source Modules** and **APEX\_EXEC** / Declarative report.
* For DB-backed REST: use **ORDS** to expose tables/PLSQL; consume via **Web Source** or `APEX_WEB_SERVICE`.
* **OAuth2**: set **Authentication** on REST Data Source; use credentials in APEX (Workspace → Web Credentials).

---

## Navigation & UI patterns

* **Lists** power menus, breadcrumbs, tabs, cards.
* Use **List Template** (e.g., *Navigation Menu*), then map to **Navigation Menu** in Shared Components.
* **Breadcrumb** region uses **Breadcrumb List** (auto-sync with pages).
* **Cards** region = best all-purpose list UI (icons, badges, media).

---

## Build Options & Feature flags

* Create **Build Option** (e.g., `BETA_FEATURE`) and guard pages/regions/processes with it.
* Query status: `APEX_UTIL.GET_BUILD_OPTION_STATUS('BETA_FEATURE')`.

---

## Common “why isn’t it working?” fixes

* Item value isn’t reaching SQL? Add it to **Items to Submit** or **Page Items to Submit** of the region/DA.
* After DA “Set Value”, **Refresh** dependent region.
* IG not updating? Ensure **Primary Key** item mapped and **Row Processing** enabled (or custom DML uses `:APEX$ROW_STATUS`).
* LOV wrong value displayed? Return/Display columns reversed.
* Buttons not firing? Check **Request** value and server-side condition.
* Deep link breaks? Add checksum (`APEX_UTIL.PREPARE_URL` or Page Access Protection).

---

## Useful views (for quick SQL)

```sql
-- What’s on this page?
select component_type, component_name
from apex_application_page_regions
where application_id = :APP_ID and page_id = :APP_PAGE_ID;

-- Debug messages (current session)
select message, line, component_type
from apex_debug_messages
where session_id = :APP_SESSION
order by message_timestamp desc;

-- Workspace activity
select user_name, application_id, page_id, elapsed_time
from apex_workspace_activity_log
order by view_timestamp desc
fetch first 50 rows only;
```

---

## Mini-recipes

**1) Conditional button (show only for admins):**

* Create **Authorization Scheme** `IS_ADMIN` (PL/SQL returns Boolean).
* Button → **Authorization Scheme** = `IS_ADMIN`.

**2) Show success + redirect back to report:**

* Process → After Submit, then **Branch** to `f?p=&APP_ID.:1:&SESSION.` with **Success Message**.

**3) Download file from BLOB table:**

* Region → **File Download**; or PL/SQL process:
  
  ```plsql
  APEX_UTIL.GET_BLOB_FILE(
    p_file_name   => v_filename,
    p_content_type=> v_mime,
    p_blob_content=> v_blob);
  ```
  
  (or ORDS module with media handler)

**4) CSV/XLSX export from SQL** (no plugin):

```plsql
declare
  l_blob blob;
begin
  l_blob := APEX_DATA_EXPORT.get_file(
              APEX_DATA_EXPORT.export(
                p_format => APEX_DATA_EXPORT.c_format_xlsx,
                p_query  => 'select * from emp'));
  APEX_UTIL.DOWNLOAD_BINARY_FILE(l_blob, 'report.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
end;
/
```

**5) IG custom DML skeleton:**

```plsql
FOR i IN 1..APEX_APPLICATION.G_F01.COUNT LOOP
  CASE :APEX$ROW_STATUS
    WHEN 'C' THEN INSERT ...
    WHEN 'U' THEN UPDATE ...
    WHEN 'D' THEN DELETE ...
  END CASE;
END LOOP;
```

---

## Testing & deployment

* **Export** app as SQL (App → Export/Import). Store in Git.
* Use **Application Substitutions** for environment-specific values (`&API_BASE_URL.`).
* Prefer **Build Options** and **Feature Flags** over hard-coding.
* Smoke test with **APEX Advisor**, **Debug**, and **Saved IR/IG reports**.

---

If you want this turned into **CSV flashcards** (term\:definition) or a **print-ready PDF**, say which and I’ll generate it. Ready for the next language when you are.
