---
id: python/retry-with-jitter
lang: python
since: "v0.1"
tags: [retry, jitter, decorator]
description: "Transient-safe retry with cap + jitter"
---

### Python: Module - Retry w/ Jitter
```python
import random, time, functools

class RetryableError(Exception):
    pass

def retry(max_attempts=5, base=0.25, cap=4.0):
    def deco(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            attempt = 0
            while True:
                try:
                    return fn(*args, **kwargs)
                except RetryableError as e:
                    attempt += 1
                    if attempt >= max_attempts:
                        raise
                    sleep = min(cap, base * (2 ** (attempt - 1)))
                    sleep += random.uniform(0, sleep * 0.2)  # ±20% jitter
                    time.sleep(sleep)
        return wrapper
    return deco
```
