###### Perl

# Retry with Jitter: Transient Recovery, Backoff Curves, and Idempotence Safety

Robust retries for flaky operations — HTTP calls, DB queries, file locks — with bounded exponential backoff and random jitter to prevent synchronized thundering herds.

## TL;DR

* Only retry *idempotent* actions (GETs, SELECTs, etc.).
* Use exponential backoff with jitter (`rand()` noise).
* Stop after a sane cap (2–3 seconds max per sleep).
* Wrap in `Try::Tiny` to trap transient errors cleanly.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings;
use Try::Tiny;
use Time::HiRes qw(usleep);

sub with_retry (&$$$) {    # code, max_attempts, base_delay, max_delay
    my ($code, $max, $base, $cap) = @_;
    $cap //= 2.0;  # seconds
    my $delay = $base;
    for my $attempt (1..$max) {
        my $ok = try { $code->(); 1 } catch { warn "attempt $attempt: $_"; undef };
        return 1 if $ok;
        last if $attempt == $max;
        my $jitter = (rand() - 0.5) * $delay;      # ±50%
        my $sleep  = $delay + $jitter;
        $sleep = $cap if $sleep > $cap;
        usleep(int($sleep * 1_000_000));
        $delay *= 1.7;                             # exponential growth
    }
    return;
}

# Example:
# with_retry { http_json_get($url) } 5, 0.1, 2.0;
```

### Optional: classify errors

```perl
sub is_transient ($err) {
    return 1 if $err =~ /\b(?:timeout|connection reset|temporarily unavailable)\b/i;
    return 0;
}
```

### Variation: pure functional form

```perl
sub retry_until (&$) {
    my ($fn,$n) = @_;
    for (1..$n) { return 1 if $fn->(); sleep 1 }
    return;
}
```

---

## Notes

* Use `Time::HiRes::usleep` for sub-second backoff.
* Add jitter to avoid herd effects when many clients retry.
* Combine with `with_http_retry` or DBI wrappers for transient errors.

---

```yaml
---
id: docs/perl/130-retry-jitter.pl.md
lang: perl
platform: posix
scope: resilience
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, retry, jitter, backoff, try-tiny, transient, resilience]
description: "Bounded exponential backoff with jitter for idempotent retries using Try::Tiny and Time::HiRes."
---
```