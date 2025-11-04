#!/usr/bin/env perl
use v5.34;
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use feature qw(signatures);
no warnings 'experimental::signatures';

use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Time::HiRes qw(time);
use Try::Tiny;
use Log::Log4perl qw(get_logger :levels);

# --- CLI options --------------------------------------------------------------
my %opt = (
    verbose   => 0,
    dryrun    => 0,
    log_level => 'INFO',      # TRACE|DEBUG|INFO|WARN|ERROR|FATAL
    log_file  => '',          # empty = stdout/stderr
    log_json  => 0,           # 1 = JSON layout if available
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

# --- Logger init --------------------------------------------------------------
sub _l4p_level ($name) {
    my %map = (
        TRACE => $TRACE, DEBUG => $DEBUG, INFO => $INFO,
        WARN  => $WARN,  ERROR => $ERROR, FATAL => $FATAL,
    );
    return $map{ uc($name // 'INFO') } // $INFO;
}

sub _init_logger (%o) {
    my $level_name = uc($o{log_level} // 'INFO');
    my $level_num  = _l4p_level($level_name);

    # Prefer JSON layout if requested and available; otherwise use PatternLayout.
    my $have_json = 0;
    if ($o{log_json}) {
        eval { require Log::Log4perl::Layout::JSON; $have_json = 1 };
    }

    my $layout = $have_json
        ? q{log4perl.appender.A1.layout = Log::Log4perl::Layout::JSON}
        : q{log4perl.appender.A1.layout = PatternLayout
            log4perl.appender.A1.layout.ConversionPattern = %d{yyyy-MM-dd'T'HH:mm:ss} %5p pid=%P file=%F line=%L fn=%M %m%n
          };

    # Appender to file or to screen
    my $appender = $o{log_file}
        ? qq{
              log4perl.appender.A1 = Log::Log4perl::Appender::File
              log4perl.appender.A1.filename = $o{log_file}
              log4perl.appender.A1.mode = append
           }
        : q{
              log4perl.appender.A1 = Log::Log4perl::Appender::Screen
              log4perl.appender.A1.stderr = 1
           };

    my $conf = <<"CONF";
log4perl.rootLogger = $level_name, A1
$appender
$layout
CONF

    Log::Log4perl->init( \$conf );
    my $log = get_logger();

    # Honor -v/-vv: n bumps DEBUG/TRACE regardless of --log-level (but don't lower below TRACE)
    if ($o{verbose} >= 2) { $log->level($TRACE) }
    elsif ($o{verbose} == 1 && $level_num > $DEBUG) { $log->level($DEBUG) }

    return $log;
}

my $LOG = _init_logger(%opt);

# --- Helpers ------------------------------------------------------------------
sub _q ($s) { $s eq '' ? "''" : do { (my $t=$s) =~ s/'/'"'"'/g; "'$t'"} }

sub run (@cmd) {
    my $shown = join ' ', map { _q($_) } @cmd;
    $LOG->info("+ $shown");

    if ($opt{dryrun}) {
        $LOG->debug("dry-run: skipping exec");
        return 1;
    }

    system @cmd;
    my $st = $?;
    return 1 if $st == 0;

    if ($st == -1) { die "failed to execute: $shown: $!" }
    if ($st & 127) {
        my $sig = ($st & 127);
        die sprintf "command died with signal %d: %s", $sig, $shown;
    }
    my $rc = $st >> 8;
    die "command failed rc=$rc: $shown";
}

# --- Main ---------------------------------------------------------------------
sub main() {
    my $t0 = time();
    $LOG->info(sprintf "Starting (dryrun=%d, verbose=%d, level=%s)",
               @opt{qw(dryrun verbose log_level)});

    # Example side-effect
    run 'echo', 'Hello, Log4perl';

    $LOG->info(sprintf "Done in %.3fs", time() - $t0);
    return 0;
}

# --- Guarded execution --------------------------------------------------------
my $exit = 0;
try   { $exit = main() }
catch {
    my $err = $_ // 'unknown'; $err =~ s/\s+\z//;
    $LOG->error("Unhandled: $err");
    $exit = 1;
};
exit $exit;

__END__

=head1 NAME
cli-skeleton-log4perl - strict CLI with Log::Log4perl logging

=head1 SYNOPSIS
cli-skeleton-log4perl [--log-level INFO|DEBUG|TRACE] [--log-file path] [--log-json] [-n] [-v|-vv]

=head1 DESCRIPTION
Skeleton for disciplined Perl CLIs using Log::Log4perl for structured logging.
