###### Perl

# Regex Cookbook: Named Captures, `\K`, Atomic/Possessive, Branch-Reset, Conditionals, `\G`

Practical patterns you’ll actually use—plus a few spicy advanced tools for when logs and protocols get weird.

## TL;DR

* Prefer **named captures** and explicit anchors.
* Use `\K` to “cut off the prefix” without capturing it.
* Atomic groups `(?>...)` and **possessive quantifiers** `++` stop catastrophic backtracking.
* **Branch-reset** groups `(?|...)` keep numbering consistent across alternatives.
* `\G` lets you iteratively scan a string across multiple matches without reparsing.
* Conditional subpatterns `(?(?=lookahead)yes|no)` when formats diverge.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));

my $line = q{ERROR 2025-11-01T12:34:56Z user=john action="login attempt" ip=192.0.2.5};

# --- 1) Named captures ---------------------------------------------------------
if ($line =~ /^(?<lvl>INFO|WARN|ERROR)\s+(?<ts>\S+)\s+(?<rest>.*)$/) {
    my %m = %+;                               # { lvl => ..., ts => ..., rest => ... }
    say "lvl=$m{lvl} ts=$m{ts}";
}

# --- 2) \K: drop the prefix, keep the tail ------------------------------------
(my $msg = $line) =~ s/^.*?\s\K//;           # remove first field+space
say $msg;                                    # "2025-... ip=192.0.2.5"

# --- 3) Atomic & possessive to curb backtracking ------------------------------
my $url = 'https://example.org/a/b?q=1';
if ($url =~ /(?>https?:\/\/\S+?)\b/) { say "url ok" }   # atomic group
# or possessive quantifiers (greedy, no backtrack):
if ($url =~ /(https?:\/\/\S++)/) { say "url ok (pos)" }

# --- 4) Branch-reset: uniform numbering across alternatives -------------------
# Format A: id=123 name="Ada"
# Format B: name="Ada" id=123
for my $s ('id=123 name="Ada"', 'name="Ada" id=123') {
    if ($s =~ /(?|id=(\d+)\s+name="([^"]+)"|name="([^"]+)"\s+id=(\d+))/) {
        my ($id, $name) = $s =~ /id=(\d+)|name="([^"]+)"/g; # demo, but:
        # Better: use a single capture pass:
        $s =~ /(?|id=(\d+)\s+name="([^"]+)"|name="([^"]+)"\s+id=(\d+))/;
        my ($c1,$c2) = ($1,$2);  # numbering resets per branch; $1 is id or name consistently per pattern
        say "branch-reset got: $c1 $c2";
    }
}

# --- 5) Conditional subpatterns ------------------------------------------------
# Parse either [lvl] message   OR   lvl=... message
for my $s ('[WARN] stuff', 'lvl=INFO stuff') {
    if ($s =~ /(?(?=\[)(?:\[(?<lvl1>\w+)\]\s+(?<msg1>.*))|(?:lvl=(?<lvl2>\w+)\s+(?<msg2>.*)))/) {
        my $lvl = $+{lvl1} // $+{lvl2};
        my $msg = $+{msg1} // $+{msg2};
        say "lvl=$lvl msg=$msg";
    }
}

# --- 6) \G scanning: token-by-token parse -------------------------------------
my $log = q{key="a b" x=1 y=2 key="c d" z=3};
my %kv; pos($log) = 0;
while ($log =~ /\G\s*(?:key="([^"]+)"|(\w+)=([^\s"]+))/g) {
    if (defined $1) { push @{ $kv{key} }, $1 }
    else            { $kv{$2} = $3 }
}
# %kv = ( key => ['a b','c d'], x=>1, y=>2, z=>3 )

# --- 7) Unicode-aware line breaks & words -------------------------------------
my $text = "alpha\x{2028}beta\n\rgamma";
my @lines = split /\R/, $text;              # any Unicode line break
for (@lines) { s/\A\p{Zs}+|\p{Zs}+\z//g }   # trim Unicode spaces
```

---

## Notes

* The backtracking killers (atomic groups & possessive quantifiers) are your safety valves for hairy patterns.
* `\G` + `/g` is great for stateful scans where fields alternate forms.
* Keep regexes readable: comment with `/x` and break lines when they get dense.

---

```yaml
---
id: docs/perl/110-regex-cookbook.pl.md
lang: perl
platform: posix
scope: regex
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, regex, named-captures, K-operator, atomic, possessive, branch-reset, conditional, G-anchor, unicode]
description: "Practical regex patterns plus advanced tools: \\K, atomic/possessive, branch-reset groups, conditionals, and \\G scanning."
---
```