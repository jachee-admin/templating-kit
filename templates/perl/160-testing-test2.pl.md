###### Perl

# Testing: `Test2::V0` Basics, Subtests, Fixtures, Mocks, and CLI Tips

Lean, modern tests with `Test2::V0`: table-driven cases, subtests, temporary fixtures, mocking, and handy `prove` flags.

## TL;DR

* Use `Test2::V0` for a rich, modern assertion set.
* Prefer **table-driven** tests and **subtests** for clarity.
* Create **temp fixtures** with `File::Temp`; keep tests hermetic.
* Mock surgically with `Test2::Mock` (or environment injection).
* Run with `prove -lr t` (add `-j` for parallelism).

---

## Script

```perl
# t/basic.t
use v5.36;
use Test2::V0;                      # cpanm Test2::Suite
use File::Temp qw(tempdir tempfile);

# --- Unit under test (inline demo) --------------------------------------------
BEGIN {
    package Calc;
    use Exporter 'import';
    our @EXPORT_OK = qw(add div);
    sub add ($a,$b){ $a + $b }
    sub div ($a,$b){ die "division by zero" if !$b; $a / $b }
}

# --- Table-driven examples -----------------------------------------------------
my @cases = (
    [2,2,4],
    [1,-3,-2],
    [0,0,0],
);
subtest 'add' => sub {
    for my $c (@cases) {
        my ($a,$b,$want) = @$c;
        is Calc::add($a,$b), $want, "add($a,$b)=$want";
    }
    done_testing;
};

# --- Error path ----------------------------------------------------------------
like dies { Calc::div(1,0) }, qr/division by zero/, 'div by zero dies';
is Calc::div(4,2), 2, 'div ok';

# --- Temp fixtures -------------------------------------------------------------
subtest 'fixture' => sub {
    my $tmpd = tempdir(CLEANUP => 1);
    open my $fh, '>', "$tmpd/hello.txt" or die $!;
    print {$fh} "hi\n"; close $fh;
    ok -e "$tmpd/hello.txt", 'file created';
    done_testing;
};

# --- Mocking (method override) -------------------------------------------------
use Test2::Mock;
{
    my $m = Test2::Mock->new(
        class => 'Calc',
        override => [ add => sub ($a,$b){ 100 } ],
    );
    is Calc::add(9,9), 100, 'mocked add';
}

# --- Warnings capture ----------------------------------------------------------
like warning { warn "yikes\n" }, qr/yikes/, 'warning seen';

done_testing;
```

---

## Notes

* Run: `prove -lr t` (add `-j4` for parallel test jobs).
* For CLI tools, test end-to-end with `IPC::Run` to capture stdout/stderr/exit.
* Keep tests deterministic: fix time with `Test::MockTime` when needed.

---

```yaml
---
id: templates/perl/160-testing-test2.pl.md
lang: perl
platform: posix
scope: testing
since: "v0.1"
tested_on: "perl 5.36, Test2::Suite 0.000155"
tags: [perl, testing, test2, subtest, fixtures, mocks, prove]
description: "Modern testing with Test2::V0: subtests, table-driven cases, fixtures, mocking, and CLI tips."
---
```