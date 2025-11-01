---
id: ords/proxy-user-logging
since: "v0.1"
tags: [ords, proxy, logging]
description: "Proxy user tips + log hygiene"
---

- Ensure proxy grants at the DB level (ALTER USER ... GRANT CONNECT THROUGH ...).
- Keep logs on a short rotation; ship to central if available.
- Use different log folders per environment.
