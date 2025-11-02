###### Perl

# DBI + Postgres: Safe Connect, Placeholders, Transactions, Light Reconnect

Clean DB access with parameterized queries, explicit transactions, UTF-8 handling, and a minimal reconnect/retry shim for transient errors.

## TL;DR

* Connect with `RaiseError=>1`, `AutoCommit=>1` for safety; turn off AutoCommit only inside transactions.
* Always use placeholders (`?`); no string interpolation.
* Use `begin_work`/`commit`/`rollback` with a `try/catch`.
* For transient failures (network, deadlocks), a tiny `with_db_retry` helps—don’t mask logic errors.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));
use DBI;
use Try::Tiny;
use Time::HiRes qw(usleep);

# --- DSN examples --------------------------------------------------------------
# my $dsn = "dbi:Pg:dbname=mydb;host=127.0.0.1;port=5432";
# my ($user,$pass) = @ENV{qw(DB_USER DB_PASS)};

sub connect_pg ($dsn,$user,$pass) {
    return DBI->connect($dsn, $user, $pass, {
        RaiseError   => 1,
        PrintError   => 0,
        AutoCommit   => 1,
        pg_enable_utf8 => 1,   # DBD::Pg: decode text to Perl's internal utf8
    });
}

# --- Basic read ---------------------------------------------------------------
sub fetch_payments ($dbh, $min_id) {
    my $sth = $dbh->prepare('SELECT id, name, amount FROM payments WHERE id >= ? ORDER BY id');
    $sth->execute($min_id);
    my @rows;
    while (my $row = $sth->fetchrow_hashref) { push @rows, $row }
    return \@rows;
}

# --- Transactional write -------------------------------------------------------
sub insert_payment ($dbh, $name, $amount) {
    $dbh->begin_work;
    try {
        my $sth = $dbh->prepare('INSERT INTO payments(name, amount) VALUES (?, ?)');
        $sth->execute($name, $amount);
        $dbh->commit;
    }
    catch {
        my $e = $_; eval { $dbh->rollback };
        die $e;
    };
}

# --- Minimal retry for transient errors ---------------------------------------
# Retries on SQLSTATE classes: 08xxx (connection), 40P01 (deadlock), 40001 (serialization)
sub with_db_retry (&$$) {
    my ($code, $tries, $base_delay) = @_; my $delay = $base_delay // 0.1;
    for my $i (1..$tries) {
        my ($ok, $out) = eval { (1, $code->()) };
        return $out if $ok;
        my $err = $@ // '';
        my ($state) = $err =~ /SQLSTATE\[?([0-9A-Z]{5})\]?/ ? ($1) :
                      $err =~ /DBD::Pg::db .*? \((\w{5})\)/ ? ($1) : ();
        if (defined $state && ($state =~ /^08/ || $state eq '40P01' || $state eq '40001') && $i < $tries) {
            usleep int(($delay + rand($delay))*1_000_000); $delay *= 1.6; next
        }
        die $err;
    }
}

# Example usage:
# my $dbh = connect_pg($dsn,$user,$pass);
# my $rows = with_db_retry { fetch_payments($dbh, 1000) } 5, 0.1;
# with_db_retry { insert_payment($dbh, 'Ada', 42.00) } 5, 0.1;

# --- Bulk inserts efficiently --------------------------------------------------
sub bulk_insert_payments ($dbh, $rows) {
    $dbh->begin_work;
    try {
        my $sth = $dbh->prepare('INSERT INTO payments (name, amount) VALUES (?, ?)');
        for my $r (@$rows) { $sth->execute($r->{name}, $r->{amount}) }
        $dbh->commit;
    }
    catch {
        my $e = $_; eval { $dbh->rollback }; die $e;
    };
}

# --- Ping/reconnect example (lightweight) --------------------------------------
sub ensure_connected ($dbh_ref, $dsn,$user,$pass) {
    my $dbh = $$dbh_ref;
    if (!$dbh || !$dbh->ping) { $$dbh_ref = connect_pg($dsn,$user,$pass) }
}
```

---

## Notes

* `pg_enable_utf8 => 1` ensures text comes back decoded; match that with `use open` at the top.
* Use server-side prepared statements carefully; default DBI prepare/execute is fine for most CLIs.
* Keep retries narrow—SQLSTATE filtering prevents hiding real application errors.

---

```yaml
---
id: templates/perl/90-dbi-postgres-reconnect.pl.md
lang: perl
platform: posix
scope: db
since: "v0.1"
tested_on: "perl 5.36, DBI 1.643, DBD::Pg 3.x"
tags: [perl, dbi, postgres, transactions, placeholders, retry, sqlstate, utf8]
description: "DBI with Postgres: safe connect, UTF-8, parameterized queries, explicit transactions, and minimal transient retry."
---
```
