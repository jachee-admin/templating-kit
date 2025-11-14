###### Perl

# Tied Variables & Symbol Table Hacks: Custom Storage, Dynamic Methods, AUTOLOAD Tricks

Low-level Perl wizardry. Mostly unnecessary—but sometimes exactly the right tool for extending behavior dynamically.

## TL;DR

* `tie` lets you override get/set behavior of variables.
* Useful for ordered hashes, lazy loads, transparent encryption, etc.
* Symbol-table manipulation allows runtime definition or inspection of functions/vars.
* `AUTOLOAD` can generate missing methods dynamically (be careful!).

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings;

# --- 1) Ordered Hash (Tie::IxHash) --------------------------------------------
use Tie::IxHash;
tie my %h, 'Tie::IxHash';
%h = (a => 1, c => 3, b => 2);
for my $k (keys %h) { say "$k=$h{$k}" }  # preserves insertion order

# --- 2) Custom tie (intercept access) -----------------------------------------
{
    package Tie::Upper;
    use strict; use warnings;
    sub TIESCALAR { bless { val => '' }, shift }
    sub FETCH     { uc($_[0]->{val}) }
    sub STORE     { $_[0]->{val} = $_[1] }
}
tie my $foo, 'Tie::Upper';
$foo = 'bar';
say $foo;  # BAR

# --- 3) Symbol table introspection --------------------------------------------
no strict 'refs';
for my $sym (keys %{"main::"}) {
    say "symbol: $sym" if *{"main::$sym"}{CODE};
}
use strict 'refs';

# --- 4) AUTOLOAD method dispatch ----------------------------------------------
{
    package Dynamic;
    our $AUTOLOAD;
    sub AUTOLOAD {
        (my $method = $AUTOLOAD) =~ s/.*:://;
        return if $method eq 'DESTROY';
        return "dynamic:$method";
    }
}
my $o = bless {}, 'Dynamic';
say $o->hello;     # prints "dynamic:hello"
say $o->pingpong;  # prints "dynamic:pingpong"

# --- 5) Symbol aliasing --------------------------------------------------------
*say_hi = sub { print "hi!\n" };
say_hi();
```

---

## Notes

* Symbol table access is the closest you’ll get to reflection/metaprogramming in Perl.
* `AUTOLOAD` should normally be paired with `can()` override to appease introspection.
* `Tie::IxHash`, `Tie::File`, `Tie::Cache::LRU` are the only “safe to use in production” ties these days.
* Never expose user input to `eval` or symbol-table names.

---

```yaml
---
id: docs/perl/190-ties-symbols.pl.md
lang: perl
platform: posix
scope: meta
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, tie, symbol-table, autoload, dynamic, introspection, metaprogramming]
description: "Tied variables, ordered hashes, symbol-table introspection, AUTOLOAD dispatch, and aliasing examples."
---
```
