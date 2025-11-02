###### Perl

# Concurrency: `Parallel::ForkManager`, `threads`, and `MCE` (Map-Reduce)

Exploit multiple cores safely. Fork-based is simplest; threads work but are heavier; MCE (Many-Core Engine) gives a high-level API like Python’s multiprocessing.

## TL;DR

* **ForkManager** is easiest for parallel tasks with limited slots.
* **threads** allow shared data but add complexity — avoid unless needed.
* **MCE** provides parallel map/grep/loop abstractions; efficient and clean.
* Always collect results via shared or synchronized channels.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings;

# --- 1) Parallel::ForkManager (fan-out) ---------------------------------------
use Parallel::ForkManager;
my @jobs = (1..10);
my $pm = Parallel::ForkManager->new(4);     # max 4 processes

for my $job (@jobs) {
    $pm->start and next;
    my $pid = $$;
    print "worker $pid processing job=$job\n";
    sleep rand(2);
    $pm->finish;
}
$pm->wait_all_children;
print "all jobs done\n";

# --- 2) threads (shared var demo) ---------------------------------------------
# cpanm threads threads::shared
use threads;
use threads::shared;

my @nums :shared;   # shareable data structure
my @thr = map {
    threads->create(sub {
        my $id = $_;
        push @nums, $id * 2;
    }, $_);
} 1..5;
$_->join for @thr;
print "nums=@nums\n";

# --- 3) MCE (map/grep style) --------------------------------------------------
# cpanm MCE
use MCE::Loop;
my @squares = mce_map { $_ * $_ } 1..10;
say join(',', @squares);
```

---

## Notes

* `Parallel::ForkManager` avoids race conditions by design—no shared memory.
* When sharing data, prefer message passing or queue files.
* MCE’s `mce_map` is drop-in compatible with `map`; its `max_workers` param controls parallelism.

---

```yaml
---
id: templates/perl/140-concurrency.pl.md
lang: perl
platform: posix
scope: concurrency
since: "v0.1"
tested_on: "perl 5.36, MCE 1.9"
tags: [perl, concurrency, forkmanager, threads, mce, parallel, multiprocessing]
description: "Concurrent Perl patterns with ForkManager, threads, and MCE; fan-out, shared data, and map/grep abstractions."
---
```