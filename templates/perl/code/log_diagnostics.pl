#!/usr/bin/env perl
use v5.34;
use strict;
use warnings;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use utf8;
use open qw(:std :encoding(UTF-8));
use Try::Tiny;
use Time::Piece;

# --- Minimal logger ------------------------------------------------------------
sub _ts    { gmtime->strftime('%Y-%m-%dT%H:%M:%SZ') }
sub _lno   { (caller(1))[2] // 0 }
sub _func  { (caller(1))[3] // 'main' }
sub _log ($level, $msg) {
    printf STDERR "%s %-5s pid=%d line=%d fn=%s %s\n", _ts(), $level, $$, _lno(), _func(), $msg;
}
sub log_debug ($m){ $ENV{DEBUG} and _log('DEBUG', $m) }
sub log_info  ($m){ _log('INFO',  $m) }
sub log_warn  ($m){ _log('WARN',  $m) }
sub log_error ($m){ _log('ERROR', $m) }

# --- Log::Any variant ----------------------------------------------------------
# use Log::Any qw($log);
# use Log::Any::Adapter ('Stdout'); # or 'Stderr'
# $log->infof('rows=%d', $rows);

# --- Pretty data inspect -------------------------------------------------------
# cpanm Data::Printer
# use Data::Printer; p($data);

# --- Error with stack ----------------------------------------------------------
sub risky { die 'boom at work' }
my $rc = 0;
try {
    risky();
    $rc = 0;
}
catch {
    my $err = $_;
    chomp $err;
    require Devel::StackTrace;
    my $st = Devel::StackTrace->new(
        #ignore_package => [qw(Try::Tiny)],  # optional: hide Try::Tiny frames
        no_args        => 1,                # ← don’t print ('...^J') args
    );
    log_error("FAIL: $err");
    warn $st->as_string;  # goes to STDERR
    $rc = 1;
};
exit $rc;