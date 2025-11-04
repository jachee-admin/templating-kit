#!/usr/bin/env perl
use v5.34;
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use feature 'signatures';
no warnings 'experimental::signatures';

# --- 1) Quick timestamps with Time::Piece -------------------------------------
use Time::Piece;
my $now_local = localtime;                   # object
my $now_utc   = gmtime;

say $now_utc->strftime('%Y-%m-%dT%H:%M:%SZ');     # ISO-8601-ish UTC
say $now_local->strftime('%Y-%m-%d %H:%M:%S %z'); # local with numeric offset

# Parse ISO string (naive; assumes UTC if 'Z'):
my $t = Time::Piece->strptime('2025-10-31T23:59:00Z', '%Y-%m-%dT%H:%M:%SZ');
say $t + 3600;  # arithmetic works

# --- 2) Real time zone math with DateTime -------------------------------------
# cpanm DateTime DateTime::Format::ISO8601
use DateTime;
use DateTime::Format::ISO8601;

my $dt = DateTime->now( time_zone => 'UTC' );
my $eastern = $dt->clone->set_time_zone('America/New_York');
say $eastern->strftime('%Y-%m-%dT%H:%M:%S %Z'); # => EDT/EST

# Parse arbitrary ISO8601
my $p = DateTime::Format::ISO8601->parse_datetime('2025-11-01T18:45:03+01:00');
$p->set_time_zone('UTC');
say $p->iso8601 . 'Z';

# Durations / intervals
my $start = DateTime->new(year=>2025,month=>11,day=>1, hour=>10, time_zone=>'UTC');
my $end   = $start->clone->add( hours => 36, minutes => 15 );
my $dur   = $end->subtract_datetime($start);
say sprintf "elapsed: %d days %d hours %d min", $dur->in_units(qw(days hours minutes));

# --- 3) Monotonic timing (don’t use wall clock) -------------------------------
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC time sleep);

my $t0 = clock_gettime(CLOCK_MONOTONIC);
# ... work ...
sleep 1;
my $t1 = clock_gettime(CLOCK_MONOTONIC);
say sprintf "monotonic elapsed=%.6f s", $t1 - $t0;

# --- 4) Micro-bench small code blocks -----------------------------------------
use Time::HiRes qw(gettimeofday tv_interval);

my $t0v = [gettimeofday];
# ... hot path ...
my $ms = 1000 * tv_interval($t0v, [gettimeofday]);
say sprintf "hot path: %.3f ms", $ms;

# --- 5) Safe ISO helpers -------------------------------------------------------
sub iso_utc_now     () { gmtime->strftime('%Y-%m-%dT%H:%M:%SZ') }
sub iso_local_now   () { localtime->strftime('%Y-%m-%dT%H:%M:%S%z') }
sub iso_from_epoch  ($epoch) { gmtime($epoch)->strftime('%Y-%m-%dT%H:%M:%SZ') }

say iso_utc_now();