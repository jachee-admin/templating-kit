---
title: "NC DPI Templating Kit (Markdown‑First)"
since: "v0.1"
description: "Grab‑and‑go code snippets and patterns as readable Markdown."
---

This repo stores **scripts as Markdown** so you can:
- read context and guardrails up top,
- copy code blocks in one swipe,
- and keep examples + variations near the primary snippet.

Conventions:
- Each file starts with a YAML header.
- Primary snippet is the first fenced code block; variants follow.
- Use `tags:` to make ripgrep/grep searches deliciously fast.
- Filenames end with the original extension **plus** `.md` (e.g., `10-upsert-basic.sql.md`).

> Rule of thumb: if a snippet needs more than 60 seconds of adaptation, split it.
