###### Perl

# Exports & Namespaces: `Exporter`, `Exporter::Tiny`, Tags, and Import Hooks

Ship utility functions cleanly. Control what gets exported by default, offer tags, and avoid polluting caller namespaces.

## TL;DR

* Use `Exporter` (core) or `Exporter::Tiny` (nicer features).
* Keep `@EXPORT` small; prefer `@EXPORT_OK` and tags (`%EXPORT_TAGS`).
* Modules should work both with and without importing (call `My::Util::sum`).
* Document import options in POD.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings;

# lib/My/Util.pm ---------------------------------------------------------------
{
    package My::Util;
    use strict; use warnings;
    use Exporter 'import';
    our @EXPORT      = ();                 # nothing by default
    our @EXPORT_OK   = qw(sum mean median);
    our %EXPORT_TAGS = (
        all   => [@EXPORT_OK],
        stats => [qw(sum mean median)],
    );

    sub sum  { my $t=0; $t+=$_ for @_; $t }
    sub mean { @_ ? sum(@_)/@_ : 0 }
    sub median {
        return 0 unless @_;
        my @s = sort { $a <=> $b } @_;
        return @s % 2 ? $s[@s/2] : ($s[@s/2-1] + $s[@s/2]) / 2;
    }
    1;
}

# Using it ---------------------------------------------------------------------
use lib 'lib';
use My::Util qw(sum);              # import only sum
say sum(1,2,3);

use My::Util qw(:stats);           # import tagged set
say mean(10,20,40);

# Without imports (fully qualified)
say My::Util::median(1..9);
```

### Exporter::Tiny variant

```perl
# lib/My/Tiny.pm
{
    package My::Tiny;
    use strict; use warnings;
    use Exporter::Tiny -exporter_setup => 1;
    our @EXPORT_OK   = qw(kv);
    our %EXPORT_TAGS = ( all => \@EXPORT_OK );

    sub kv (%h) { map { ($_ => $h{$_}) } keys %h }  # toy example
    1;
}
use My::Tiny qw(:all);
my %h = (a=>1,b=>2); my @pairs = kv(%h);
```

---

## Notes

* Avoid exporting by default in big codebases—explicit imports keep call sites readable.
* If you must have defaults, make them minimal and safe.
* Consider `Sub::Exporter` for advanced generators (but that’s heavy unless you truly need it).

---

```yaml
---
id: templates/perl/147-exporter-util.pl.md
lang: perl
platform: posix
scope: modules
since: "v0.1"
tested_on: "perl 5.36, Exporter 5.77, Exporter::Tiny 1.006"
tags: [perl, exporter, exporter-tiny, namespaces, imports, tags]
description: "Clean module exports with Exporter/Exporter::Tiny, optional tags, and import/no-import usage patterns."
---
```
