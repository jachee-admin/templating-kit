###### Perl

# Strict Mode Skeleton: `strict`, `warnings`, UTF-8 I/O, Structured Logging, Dry-Run, Usage

Baseline scaffold for robust Perl CLIs: strictness, UTF-8-safe I/O, structured logs, `Try::Tiny` guarded main, `--dry-run/--verbose`, and help via `Pod::Usage`.

## TL;DR

* `use v5.36;`
* `use strict;`
* `use warnings;`
* `use utf8;`
* `use open qw(:std :encoding(UTF-8));`
* `Getopt::Long` + `Pod::Usage` for flags/help; stackable `--verbose`
* Structured `log_*` with ISO timestamps and caller line/function
* `Try::Tiny` around `main()` for clean error surfaces
* `DRYRUN=1` or `--dry-run` to preview side effects via `run cmd, @args`

---

## Script

```perl
#!#!/usr/bin/env perl
# strict-skeleton.pl — reusable strict-mode scaffold for Perl
use v5.34;
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use feature qw(signatures);
no warnings 'experimental::signatures';

use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Time::HiRes qw(time);
use POSIX qw(strftime);
use Try::Tiny;

# --- Defaults -----------------------------------------------------------------
my %opt = (
    verbose => 0,
    dryrun  => 0,
);

# Ensure logs flush promptly
select STDERR; $| = 1; select STDOUT; $| = 1;

# --- Time & logging helpers ---------------------------------------------------
sub _ts () {
    # RFC3339 / ISO-8601 in UTC
    return strftime('%Y-%m-%dT%H:%M:%SZ', gmtime());
}

# shell-quote purely for display (does NOT affect how we exec)
sub _q ($s) {
    # Single-quote style: 'foo' -> 'foo', foo bar -> 'foo bar'
    # Also handle embedded single quotes: abc'def -> 'abc'"'"'def'
    return "''" if $s eq '';
    $s =~ s/'/'"'"'/g;
    return "'$s'";
}

sub _log ($level, $msg) {
    my (undef, $file, $line, $sub) = caller(2);  # <-- two levels up
    $sub =~ s/^.*::// if defined $sub;
    printf STDERR "%s %-5s pid=%d file=%s line=%d fn=%s %s\n",
        _ts(), $level, $$, ($file // '?'), ($line // 0), ($sub // 'main'), $msg;
}


# sub _log ($level, $msg, $file, $line, $sub) {
#     # Normalized sub name: main::foo -> foo
#     $sub //= 'main';
#     $sub =~ s/^.*:://;
#     printf STDERR "%s %-5s pid=%d file=%s line=%d fn=%s %s\n",
#         _ts(), $level, $$, ($file // '?'), ($line // 0), $sub, $msg;
# }

sub log_debug ($msg) {
    return unless $opt{verbose};
    my (undef, $file, $line, $sub) = caller;
    _log('DEBUG', $msg);
}
sub log_info ($msg)  { my (undef,$f,$l,$s)=caller; _log('INFO',  $msg) }
sub log_warn ($msg)  { my (undef,$f,$l,$s)=caller; _log('WARN',  $msg) }
sub log_error($msg)  { my (undef,$f,$l,$s)=caller; _log('ERROR', $msg) }

# --- Dry-run + command execution ----------------------------------------------
sub run (@cmd) {
    my $shown = join ' ', map { _q($_) } @cmd;
    log_info("+ $shown");

    if ($opt{dryrun}) {
        log_debug("dry-run: skipping exec");
        return 1;
    }

    system @cmd;
    my $status = $?;
    if ($status == -1) {
        die "failed to execute: $shown: $!";
    }
    if ($status & 127) {
        my $sig = ($status & 127);
        die sprintf "command died with signal %d: %s", $sig, $shown;
    }
    my $rc = $status >> 8;
    $rc == 0 or die "command failed rc=$rc: $shown";
    return 1;
}

# --- Usage & flag parsing ------------------------------------------------------
sub usage {
    pod2usage(-verbose => 1, -exitval => 0);
}

GetOptions(
    'input|i=s'   => \$opt{input},
    'output|o=s'  => \$opt{output},
    'verbose|v+'  => \$opt{verbose},
    'dry-run|n'   => \$opt{dryrun},
    'help|h'      => sub { usage() },
) or pod2usage(2);

# --- Main ----------------------------------------------------------------------
sub main() {
    my $t0 = time();
    log_info(sprintf "Starting (dryrun=%d, verbose=%d)", @opt{qw(dryrun verbose)});

    # Example side-effect: echo something
    run 'echo', 'Hello, strict Perl';

    log_info(sprintf "Done in %.3fs", time() - $t0);
    return 0;
}

# Guarded execution with neat error
my $exit = 0;
try   { $exit = main() }
catch {
    my $err = $_ // 'unknown';
    $err =~ s/\s+\z//;
    log_error("Unhandled: $err");
    $exit = 1;
};
exit $exit;

__END__

=head1 NAME
strict-skeleton.pl - strict, UTF-8, logging, dry-run scaffold

=head1 SYNOPSIS
strict-skeleton.pl [-n|--dry-run] [-v|--verbose] -i FILE -o FILE

=head1 DESCRIPTION
Starter skeleton for disciplined Perl CLIs with safe defaults and better logging.

```

---

## Notes

* Keep logs on **stderr** so you can pipe **stdout** as data.
* Use `-v -v` to increase verbosity levels; avoid chatty defaults.
* Prefer explicit failures (`die`) over silent returns for reliability.

---

```yaml
---
id: templates/perl/10-script-skeleton.pl.md
lang: perl
platform: posix
scope: scaffolding
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, strict, utf8, logging, dry-run, getopt, try-tiny]
description: "Strict-mode Perl CLI scaffold with UTF-8 I/O, structured logs, Try::Tiny guard, dry-run, and Pod::Usage."
---
```
