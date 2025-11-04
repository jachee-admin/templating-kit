#!/usr/bin/env perl
use v5.34;
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use feature qw(signatures);
no warnings 'experimental::signatures';

use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage qw/pod2usage/;
use Time::HiRes qw(time);
use POSIX qw(strftime);
use Try::Tiny;

use Log::Any qw($log);
use Log::Any::Adapter;
use JSON::PP qw(encode_json);
use Data::Dumper qw(Dumper);

# --- CLI options --------------------------------------------------------------
my %opt = (
    verbose   => 0,
    dryrun    => 0,
    log_level => 'INFO',   # TRACE|DEBUG|INFO|WARN|ERROR|FATAL
    log_file  => '',       # empty => stderr
    log_json  => 0,        # structured JSON lines
);

GetOptions(
    'input|i=s'    => \$opt{input},
    'output|o=s'   => \$opt{output},
    'verbose|v+'   => \$opt{verbose},
    'dry-run|n'    => \$opt{dryrun},
    'log-level=s'  => \$opt{log_level},
    'log-file=s'   => \$opt{log_file},
    'log-json!'    => \$opt{log_json},
    'help|h'       => sub { pod2usage(-verbose => 1, -exitval => 0) },
) or pod2usage(2);
#say Dumper(\%opt);
#exit;
pod2usage(1);
exit;
# --- Logger init (Log::Any + adapter) -----------------------------------------
sub _init_logger (%o) {
    my $level = uc($o{log_level} // 'INFO');

    # -v bumps to DEBUG, -vv to TRACE (without changing --log-level)
    $level = 'DEBUG' if $o{verbose} >= 1 && $level !~ /^(DEBUG|TRACE)$/;
    $level = 'TRACE' if $o{verbose} >= 2;

    if ($o{log_file}) {
        Log::Any::Adapter->set('File',
            filename  => $o{log_file},
            mode      => 'append',
            log_level => $level,
        );
    } else {
        # Stderr by default
        Log::Any::Adapter->set('Stderr',
            log_level => $level,
        );
    }
}
_init_logger(%opt);

# --- Time & formatting ---------------------------------------------------------
sub _ts () { strftime('%Y-%m-%dT%H:%M:%SZ', gmtime) }

sub _shortsub ($s) { return 'main' unless defined $s; $s =~ s/^.*:://; $s }

sub _fmt_line ($level, $msg, $file, $line, $sub) {
    sprintf "%s %-5s pid=%d file=%s line=%d fn=%s %s",
        _ts(), $level, $$, ($file // '?'), ($line // 0), _shortsub($sub), $msg;
}

sub _emit ($level, $msg) {
    # caller(1): the immediate caller of _emit (i.e., log_* wrapper)
    my (undef, $file, $line, $sub) = caller(2);

    my $out = $opt{log_json}
        ? encode_json({
            ts   => _ts(),
            lvl  => $level,
            pid  => $$,
            file => $file // '?',
            line => $line // 0,
            fn   => _shortsub($sub),
            msg  => "$msg",
          })
        : _fmt_line($level, $msg, $file, $line, $sub);

    # dispatch based on Log::Any level
    my $m = lc $level;      # 'INFO' -> 'info'
    $log->$m($out);
}

# --- Human-friendly log wrappers ----------------------------------------------
sub log_trace ($m){ _emit('TRACE', $m) }
sub log_debug ($m){ _emit('DEBUG', $m) }
sub log_info  ($m){ _emit('INFO',  $m) }
sub log_warn  ($m){ _emit('WARN',  $m) }
sub log_error ($m){ _emit('ERROR', $m) }
sub log_fatal ($m){ _emit('FATAL', $m) }

# --- Command execution helper --------------------------------------------------
sub _q ($s) { $s eq '' ? "''" : do { (my $t=$s) =~ s/'/'"'"'/g; "'$t'"} }

sub run (@cmd) {
    my $shown = join ' ', map { _q($_) } @cmd;
    log_info("+ $shown");

    if ($opt{dryrun}) {
        log_debug("dry-run: skipping exec");
        return 1;
    }

    system @cmd;
    my $st = $?;
    return 1 if $st == 0;

    if ($st == -1) {
        die "failed to execute: $shown: $!";
    }
    if ($st & 127) {
        my $sig = ($st & 127);
        die sprintf "command died with signal %d: %s", $sig, $shown;
    }
    my $rc = $st >> 8;
    die "command failed rc=$rc: $shown";
}

# --- Main ----------------------------------------------------------------------
sub main() {
    my $t0 = time();
    log_info(sprintf "Starting (dryrun=%d, verbose=%d, level=%s)",
             @opt{qw(dryrun verbose log_level)});

    run 'echo', 'Hello, Log::Any';

    log_info(sprintf "Done in %.3fs", time() - $t0);
    return 0;
}

# --- Guarded execution ---------------------------------------------------------
my $exit = 0;
try   { $exit = main() }
catch {
    my $err = $_ // 'unknown'; $err =~ s/\s+\z//;
    log_error("Unhandled: $err");
    $exit = 1;
};
exit $exit;

__END__

=head1 NAME

cli-skeleton-logany - strict CLI skeleton with Log::Any

=head1 SYNOPSIS

cli-skeleton-logany [--log-level INFO|DEBUG|TRACE] [--log-file path] [--log-json] [-n] [-v|-vv]

=head1 DESCRIPTION

Skeleton for disciplined Perl CLIs using Log::Any for structured logging.
