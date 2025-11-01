---
id: ords/serve-config-snippets
since: "v0.1"
tags: [ords, config, serve]
description: "Flags and patterns for ORDS serve"
---

- `--config "C:\\ords\\config"`: explicit config dir
- `serve --port 8181`: quick dev serve
- Avoid passing `--db-pool default`; omit entirely to use default
- Add `--proxy-user` if required by your environment
- Add `--log-folder "C:\\ords\\logs"` to persist logs
