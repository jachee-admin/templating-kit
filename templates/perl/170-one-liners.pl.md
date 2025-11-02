###### Perl

# One-Liners You’ll Actually Reuse: Text, JSON, CSV, Timestamps, Files

Tight, practical Perl one-liners with flags explained. Use these as muscle memory.

## TL;DR

* `-n` loop; `-p` loop+print; `-l` auto-chomp/newlines; `-a` autosplit to `@F`; `-F` splitter.
* Use `-MModule` to pull helpers (e.g., JSON).
* Prefer quoting that survives shells (`\'` inside single quotes).

---

## Script

```bash
# --- Text & grep-ish -----------------------------------------------------------
# Show lines with 'todo' and their numbers
perl -lne 'print "$.: $_" if /todo/' file.txt

# Replace in-place w/ backup
perl -i.bak -pe 's/foo/bar/g' *.txt

# Deduplicate lines (preserve order)
perl -lne 'print if !$seen{$_}++' file.txt

# Extract fields 1 and 3 (space-delimited)
perl -lane 'print join("\t", @F[0,2])' file.txt

# --- JSON (requires JSON::MaybeXS) --------------------------------------------
# Pretty-print JSON
perl -MJSON::MaybeXS -0777 -ne 'print JSON->new->pretty->canonical->encode(JSON->new->decode($_))' data.json

# Filter NDJSON by key
perl -MJSON::MaybeXS -ne 'my $o=decode_json($_); print if $o->{lvl} && $o->{lvl} eq "ERROR"' logs.ndjson

# Transform NDJSON (pick keys)
perl -MJSON::MaybeXS -ne 'my $o=decode_json($_); print encode_json({ts=>$o->{ts},msg=>$o->{msg}}),"\n"' in.ndjson

# --- CSV (Text::CSV_XS) --------------------------------------------------------
# Sum column 3 (0-based @F via -a with comma split)
perl -MText::CSV_XS -F, -lane '$s+=$F[2]; END{print $s}' data.csv

# Convert CSV -> TSV
perl -MText::CSV_XS -F, -lane 'print join("\t",@F)' data.csv

# --- Timestamps ----------------------------------------------------------------
# Print current ISO8601 UTC
perl -MPOSIX -e 'print strftime("%Y-%m-%dT%H:%M:%SZ", gmtime),"\n"'

# Convert epoch->ISO
perl -MPOSIX -e '$e=shift//time; print strftime("%Y-%m-%d %H:%M:%S", gmtime($e)),"\n"' 1700000000

# --- Filesystem ----------------------------------------------------------------
# Recursively list files with size
find . -type f -print0 | perl -MFile::stat -0nE '($s)=stat; say "$_ ".($s? $s->size:0)'

# Bulk rename: spaces -> underscores (preview)
find . -type f -print0 | perl -0nE '$n=$_; $n=~s/\s+/_/g; say "$_ -> $n"'

# --- Net / HTTP (HTTP::Tiny) ---------------------------------------------------
perl -MHTTP::Tiny -E '$r=HTTP::Tiny->new->get(shift); say $r->{status}; say $r->{content}' https://example.com

# --- Regex debugging -----------------------------------------------------------
# Show only the part after first ERROR (using \K)
perl -pe 's/.*?ERROR\K\s*//' logfile.txt
```

---

## Notes

* `-0777` slurps whole file into `$_` (great for JSON pretty).
* `-E` enables `say` and `state`; `-n/-p` don’t play with `-e`’s multiple programs unless you know what you’re doing.
* Always keep backups when doing `-i` edits on critical data.

---

```yaml
---
id: templates/perl/170-one-liners.pl.md
lang: perl
platform: posix
scope: cli
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, one-liners, json, csv, timestamps, filesystem, http]
description: "Field-tested one-liners for text, JSON, CSV, timestamps, filesystem tasks, and HTTP."
---
```

