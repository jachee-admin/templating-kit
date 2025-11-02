###### Perl

# JSON & YAML: `JSON::MaybeXS`/`Cpanel::JSON::XS`, YAML read/write, and NDJSON

Reliable JSON/YAML handling with proper UTF-8, pretty/canonical output for diffs, and newline-delimited JSON for streaming pipelines.

## TL;DR

* Prefer `JSON::MaybeXS` (fastest available backend), set `canonical`, `pretty`, `utf8`.
* Decode at the edges; pass Perl data structures around internally.
* `YAML::XS` is fast but don’t `Load` untrusted input; YAML can instantiate objects.
* For pipelines, use **NDJSON**: one JSON object per line.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));
use JSON::MaybeXS qw(encode_json decode_json);   # cpanm JSON::MaybeXS
use YAML::XS qw(Load Dump);                      # cpanm YAML::XS

# --- JSON read/write (files) ---------------------------------------------------
sub read_json ($path) {
    open my $fh, '<', $path or die "open $path: $!";
    local $/; my $txt = <$fh>; close $fh;
    return decode_json($txt);   # HASH/ARRAY ref
}

sub write_json ($path, $data) {
    my $json = JSON::MaybeXS->new->utf8->canonical->pretty->allow_nonref;
    open my $fh, '>', $path or die "open $path: $!";
    print {$fh} $json->encode($data);
    close $fh or die "close $path: $!";
}

# Example:
# my $cfg = read_json('config.json');
# $cfg->{enabled} = \1;  # boolean true
# write_json('config.pretty.json', $cfg);

# --- NDJSON (newline-delimited JSON) ------------------------------------------
sub ndjson_stream_read ($path, $cb) {
    open my $fh, '<', $path or die "open $path: $!";
    while (my $line = <$fh>) {
        next unless length $line; chomp $line;
        next if $line =~ /^\s*(?:#|$)/;     # skip blanks/comments
        my $obj = decode_json($line);
        $cb->($obj);
    }
    close $fh;
}

sub ndjson_stream_write ($path, $it) {
    my $json = JSON::MaybeXS->new->utf8->canonical->allow_nonref;
    open my $fh, '>', $path or die "open $path: $!";
    while (my $obj = $it->()) {           # iterator returns undef to stop
        print {$fh} $json->encode($obj), "\n";
    }
    close $fh;
}

# --- YAML read/write -----------------------------------------------------------
sub read_yaml ($path) {
    open my $fh, '<', $path or die "open $path: $!";
    local $/; my $txt = <$fh>; close $fh;
    return Load($txt);          # returns ref
}

sub write_yaml ($path, $data) {
    open my $fh, '>', $path or die "open $path: $!";
    print {$fh} Dump($data);
    close $fh or die "close $path: $!";
}

# --- JSON<->YAML conversion helpers -------------------------------------------
sub json_to_yaml ($in, $out) { write_yaml($out, read_json($in)) }
sub yaml_to_json ($in, $out) { write_json($out, read_yaml($in)) }

# --- Pretty print to STDOUT (for CLI use) -------------------------------------
sub print_json_pretty ($data) {
    my $json = JSON::MaybeXS->new->utf8->canonical->pretty->allow_nonref;
    print $json->encode($data), "\n";
}
```

---

## Notes

* `canonical` stabilizes key order—critical for test diffs and Git noise reduction.
* JSON booleans are special scalars (`\1`/`\0`); avoid accidental stringification.
* For safer YAML on untrusted input, use `YAML::PP` with a strict schema.

---

```yaml
---
id: templates/perl/60-json-yaml.pl.md
lang: perl
platform: posix
scope: io
since: "v0.1"
tested_on: "perl 5.36, JSON::MaybeXS 1.006, YAML::XS 0.88"
tags: [perl, json, yaml, ndjson, pretty, canonical]
description: "JSON and YAML helpers: robust read/write, pretty+canonical output, and NDJSON streaming."
---
```
