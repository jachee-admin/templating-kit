###### Perl

# Logging & Diagnostics: Minimal Logger, `Log::Any`, Stacktraces, Pretty Inspect

Structured logs that don’t fight you, plus rich error context when things explode.

## TL;DR

* Minimal dependency-free logger for small scripts; `Log::Any` for bigger.
* Add context: timestamp, level, pid, line, function.
* On errors, show stack (`Devel::StackTrace`) and a compact message.
* For inspecting data, prefer `Data::Printer` over raw `Dumper`.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));
use Try::Tiny;

# --- Minimal logger ------------------------------------------------------------
sub _ts    { scalar gmtime() =~ s/ /T/r . 'Z' }
sub _lno   { (caller(1))[2] // 0 }
sub _func  { (caller(1))[3] // 'main' }
sub _log ($level, $msg) {
    printf STDERR "%s %-5s pid=%d line=%d fn=%s %s\n", _ts(), $level, $$, _lno(), _func(), $msg;
}
sub log_debug ($m){ $ENV{DEBUG} and _log('DEBUG', $m) }
sub log_info  ($m){ _log('INFO',  $m) }
sub log_warn  ($m){ _log('WARN',  $m) }
sub log_error ($m){ _log('ERROR', $m) }

# --- Log::Any variant ----------------------------------------------------------
# use Log::Any qw($log);
# use Log::Any::Adapter ('Stdout'); # or 'Stderr'
# $log->infof('rows=%d', $rows);

# --- Pretty data inspect -------------------------------------------------------
# cpanm Data::Printer
# use Data::Printer; p($data);

# --- Error with stack ----------------------------------------------------------
sub risky { die "boom at work()" }
my $rc = 0;
try {
    risky();
    $rc = 0;
}
catch {
    my $err = $_; chomp $err;
    require Devel::StackTrace;
    my $st = Devel::StackTrace->new;
    log_error("FAIL: $err");
    warn $st->as_string;  # goes to STDERR
    $rc = 1;
};
exit $rc;
```

---

## Notes

* Keep the **minimal logger** around for scripts you’ll paste into chat/notes.
* For long-running processes, wire **Log::Any** to syslog or files with adapters.
* Avoid dumping megabytes into logs—sample the payload or summarize.

---

```yaml
---
id: docs/perl/30-logging-diagnostics.pl.md
lang: perl
platform: posix
scope: diagnostics
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, logging, log-any, stacktrace, diagnostics]
description: "Small logger pattern, Log::Any adapter hint, stacktraces, and pretty inspection."
---
```
