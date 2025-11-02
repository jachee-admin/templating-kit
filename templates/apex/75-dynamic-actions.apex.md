###### APEX

# Dynamic Actions: Item Change → JS/PL/SQL, Show/Hide, Set Value (Patterns & Pitfalls)

Make pages reactive without writing a full SPA. Use DAs to conditionally show/hide, compute on change, fetch server data, and validate—all while keeping UX snappy.

---

## TL;DR

* Prefer **“Change”** on items and **“Click”** on buttons; narrow **Selection Type** to the exact item(s).
* Use **Set Value → SQL/PLSQL** with **Page Items to Submit** and **Items to Return** configured.
* For conditional UI, use **Show/Hide** + **Server-side Conditions** (defense in depth).
* For AJAX PL/SQL, use **Execute Server-side Code** (with proper item submit/return).
* Avoid page flicker: combine **Hide** + **Disable** while waiting; show **apex.message.showPageSuccess** on success.

---

## 1) Show/Hide a Region When Item = Value

**Dynamic Action**

* Event: *Change* (Item: `P10_STATUS`)
* True Action: *Show* (Selection: Region **“Reason Details”**)
* False Action: *Hide* (same region)

**Condition**

* Client-side Condition on True/False actions:

  * When `P10_STATUS = 'REJECTED'` (Type: *Item = Value*)

> Pitfall: Always also add a **server-side condition** on the region (Authorization/Condition) to prevent accidental exposure on initial render.

---

## 2) Set Value from SQL (Dependent Select)

Populate `P10_CITY` when `P10_ZIP` changes.

**DA**

* Event: *Change* on `P10_ZIP`
* True Action: *Set Value*

  * Type: **SQL Statement**
  * SQL: `select city from zipcodes where zip = :P10_ZIP`
  * **Page Items to Submit**: `P10_ZIP`
  * **Affected Elements**: `P10_CITY` (Items to Return auto-set)

> Pitfall: If you forget **Page Items to Submit**, your server code will see `NULL` and return nothing.

---

## 3) Execute Server-side PL/SQL and Return Values

Compute discount and message into `P10_DISCOUNT`, `P10_MSG`.

**DA**

* Event: *Change* on `P10_AMOUNT`
* True Action: *Execute Server-side Code*

```plsql
declare
  l_disc number := 0;
begin
  if :P10_AMOUNT >= 100 then
    l_disc := 10;
    :P10_MSG := 'Bulk discount applied';
  else
    :P10_MSG := null;
  end if;
  :P10_DISCOUNT := l_disc;
end;
```

* **Items to Submit**: `P10_AMOUNT`
* **Items to Return**: `P10_DISCOUNT,P10_MSG`

---

## 4) Client-side: Validate & Notify

```javascript
// True Action: Execute JavaScript Code
(function(){
  const amt = +apex.item("P10_AMOUNT").getValue();
  if (amt < 0) {
    apex.message.clearErrors();
    apex.message.showErrors([{
      type: "error",
      location: ["inline"],
      pageItem: "P10_AMOUNT",
      message: "Amount cannot be negative.",
      unsafe: false
    }]);
    throw "abort"; // stop DA flow
  }
})();
```

> Tip: Throwing stops subsequent DA actions (no extra AJAX call).

---

## 5) Cascading LOV (Parent → Child)

**Child item** (`P10_PRODUCT`) LOV query:

```sql
select name d, id r
from products
where category_id = :P10_CATEGORY
order by 1
```

* In **Cascading LOV** settings for `P10_PRODUCT`:

  * Parent Items: `P10_CATEGORY`
  * **Items to Submit**: `P10_CATEGORY`
  * **Optimize Refresh**: On

---

## 6) Refresh Region After Server Action

After creating a row in a DA, add a **Refresh** action on the IR/IG region.
If source uses **“Page Items to Submit”**, ensure the new value is submitted or use a **Set Value** before refresh.

---

## Notes

* Keep DAs **small and composable**—one job per DA.
* Use **Server-side Condition** mirrors for any client-side Show/Hide (zero trust).
* Prefer **Execute Server-side Code** over classic processes for snappy UX.
* For complex JS, move code to **File → app.js** and call functions from DAs.

---

```yaml
---
id: templates/apex/75-dynamic-actions.apex.md
lang: plsql
platform: apex
scope: ui-reactivity
since: "v0.1"
tested_on: "APEX 24.2"
tags: [dynamic-actions, set-value, ajax, show-hide, cascading-lov, validation]
description: "Battle-tested DA patterns: show/hide, compute via SQL/PLSQL, JS validation, cascades, and region refresh."
---
```
