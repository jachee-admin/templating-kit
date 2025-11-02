###### APEX

# App Export Checklist: Sanity Checks Before Exporting for Release or Version Control

A pre-flight list to ensure your APEX application export represents a clean, consistent, and portable build.
Use this before generating a `.sql` or split-file export for version control or deployment pipelines.

---

## TL;DR

* Verify Shared Components and Dependencies are all included.
* Ensure Build Options and Conditional UI are correctly toggled.
* Confirm Friendly URLs and Application Settings match deployment targets.
* Always export with “Split Files” enabled for Git diffability.
* Include environment-specific substitution variables and ACL notes in your release doc.

---

## 1. Shared Components Completeness

* **Authentication Schemes** — confirm the correct scheme is **current**, and unused prototypes are deleted or marked inactive.
* **Authorization Schemes** — ensure all are named consistently and not duplicated under similar logic.
* **Lists of Values (LOVs)** — check static LOVs are centralized, not page-local unless truly specific.
* **Web Credentials & REST Data Sources** — verify Static IDs exist (used in code, e.g., `p_credential_static_id => 'API_CRED'`).
* **Email Templates** — test merge substitution strings render properly.
* **Themes / Templates** — confirm custom templates are marked *Valid for Export* and associated CSS is in Static Files.

---

## 2. Application & Build Options

* Open **Shared Components → Build Options**, ensure each flag matches release intent (e.g., “DEBUG” off in prod).
* Remove deprecated options or merge duplicates.
* Verify **Conditional Display** logic (buttons, regions, processes) references the correct Build Option names.
* For **Team Dev Notes or TODOs**, clean or close them before tagging release.

---

## 3. Session & Security Settings

* Check **Application → Security**:

  * Session timeout, re-authentication mode, and Cookie scope are correct.
  * Browser cache control = “No caching” for sensitive apps.
* Confirm **Public Pages** list (authentication required vs. allowed) is intentional.
* Review **Authorization Schemes** and **Access Control** packages for hardcoded usernames or test users.

---

## 4. URL, Theme, and Environment Config

* Verify **Friendly URLs** enabled (`Application → Definition → Friendly URL`).
* Confirm **Application Base Path** doesn’t include dev-specific schema or workspace info.
* For multi-environment deployments:

  * Validate `apex_application_install.set_application_alias` and ID usage in your CI/CD pipeline.
  * Check app alias uniqueness across workspaces.
* Theme Roller customizations exported (ensure “Substitute Theme” not set to another app ID).

---

## 5. Static Files & Supporting Objects

* All JS/CSS under **Shared Components → Static Application Files** rather than page-local assets.
* Remove orphaned legacy files (inspect file manifest).
* If using **Supporting Objects**:

  * Ensure install scripts create necessary tables, sequences, and grants.
  * Verify “Auto Install Supporting Objects” is disabled unless specifically required.

---

## 6. Database Dependencies

* Validate references to:

  * Packages / views are schema-qualified (`APP_SCHEMA.PKG_FOO`).
  * External synonyms exist in target schema.
  * DDL scripts (if any) are versioned separately in Git (not embedded in the export).
* Check **APEX Advisor** → “References” to find unresolved database object names.

---

## 7. Export Configuration

* From **App Builder → Export / Import → Export**, set:

  * ✅ **Split Files**: yes (for Git diffs).
  * ✅ **Include Supporting Objects** only if installing elsewhere.
  * ✅ **Export as Zip** if large.
  * 🔲 **Include Translations** only if tested.
* Commit the full directory (not just `fXXXX.sql`) under `/apex/apps/`.

---

## 8. Post-Export Validation

* Re-import into a clean workspace to confirm:

  * No “Missing Shared Component” warnings.
  * Application opens without prompts for unsupported credentials or invalid IDs.
* Tag Git commit with app alias and version:
  `git tag apex-myapp-v1.4.3`

---

## 9. Release Notes / Metadata Capture

Record in your changelog:

| Item          | Example                              |
| ------------- | ------------------------------------ |
| App ID        | 105                                  |
| Alias         | `finance_admin`                      |
| Version       | 1.4.3                                |
| Workspace     | PROD                                 |
| Export Date   | `2025-11-02T14:30Z`                  |
| Exporter      | `john.doe`                           |
| Build Options | `DEBUG=OFF`, `BETA_FEATURES=OFF`     |
| REST Sources  | `api_finance_v1`, `auth_oauth2_cred` |

---

## Notes

* Keep a **DEV → TEST → PROD** export policy, never edit directly in PROD.
* Combine this checklist with SQLcl or `apexexport` automation for CI/CD pipelines.
* Include schema grants and ACL updates in the same commit as the export.

---

```yaml
---
id: templates/apex/01-app-export-checklist.md
lang: plsql
platform: apex
scope: release
since: "v0.1"
tested_on: "APEX 24.2"
tags: [apex, export, release, checklist, deployment]
description: "Comprehensive sanity checklist before exporting APEX apps for release or version control."
---
```

