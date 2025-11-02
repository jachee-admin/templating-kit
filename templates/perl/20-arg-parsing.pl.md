###### Perl

# Argument Parsing: `Getopt::Long` & `Getopt::Long::Descriptive` (Requireds, Enums, Repeats)

Two ergonomic ways to parse flags: low-dep `Getopt::Long`, and human-friendly `Descriptive` with built-in usage text.

## TL;DR

* `Getopt::Long` gives control; validate requireds yourself.
* `Descriptive` adds types, defaults, and pretty usage out of the box.
* Stackable `-v -v` verbosity and `--key=value` are standard.
* Use `Pod::Usage` when you want `perldoc`-style `--help`.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));

# --- Option Set A: Getopt::Long ------------------------------------------------
{
    require Getopt::Long; Getopt::Long->import(qw(:config no_ignore_case bundling));
    require Pod::Usage;

    my %opt = (limit => 100, verbose => 0);
    Getopt::Long::GetOptions(
        'mode|m=s'   => \$opt{mode},      # required by validation
        'limit|l=i'  => \$opt{limit},     # integer
        'tag|t=s@'   => \$opt{tags},      # repeatable: --tag a --tag b
        'verbose|v+' => \$opt{verbose},   # stackable
        'dry-run|n'  => \$opt{dryrun},
        'help|h'     => sub { Pod::Usage::pod2usage(1) },
    ) or Pod::Usage::pod2usage(2);

    # Validate requireds & enums
    defined $opt{mode} or Pod::Usage::pod2usage(
        -message => "Missing --mode (fast|safe)",
        -exitval => 2, -verbose => 0
    );
    $opt{mode} =~ /\A(?:fast|safe)\z/ or die "--mode must be fast|safe\n";

    # Use it
    say "A) mode=$opt{mode} limit=$opt{limit} verbose=$opt{verbose} dryrun=" . ($opt{dryrun}//0);
    say "    tags=@{ $opt{tags}//[] }";
}

# --- Option Set B: Getopt::Long::Descriptive ----------------------------------
{
    require Getopt::Long::Descriptive;
    my ($opt, $usage) = Getopt::Long::Descriptive::describe_options(
        '%c %o',
        ['mode|m=s',   'run mode (fast|safe)',   { required => 1 }],
        ['limit|l=i',  'row limit (default 100)',{ default  => 100 }],
        ['tag|t=s@',   'repeatable tag(s)'],
        ['verbose|v+', 'increase verbosity'],
        ['dry-run|n',  'no writes'],
        ['help|h',     'this help'],
    );
    if ($opt->help) { print $usage->text; exit 0 }

    $opt->mode =~ /\A(?:fast|safe)\z/ or die "--mode must be fast|safe\n";

    say "B) mode=" . $opt->mode . " limit=" . $opt->limit . " verbose=" . ($opt->verbose // 0);
    say "    tags=" . join(',', @{ $opt->tag // [] });
}
```

---

## Notes

* For complex CLIs, `Descriptive` reduces boilerplate and produces friendly `--help`.
* Use `s@` for repeatable string options and `i@` for repeatable integers.
* Prefer validating enums explicitly—don’t let bad strings leak deeper into the program.

---

```yaml
---
id: templates/perl/20-arg-parsing.pl.md
lang: perl
platform: posix
scope: cli
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, getopt-long, getopt-descriptive, cli, enums]
description: "Two styles of option parsing with requireds, enums, repeats, and pretty help."
---
```
