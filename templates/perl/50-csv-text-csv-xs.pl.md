###### Perl

# CSV/TSV Ingestion & Emission: `Text::CSV_XS` with Headers, Robust Options, and Streaming

Battle-tested CSV handling with `Text::CSV_XS`: safe parsing, header mapping, TSV variant, ND-style transforms, and reliable writing.

## TL;DR

* Use `Text::CSV_XS` with `binary=>1`, `auto_diag=>1`.
* Read header row once, map name→index; emit hashrefs for clarity.
* Stream large files; only slurp if bounded.
* For TSV, set `sep_char => "\t"`.
* When writing, set `eol => "\n"`; consider `always_quote => 1` for portability.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; 
use strict; 
use warnings; 
use utf8; 
use open qw(:std :encoding(UTF-8));
use Text::CSV_XS;          # cpanm Text::CSV_XS

# --- Create a CSV parser -------------------------------------------------------
my $csv = Text::CSV_XS->new({
    binary       => 1,        # allow any byte; avoids choking on 8-bit
    auto_diag    => 1,        # warn on malformed rows
    allow_loose_quotes  => 1, # pragmatic for messy exports
    allow_loose_escapes => 1,
    blank_is_undef      => 0, # empty string stays empty
}) or die "Cannot use CSV: " . Text::CSV_XS->error_diag;

# --- Read with header mapping --------------------------------------------------
sub read_csv_with_header ($path, $cb) {
    open my $fh, '<', $path or die "open $path: $!";

    my $hdr = $csv->getline($fh) // die "missing header in $path";
    my %ix  = map { $hdr->[$_] => $_ } 0..$#$hdr;  # name -> index

    # Optional: normalize headers
    # my %norm = map { (lc($_) =~ s/\W+/_/gr) => $ix{$_} } keys %ix; %ix = %norm;

    while (my $row = $csv->getline($fh)) {
        my %h; 
        @h{@$hdr} = @$row;     # array -> hash by header
        $cb->(\%h, \%ix);
    }
    close $fh or die "close $path: $!";
}

# Example:
# read_csv_with_header('in.csv', sub ($r, $ix) {
#   next unless ($r->{status} // '') eq 'active';
#   say join(",", @{$r}{qw/id name email/});
# });

# --- TSV variant ---------------------------------------------------------------
sub make_tsv_parser() {
    return Text::CSV_XS->new({ sep_char => "\t", binary => 1, auto_diag => 1 });
}

# --- Write CSV safely ----------------------------------------------------------
sub write_csv_rows ($path, $header_aref, $rows_aref) {
    my $wcsv = Text::CSV_XS->new({ binary=>1, auto_diag=>1, eol=>"\n", always_quote=>0 });
    open my $fh, '>', $path or die "open $path: $!";
    $wcsv->print($fh, $header_aref);
    for my $r (@$rows_aref) {
        my @out = ref($r) eq 'HASH' ? @{$r}{@$header_aref} : @$r;
        $wcsv->print($fh, \@out);
    }
    close $fh or die "close $path: $!";
}

# Example:
# my @rows = (
#   { id=>1, name=>'Ada',   email=>'ada@example.org' },
#   { id=>2, name=>'Linus', email=>'linus@example.org' },
# );
# write_csv_rows('out.csv', [qw/id name email/], \@rows);

# --- Robust row iteration with error capture ----------------------------------
sub each_row ($path, $on_row, $on_error = undef) {
    open my $fh, '<', $path or die "open $path: $!";
    my $hdr = $csv->getline($fh) // die "missing header";
    my %ix = map { $hdr->[$_] => $_ } 0..$#$hdr;
    while (1) {
        my $row = $csv->getline($fh);
        last unless defined $row;
        if ($csv->status) {
            my %h; @h{@$hdr} = @$row;
            $on_row->(\%h, \%ix);
        } else {
            my $diag = $csv->error_diag;
            if ($on_error) { $on_error->($diag) } else { warn "CSV error: $diag\n" }
        }
    }
    close $fh;
}
```

---

## Notes

* `auto_diag` is your early-warning radar for malformed lines.
* Stream > slurp for anything non-trivial; keep memory flat.
* BOMs from Excel? If needed, strip `\x{FEFF}` from the first field on the header line.

---

```yaml
---
id: templates/perl/50-csv-text-csv-xs.pl.md
lang: perl
platform: posix
scope: io
since: "v0.1"
tested_on: "perl 5.36, Text::CSV_XS 1.54"
tags: [perl, csv, tsv, text-csv-xs, streaming, io]
description: "CSV/TSV ingestion with Text::CSV_XS, header mapping, streaming iteration, and safe writing."
---
```
