#!/usr/bin/env perl
use v5.34;
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use autodie;


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