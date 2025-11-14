###### Perl

# Binary Parsing: `pack`/`unpack`, Endianness, Bitfields, Hexdump, Checksums

Parse binary protocols and file formats safely with clear templates and correct byte order.

## TL;DR

* `unpack` with templates like `N` (uint32 BE), `V` (uint32 LE), `n`/`v` (uint16), `C` (byte).
* Read exact lengths; check short reads.
* For bitfields, unpack to integers then mask/shift.
* Use `Digest::CRC`/`Digest::SHA` for checksums.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use open qw(:std :encoding(UTF-8));

# --- Helpers -------------------------------------------------------------------
sub read_exact ($fh, $len) {
    my $buf = '';
    my $n = read($fh, $buf, $len);
    die "short read: want=$len got=".($n//0) unless defined $n && $n == $len;
    return $buf;
}

# --- Example: length-prefixed blob (u32 BE) -----------------------------------
open my $fh, '<:raw', 'input.bin' or die $!;
my $hdr  = read_exact($fh, 4);
my $len  = unpack('N', $hdr);           # big-endian uint32
my $blob = read_exact($fh, $len);

# --- Example: struct parsing ---------------------------------------------------
# struct Packet { u16 type_be; u16 flags_le; u32 ts_be; u8 ver; u8 pad; u16 len_le; }
my $pkt_raw = read_exact($fh, 2+2+4+1+1+2);
my ($type_be, $flags_le, $ts_be, $ver, $pad, $len_le) = unpack('n v N C C v', $pkt_raw);

# --- Bitfields -----------------------------------------------------------------
# Suppose flags_le bit layout: 0=ACK,1=SYN,2=FIN
my $ACK = $flags_le & 0x0001;
my $SYN = ($flags_le >> 1) & 0x1;
my $FIN = ($flags_le >> 2) & 0x1;

# --- Hexdump (quick) -----------------------------------------------------------
sub hexdump ($bytes) {
    my $hex = unpack('H*', $bytes);
    $hex =~ s/(..)/$1 /g;
    return $hex;
}
# say hexdump($blob);

# --- Checksums -----------------------------------------------------------------
# cpanm Digest::SHA Digest::CRC
use Digest::SHA qw(sha256_hex);
use Digest::CRC qw(crc32);

my $sha = sha256_hex($blob);
my $crc = crc32($blob);

# --- Writing binary data -------------------------------------------------------
# Compose the same Packet with different values
my $out = pack('n v N C C v', 0x1001, 0b0000_0011, time, 1, 0, length($blob));
open my $o, '>:raw', 'out.bin' or die $!; print {$o} $out, $blob; close $o;

# --- Safety: bounds for variable-length fields --------------------------------
# Always check that $len does not exceed file size/limits before read_exact().
```

---

## Notes

* Use `:raw` layer on filehandles for binary I/O (no newline translation).
* Document your `pack`/`unpack` templates inline; future you will forget.
* Sanity-check lengths before allocating buffers; guard against malicious inputs.

---

```yaml
---
id: docs/perl/180-binary-pack-unpack.pl.md
lang: perl
platform: posix
scope: binary
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, binary, pack, unpack, endian, bitfields, hexdump, checksum]
description: "Binary parsing/writing with pack/unpack templates, endianness, bitfields, hexdump, and checksums."
---
```
