###### Perl

# Process Control & Shelling Out: `IPC::Run`, `open3`, Exit Codes, Timeouts

Run external commands safely, capture stdout/stderr, and avoid shell-injection foot-guns.

## TL;DR

* Prefer **list form** (`system @cmd`) to avoid shell interpolation.
* For capturing stdout/stderr—use `IPC::Run` (simpler) or `open3` (sharp knives).
* Always check exit codes (`$? >> 8`) and handle timeouts.
* Don’t compose commands with user input—pass argv parts as separate list elements.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));

# --- 1) Just run a command safely ---------------------------------------------
sub run_cmd (@cmd) {
    system @cmd;
    my $rc = $? >> 8;
    $rc == 0 or die "cmd failed rc=$rc: @cmd";
}

# --- 2) Capture stdout/stderr with IPC::Run -----------------------------------
use IPC::Run qw(run timeout);

sub capture_cmd (@cmd) {
    my ($in, $out, $err) = ('', '', '');
    my $ok = run \@cmd, \$in, \$out, \$err, timeout(10);   # 10s
    $ok or die "cmd failed rc=" . ($? >> 8) . " err=$err";
    return ($out, $err);
}

# Example:
# my ($out,$err) = capture_cmd(qw/awk -F, {print $1} data.csv/);

# --- 3) Pipelining with IPC::Run ----------------------------------------------
sub capture_pipeline () {
    my ($out,$err) = ('','');
    # Equivalent to: printf 'foo\nbar' | grep foo
    my $ok = run [qw/printf foo\nbar/], '|', [qw/grep foo/], '>', \$out, '2>', \$err, timeout(5);
    $ok or die "pipeline failed: $err";
    return $out;
}

# --- 4) open3 (advanced; mind the dragons) ------------------------------------
use IPC::Open3;
use Symbol 'gensym';

sub capture_open3 (@cmd) {
    my $err = gensym;
    my $pid = open3(undef, my $out, $err, @cmd);  # no stdin
    my $stdout = do { local $/; <$out> };
    my $stderr = do { local $/; <$err> };
    waitpid $pid, 0;
    my $rc = $? >> 8;
    $rc == 0 or die "open3 rc=$rc stderr=$stderr";
    return ($stdout, $stderr);
}

# --- 5) Environment and cwd control -------------------------------------------
sub run_in_env ($cwd, $env_ref, @cmd) {
    local %ENV = (%ENV, %{$env_ref // {}});
    local $ENV{LC_ALL} = 'C';
    local $/;                        # no effect here, just std advice
    local *_ = \*_;
    require Cwd; my $old = Cwd::getcwd();
    chdir $cwd or die "chdir $cwd: $!";
    system @cmd; my $rc = $? >> 8;
    chdir $old or warn "chdir back failed: $!";
    $rc == 0 or die "cmd failed rc=$rc: @cmd";
}
```

---

## Notes

* `system "cmd $user_input"` is unsafe—**never** pass untrusted strings to the shell. Use list form: `system 'cmd', $user_input`.
* `IPC::Run` is friendlier for pipelines and timeouts; `open3` gives control but is easy to misuse.
* Always surface stderr in error messages; your future self will thank you.

---

```yaml
---
id: docs/perl/80-process-control-ipc-run-open3.pl.md
lang: perl
platform: posix
scope: processes
since: "v0.1"
tested_on: "perl 5.36, IPC::Run 2023.x"
tags: [perl, processes, ipc-run, open3, stdout, stderr, timeout, security]
description: "Safe external command execution: list-form system, IPC::Run capture/pipelines/timeouts, and open3 with cautions."
---
```