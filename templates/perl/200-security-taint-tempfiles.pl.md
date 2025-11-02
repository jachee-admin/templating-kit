###### Perl

# Security, Taint Mode, Safe Tempfiles, and Input Validation

Perl’s taint system and secure tempfile patterns — critical for scripts handling untrusted input, uploads, or shell parameters.

## TL;DR

* Run with `-T` (taint mode) to force validation of external data.
* Always untaint inputs via regex capture.
* Limit `$ENV{PATH}`, never rely on inherited environment.
* Use `File::Temp` or `Path::Tiny->tempfile` for safe temporary workspaces.
* Don’t interpolate untrusted data into system calls—use lists.

---

## Script

```perl
#!/usr/bin/env perl -T
use v5.36; use strict; use warnings;

# --- 1) Environment hygiene ----------------------------------------------------
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{PATH} = '/usr/bin:/bin';

# --- 2) Untainting -------------------------------------------------------------
my $user_input = shift @ARGV // die "usage: $0 safe_filename";
($user_input) = $user_input =~ m{\A([\w./-]+)\z}
    or die "bad filename: $user_input";

open my $fh, '<', $user_input or die "open: $!";

# --- 3) Secure tempfile --------------------------------------------------------
use File::Temp qw(tempfile tempdir);
my ($tmpfh, $tmpfile) = tempfile(SUFFIX => '.dat', UNLINK => 1);
print {$tmpfh} "temporary content\n";

# --- 4) Safe system calls (no shell) ------------------------------------------
my @cmd = ('/usr/bin/sort', $user_input);
system @cmd and die "sort failed: $?";

# --- 5) Drop privileges (Unix) -------------------------------------------------
if ($> == 0) {
    $< = $>;    # real uid = effective uid
    $) = $>;    # real gid = effective gid
}

# --- 6) Avoid dangerous ops ----------------------------------------------------
# Never use:
#   eval $user_input
#   system("$user_input")     # unsafe
#   open(..., "|$user_input") # unsafe

# --- 7) Safe tempdir cleanup ---------------------------------------------------
my $tmpd = tempdir(CLEANUP => 1);
say "working in $tmpd";
```

---

## Notes

* Taint mode prevents variables derived from untrusted sources from being used in unsafe contexts.
* Always verify filenames, paths, and command arguments explicitly.
* When invoking external programs, pass arguments as arrays — not interpolated strings.
* For long-running daemons, consider dropping privileges after binding ports or files.

---

```yaml
---
id: templates/perl/200-security-taint-tempfiles.pl.md
lang: perl
platform: posix
scope: security
since: "v0.1"
tested_on: "perl 5.36, File::Temp 0.2311"
tags: [perl, security, taint, tempfile, validation, safe-system, sandboxing]
description: "Security and hygiene: taint mode, environment sanitization, safe tempfiles, untainting, and command safety."
---
```
