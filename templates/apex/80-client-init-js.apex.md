###### APEX

# Client Init JS: `app.js` Module, `apex.jQuery` Hooks, `apex.item()` Helpers, Messages

Centralize your client code: a tiny `app.js` with init hooks, item helpers, and consistent message UX.

---

## TL;DR

* Put client code in one **Static Application File**: `app.js`.
* Use `apex.jQuery(document).ready(...)` or `apex.page.init` for page-ready hooks.
* Read/set items with `apex.item("PXX").getValue()/setValue()`.
* Standardize notifications with `apex.message.showPageSuccess()` and `apex.message.showErrors()`.

---

## 1) Project Layout (Static Files)

* **Shared Components → Static Application Files**: upload `js/app.js`.
* Page **Execute when Page Loads**: `app.init();`

---

## 2) `app.js` Skeleton

```javascript
/* app.js */
window.app = window.app || (function () {
  "use strict";

  function onReady() {
    // Example: auto-trim a text item
    const it = apex.item("P10_NAME");
    if (it) { it.setValue((it.getValue() || "").trim()); }
  }

  function bindGlobal() {
    // Example: delegate click
    apex.jQuery(document).on("click", "[data-do='help']", function () {
      apex.message.showPageSuccess("Help is on the way!");
    });
  }

  function showError(itemName, msg) {
    apex.message.clearErrors();
    apex.message.showErrors([{
      type: "error",
      location: "inline",
      pageItem: itemName,
      message: msg,
      unsafe: false
    }]);
  }

  function toast(msg) {
    apex.message.showPageSuccess(msg);
  }

  // Public API
  return {
    init: function () {
      apex.jQuery(onReady);   // DOM ready
      bindGlobal();
    },
    showError, toast
  };
})();
```

**Page → Execute when Page Loads:**

```javascript
app.init();
```

---

## 3) Item Helpers You’ll Use Daily

```javascript
// Get/Set
const v = apex.item("P10_AMOUNT").getValue();
apex.item("P10_AMOUNT").setValue(42);

// Enable/Disable/Hide
apex.item("P10_CODE").disable();
apex.item("P10_CODE").enable();
apex.region("empReport").hide(); // Region Static ID: empReport

// Spinner for long actions
apex.util.showSpinner($("#empReport"));
apex.server.process("DO_SOMETHING", { pageItems: "#P10_ID" })
  .done(function(pData){ apex.util.hideSpinner($("#empReport")); app.toast("Done!"); })
  .fail(function(){ apex.util.hideSpinner($("#empReport")); app.showError("P10_ID","Failed"); });
```

---

## 4) Standard Messages

```javascript
apex.message.clearErrors();
apex.message.showPageSuccess("Saved successfully");
// Inline error (with DA “Execute JavaScript Code”)
app.showError("P10_EMAIL", "Please enter a valid email.");
```

---

## 5) Callbacks: Page Events

```javascript
apex.jQuery(window).on("theme42ready", function () {
  // Theme ready hook
});

apex.jQuery(document).on("apexafterrefresh", "#empReport", function () {
  // Region refreshed
});
```

---

## Notes

* Keep `app.js` idempotent; safe to call `init()` repeatedly.
* Prefer **Static IDs** for regions/items you control in JS.
* For bigger apps, split into modules (`app.lov.js`, `app.orders.js`) and load as needed.
* Always avoid global leaks—expose only a minimal `app` API.

---

```yaml
---
id: docs/apex/80-client-init-js.apex.md
lang: javascript
platform: apex
scope: client
since: "v0.1"
tested_on: "APEX 24.2"
tags: [client, javascript, apex.item, apex.message, jQuery, init]
description: "A tidy app.js with ready hooks, item helpers, region events, and standardized messages."
---
```