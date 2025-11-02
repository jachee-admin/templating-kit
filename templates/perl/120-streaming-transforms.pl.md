###### Perl

# Streaming Transforms & Log Parsing: Line Loops, Windows, State Machines, Live Tails

Process big streams without blowing RAM, keep latency low, and parse flexible key/value logs like a pro.

## TL;DR

* For classic pipelines, `while (<>) { ... }` with chomp + guards is king.
* Maintain rolling stats with a fixed-size window; don’t accumulate forever.
* Use small state machines for multi-line entries (stack traces, JSON blobs).
* For live files, `File::Tail` is simple; for async sockets, consider `IO::Async`.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));

# --- 1) Canonical streaming loop ----------------------------------------------
while (my $line = <STDIN>) {
    next if $line =~ /^\s*(?:#|$)/;     # skip comments/blanks fast
    chomp $line;
    $line =~ s/\s+/ /g;                 # normalize whitespace
    print $line, "\n";                  # stdout is data; logs -> STDERR
}

# --- 2) Rolling window (fixed memory) -----------------------------------------
# Moving average over last N numeric samples
{
    my $N = 1000; my @win; my $sum = 0;
    while (my $line = <>) {
        next unless $line =~ /(-?\d+(?:\.\d+)?)/;
        my $x = 0 + $1;
        push @win, $x; $sum += $x;
        if (@win > $N) { $sum -= shift @win }
        printf "%.6f\n", $sum / @win;
    }
}

# --- 3) Key/Value log parsing (quoted strings) --------------------------------
# Parse: lvl=INFO ts=... msg="hello world" user=john
sub parse_kv ($s) {
    my %h;
    while ($s =~ /\G\s*(?:(\w+)="([^"]*)"|(\w+)=([^\s"]+))/gc) {
        if (defined $1) { $h{$1} = $2 } else { $h{$3} = $4 }
    }
    return \%h;
}
# Example: my $h = parse_kv('lvl=INFO msg="something odd" x=1');

# --- 4) Multiline entry state machine -----------------------------------------
# Join stack traces until a blank line; emit as one record
sub read_blocks {
    my @block;
    while (defined(my $l = <>)) {
        chomp $l;
        if ($l =~ /\S/) { push @block, $l; next }
        if (@block) { print join("\\n", @block), "\n---\n"; @block = () }
    }
    print join("\\n", @block), "\n" if @block;
}

# --- 5) Live tail with File::Tail (simple) ------------------------------------
# cpanm File::Tail
# use File::Tail;
# my $tail = File::Tail->new(name => '/var/log/app.log', interval => 1, tail => -0);
# while (defined(my $l = $tail->read)) {
#     chomp $l;
#     my $h = parse_kv($l);
#     print $h->{msg} // $l, "\n";
# }

# --- 6) NDJSON transform pipeline ---------------------------------------------
# Convert mixed logs -> NDJSON (keep keys we care about)
use JSON::MaybeXS qw(encode_json);
while (my $l = <STDIN>) {
    chomp $l; next if $l =~ /^\s*$/;
    my $h = parse_kv($l);
    my %out = (
        lvl => $h->{lvl} // 'INFO',
        msg => $h->{msg} // $l,
        ts  => $h->{ts}  // undef,
    );
    print encode_json(\%out), "\n";
}
```

---

## Notes

* Keep stdout for data and STDERR for diagnostics—lets you `| jq` or `| tee` cleanly.
* When joining multiline blocks, set a clear delimiter so downstream tools can split reliably.
* For very high throughput, consider buffering writes (print to a scalar, flush periodically).

---

```yaml
---
id: templates/perl/120-streaming-transforms.pl.md
lang: perl
platform: posix
scope: streaming
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, streaming, pipelines, windows, kv-logs, state-machine, ndjson, file-tail]
description: "Low-memory streaming transforms: canonical line loop, rolling windows, KV log parsing, multiline state machine, live tail, and NDJSON emit."
---
```
