###### Perl

# Resilient File I/O: UTF-8 Everywhere, Streaming, Safe Slurp, In-Place Edit

Handle text safely, avoid memory face-plants, and don’t corrupt files when editing.

## TL;DR

* At top of script: `use utf8; use open qw(:std :encoding(UTF-8));`
* Stream lines for large inputs; only slurp when bounded and checked.
* Guard slurp by size, and verify open returns.
* For edits, write to a temp file and move it over the original.

---

## Script

```perl
#!/usr/bin/env perl
use v5.34;
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# --- Streaming read ------------------------------------------------------------
sub stream_file ($path, $cb) {
    open my $fh, '<', $path or die "open $path: $!";
    while (my $line = <$fh>) {
        next if $line =~ /^\s*#/;
        chomp $line;
        $cb->($line);
    }
    close $fh or die "close $path: $!";
}

# Example usage:
# stream_file('data.txt', sub ($line) { say uc $line });

# --- Safe slurp with size guard ------------------------------------------------
sub slurp_safely ($path, $max_mb = 50) {
    my $size = -s $path // 0;
    die "file too large ($size bytes): $path" if $size > $max_mb * 1024 * 1024;
    open my $fh, '<', $path or die "open $path: $!";
    local $/; my $all = <$fh>;
    close $fh or die "close $path: $!";
    return $all;
}

# --- In-place edit via temp + rename ------------------------------------------
use File::Copy qw(move);
use File::Temp qw(tempfile);
sub inplace_edit ($path, $edit_cb) {
    my ($fh, $tmp) = tempfile(UNLINK => 0, SUFFIX => '.tmp', DIR => '.');
    open my $in, '<', $path or die "open $path: $!";
    while (my $line = <$in>) {
        $line = $edit_cb->($line);
        print {$fh} $line;
    }
    close $in;
    close $fh or die "close $tmp: $!";
    move $tmp, $path or die "rename $tmp -> $path: $!";
}

# Example: s/foo/bar/g
# inplace_edit('file.txt', sub ($line) { $line =~ s/foo/bar/g; return $line });

# --- Path::Tiny quality of life (optional) ------------------------------------
# cpanm Path::Tiny
# use Path::Tiny;
# my $text = path('data.txt')->slurp_utf8;
# path('out.txt')->spew_utf8($text);
```

---

## Notes

* Use **streaming** when unsure about file size; prefer callbacks for transform logic.
* `File::Temp` + `move` avoids partial writes killing your original file.
* `Path::Tiny` is a joy; just stick to its `_utf8` helpers to keep encoding explicit.

---

```yaml
---
id: docs/perl/40-file-io-utf8-resilient.pl.md
lang: perl
platform: posix
scope: io
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, utf8, file-io, streaming, slurp, path-tiny]
description: "UTF-8 defaults, streaming pattern, bounded slurp, and safe in-place edits."
---
```
