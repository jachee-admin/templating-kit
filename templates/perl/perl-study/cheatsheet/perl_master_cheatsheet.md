# Perl — Master Cheat Sheet (Language‑Focused)

**For:** full‑stack engineers who want modern, production‑ready Perl 5.  
**Goal:** Practical language reference (syntax, context, regex, data structures, modules, CLI, testing, DB).

---

## 0) Boilerplate & Project Setup

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use feature qw(say);
# Optionally, on newer Perls:
use feature qw(signatures);
# on older Perls:
no warnings qw(experimental::signatures);

use utf8;                       # source is UTF‑8
binmode STDOUT, ':encoding(UTF-8)';
```

Install modules:

```bash
cpanm Moo Path::Tiny Try::Tiny JSON::PP DateTime DBI DBD::Pg Test2::V0
# Tooling
cpanm Devel::NYTProf Data::Printer
```

Manage Perl versions: **perlbrew** or **plenv**.

---

## 1) Scalars, Arrays, Hashes

```perl
my $s = "hello";     # scalar
my @a = (1, 2, 3);   # array
my %h = (k => 1);    # hash

# Access
$a[0]; $h{key};

# Slices
my @sub = @a[0,2];
my @keys = @h{qw/k/};

# Interpolation
my $name = 'Jen';
say "Hi $name, a[0]=$a[0]";
```

**Defined/exists:**

```perl
defined $x;          # has a value (even if falsey 0 or '')
exists $h{key};     # key present in hash (even if undef)
```

**Chomp** (remove trailing $/):

```perl
chomp(my $line = <STDIN>);
```

---

## 2) Context (Core Perl Idea)

- **Scalar context** → functions return a single value.  
- **List context** → functions return a list.  
- **Void context** → return value ignored.

```perl
my $n = localtime();      # scalar → string
my @t = localtime();      # list   → (sec,min,hour,...)

my ($first) = some_list();   # list on RHS, assign first
my $count = @a;              # scalar context → length
```

`wantarray` inside a sub tells you which context was requested.

---

## 3) Operators & Comparisons

- Numeric: `== != < <= > >=`  
- String:  `eq ne lt le gt ge`  
- Defined‑or: `//`, assignment `//=`  
- Boolean: `&& || !` (short‑circuit)  
- Concatenate: `.`

```perl
my $id = $h{id} // 'unknown';
```

---

## 4) References & Complex Data

```perl
my $aref = [1,2,3];          # array ref
my $href = {k => 1};         # hash ref

push @$aref, 4;
$href->{k} = 2;

# Deep structure
my $board = {
  id => 1,
  items => [ {type=>'text', val=>'Hi'}, {type=>'img', url=>'...'} ],
};
```

Dump for debug:

```perl
use Data::Dumper; say Dumper($board);
# or Data::Printer: use DDP; p $board;
```

---

## 5) Subs (with and without signatures)

```perl
sub add { my ($a, $b) = @_; return $a + $b; }

# With signatures (newer Perls; enable feature):
# sub add2 ($a, $b) { $a + $b }
```

**Parameters are aliases** to `@_` values → copy if you will modify:

```perl
sub bump_first {
  my ($x) = @_;      # copy to lexical
  $x++;
  return $x;
}
```

Return list or scalar based on context:

```perl
sub first_two { return @_[0,1] }   # list in list context; count in scalar
```

---

## 6) Regex Power (PCRE‑like, but Perl’s engine)

```perl
my $s = "Email me at foo@example.com";
if ($s =~ /(?<user>[\w.+-]+)@(?<host>[\w.-]+)/) {
  say "$+{user} on $+{host}";
}

# Substitution
$s =~ s/\s+/-/g;          # collapse spaces to dashes

# Modifiers: /i case, /m ^$ multi‑line, /s . matches \n, /x comments/spaces
# Non‑capturing (?: ), lookaround (?=...) (?!...) (?<=...) (?<!...)
# \K to keep left side out of match
"abc123" =~ s/.*\K\d+/***/;  # "abc***"
```

**Performance note:** Avoid `$&`, `$'`, `$`` (match vars) in hot paths—they can slow regex. Use named captures or `$1..$n` if needed.

Precompile:

```perl
my $re = qr/\bboard-(\d+)\b/;
if ($str =~ $re) { say $1 }
```

Global scan with position `\G`:

```perl
while ($s =~ /(\w+)/g) { say $1 }         # iterates tokens
```

---

## 7) Files & I/O

```perl
use autodie;
open my $fh, '<:encoding(UTF-8)', $file;
while (my $line = <$fh>) {
  chomp $line;
  ...
}
close $fh;
```

Slurp file:

```perl
my $all = do { local $/; open my $f,'<',$file; <$f> };
```

**Path utils:**

```perl
use Path::Tiny qw(path);
my $txt = path($file)->slurp_utf8;
path('out.txt')->spew_utf8("Hello\n");
```

---

## 8) JSON, Dates, CLI

```perl
use JSON::PP qw(encode_json decode_json);
my $json = encode_json($board);
my $obj  = decode_json($json);

use DateTime;
my $dt = DateTime->now; 
$dt->iso8601;

use Getopt::Long qw(GetOptions);
my $verbose = 0;
GetOptions("verbose!" => \$verbose);
```

---

## 8.5) Dates

**DateTime** (the canonical choice), then show when to reach for **DateTime::Format::Strptime**, **DateTime::Format::ISO8601**, **DateTime::Duration**, **Time::Piece** (core), and **Time::Moment** (fast/immutable). Copy-paste friendly.

---

# Date & Time in Perl — Practical Toolkit

## 1a) Create, inspect, format (DateTime)

```perl
use v5.32;
use DateTime;

my $utc = DateTime->now( time_zone => 'UTC' );   # explicit tz beats surprises
say $utc->iso8601();                              # 2025-10-23T14:37:05
say $utc->strftime('%Y-%m-%d %H:%M:%S %Z');       # 2025-10-23 14:37:05 UTC

# Specific date/time
my $dt = DateTime->new(
  year => 2025, month => 12, day => 31,
  hour => 23, minute => 59, second => 59,
  time_zone => 'America/New_York',
);
say $dt->day_name;    # Wednesday
say $dt->week_number; # ISO week
```

**Tip:** Always set `time_zone` explicitly. Default “floating” time is a foot-gun around DST.

---

## 2a) Parse strings → DateTime

Strict, reliable parsing is your friend.

**ISO 8601**

```perl
use DateTime::Format::ISO8601;
my $dt = DateTime::Format::ISO8601->parse_datetime('2025-10-23T09:12:33-04:00');
say $dt->time_zone->name;          # America/New_York (offset respected)
```

**Custom formats (Strptime)**

```perl
use DateTime::Format::Strptime;

my $fmt = DateTime::Format::Strptime->new(
  pattern   => '%d/%m/%Y %H:%M',
  time_zone => 'Europe/London',
  on_error  => 'croak',
);

my $dt = $fmt->parse_datetime('31/01/2025 08:30');
say $dt->iso8601(); # 2025-01-31T08:30:00
```

**Gotchas**

- Parsing without a zone assumes the formatter’s `time_zone`.

- Use `on_error => 'croak'` so bad input doesn’t quietly become `undef`.

---

## 3a) Time zones & conversion

```perl
my $ny = DateTime->now( time_zone => 'America/New_York' );
my $tokyo = $ny->clone->set_time_zone('Asia/Tokyo');

say $ny->strftime('%F %T %Z');     # 2025-10-23 10:00:00 EDT
say $tokyo->strftime('%F %T %Z');  # 2025-10-23 23:00:00 JST
```

**Rule of thumb:** store in **UTC**, convert at the edges (I/O).

---

## 4a) Arithmetic (add/subtract)

```perl
my $dt = DateTime->new( year=>2025, month=>1, day=>31, time_zone=>'UTC' );

$dt->add( days => 1 );        # 2025-02-01
$dt->subtract( months => 1 ); # 2025-01-01

# Using a Duration object:
use DateTime::Duration;
my $one_week = DateTime::Duration->new( days => 7 );
$dt->add_duration($one_week);
```

**Month math & DST:** DateTime handles calendar-aware rollovers; just don’t assume “1 month = 30 days”.

---

## 5a) Truncation & rounding

```perl
my $dt = DateTime->now( time_zone => 'UTC' );
say $dt->clone->truncate( to => 'day'   )->iso8601(); # 2025-10-23T00:00:00
say $dt->clone->truncate( to => 'hour'  )->iso8601();
say $dt->clone->truncate( to => 'minute')->iso8601();
```

---

## 6a) Epochs (UNIX time) and high precision

```perl
my $dt = DateTime->from_epoch( epoch => time(), time_zone => 'UTC' );
say $dt->iso8601();

my $epoch = $dt->epoch;  # integer seconds

# For subsecond precision:
use Time::HiRes qw(time);
my $dt_ms = DateTime->from_epoch( epoch => time(), time_zone => 'UTC' );
```

---

## 7a) Comparing, sorting, intervals

```perl
my ($a, $b) = (
  DateTime->new(year=>2025, month=>10, day=>1,  time_zone=>'UTC'),
  DateTime->new(year=>2025, month=>10, day=>15, time_zone=>'UTC'),
);

say $a < $b ? 'a before b' : 'a after/equal b';

# Interval overlap check: [s1,e1) vs [s2,e2)
sub overlaps {
  my ($s1,$e1,$s2,$e2) = @_;
  return ($s1 < $e2) && ($s2 < $e1);
}
```

---

## 8a) Locales (month/day names in other languages)

```perl
my $dt = DateTime->new(
  year=>2025, month=>10, day=>23, time_zone=>'UTC', locale=>'fr_FR'
);
say $dt->month_name; # octobre
say $dt->day_name;   # jeudi
```

---

## 9a) Recurring events (quick taste)

For iCal-style rules:

```perl
use DateTime;
use DateTime::Event::ICal;

my $rule = DateTime::Event::ICal->recur(
  dtstart => DateTime->new(year=>2025,month=>1,day=>1, time_zone=>'UTC'),
  freq    => 'weekly',
  byday   => [ 'mo', 'we', 'fr' ],
);

my $iter = $rule->iterator;
for (1..5) {
  my $dt = $iter->next;
  say $dt->ymd;
}
```

(There are other recurrence/event modules; this one is declarative and solid.)

---

## 10a) Business time & durations (options)

- **DateTime::BusinessDuration** — business-hour math.

- **DateTime::Format::Natural** — forgiving input (“next Friday 3pm”), handy for UX, less strict for backends.

---

## 11a) Common recipes (cheat-ready)

**A. Parse mixed input robustly (prefer strict, fall back to ISO8601)**

```perl
sub parse_ts {
  my ($s, $tz) = @_;
  $tz //= 'UTC';

  require DateTime::Format::ISO8601;
  require DateTime::Format::Strptime;

  my @fmts = (
    DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S', time_zone=>$tz),
    DateTime::Format::Strptime->new(pattern => '%Y/%m/%d %H:%M',     time_zone=>$tz),
  );

  for my $f (@fmts) {
    my $dt = $f->parse_datetime($s);
    return $dt if $dt;
  }
  return DateTime::Format::ISO8601->parse_datetime($s); # may croak on garbage
}
```

**B. “Next weekday at 09:00”**

```perl
sub next_weekday_9am {
  my ($tz) = @_;
  my $dt = DateTime->now( time_zone => $tz // 'UTC' )->truncate( to => 'day' );
  $dt->add( days => 1 );
  $dt->add( days => 1 ) while $dt->day_of_week >= 6; # 6=Sat,7=Sun
  $dt->set( hour=>9, minute=>0, second=>0 );
  return $dt;
}
```

**C. Convert local string → UTC ISO8601**

```perl
sub local_to_utc_iso {
  my ($s, $tz) = @_;
  my $fmt = DateTime::Format::Strptime->new(
    pattern   => '%m/%d/%Y %I:%M %p',
    time_zone => $tz, # e.g., 'America/New_York'
    on_error  => 'croak',
  );
  my $dt = $fmt->parse_datetime($s);
  return $dt->clone->set_time_zone('UTC')->iso8601();
}
```

---

## 12a) Alternatives & when to use them

### Time::Piece (core, lightweight)

- Pros: no CPAN install, simple, strftime/strptime-ish.

- Cons: fewer calendar smarts, time zone handling is coarse.

```perl
use Time::Piece;
my $tp = localtime;                   # now
say $tp->strftime('%F %T');
my $tp2 = Time::Piece->strptime('2025-10-23 11:00', '%Y-%m-%d %H:%M');
say ($tp2 + 3600)->strftime('%H:%M'); # add seconds
```

### Time::Moment (fast, immutable)

- Pros: speed demon, correct ISO8601, great for high-throughput services.

- Cons: smaller ecosystem than DateTime, different API.

```perl
use Time::Moment;
my $tm = Time::Moment->now_utc;
say $tm->to_string;                      # 2025-10-23T14:37:05Z
my $tm2 = $tm->plus_days(7)->with_offset_same_instant(-240); # -04:00
say $tm2->to_string;                     # 2025-10-30T10:37:05-04:00
```

**Rule of thumb**

- Need rich calendar ops, locales, time zones → **DateTime**.

- Need core-only, simple formatting → **Time::Piece**.

- Need speed/immutability/ISO strictness → **Time::Moment**.

---

## 13a) Pitfalls to dodge

- **Floating time**: DateTime without `time_zone` does not adjust for DST. Set it.

- **Parsing loose input**: prefer **Strptime/ISO8601** over DIY regexes.

- **Storing local times**: store UTC, keep original zone if business logic needs it.

- **Assuming month = 30 days**: use calendar math, not seconds, for months/years.

- **Leap seconds**: Perl’s typical stack ignores them (POSIX time). That’s normal for most apps.

---



## 9) Modules & Packages

### A. Minimal project layout (script + library + tests)

```
my-app/
├─ bin/
│  └─ app.pl
├─ lib/
│  └─ My/
│     └─ Util.pm
└─ t/
   └─ util.t
```

**bin/app.pl**

```perl
#!/usr/bin/env perl
use v5.36;
use FindBin; use lib "$FindBin::Bin/../lib";
use My::Util qw(sum mean);

say sum(1..5);
say mean(2,4,6,8);
```

**lib/My/Util.pm** — modern, export-friendly, documented

```perl
package My::Util;
use v5.36;
use Exporter::Tiny qw(import);   # nicer than base Exporter
our $VERSION   = '0.1.0';
our @EXPORT    = ();             # nothing by default
our @EXPORT_OK = qw(sum mean :stats);
our %EXPORT_TAGS = ( stats => [qw(sum mean)] );

sub sum  ($first, @rest) { my $t = $first // 0; $t += $_ for @rest; $t }
sub mean (@nums)         { die "no numbers" unless @nums; sum(@nums)/@nums }

1;
__END__

=pod

=head1 NAME
My::Util - Small numeric utilities

=head1 SYNOPSIS
  use My::Util qw(sum mean);
  say sum(1..5);
  say mean(2,4,6);

=head1 EXPORT
Nothing by default. Opt in to C<sum>, C<mean>, or C<:stats>.

=cut
```

**t/util.t** — tests (Test2 is the modern stack)

```perl
use v5.36;
use Test2::V0;
use FindBin; use lib "$FindBin::Bin/../lib";
use My::Util qw(sum mean);

is sum(1,2,3), 6, 'sum';
is mean(2,4,6), 4, 'mean';
like dies { mean() }, qr/no numbers/, 'mean dies on empty';

done_testing;
```

Run tests: `prove -lvr t`

---

### B. Understanding `@INC` and getting your module found

- One-off: `perl -Ilib bin/app.pl`

- In code (portable): `use FindBin; use lib "$FindBin::Bin/../lib";`

- Don’t hardcode relative `use lib 'lib'` in modules; reserve that for scripts and tests.

---

### C. Export patterns: default, opt-in, and tags

```perl
use My::Util qw(:stats);   # imports sum, mean via tag
use My::Util qw(sum);      # opt-in single
use My::Util ();           # import nothing; call with My::Util::sum()
```

Prefer **opt-in** (`@EXPORT_OK`) to avoid namespace collisions.

---

### D. Versioning and minimum Perl

```perl
package My::Thing;
use v5.36;                     # enables signatures, say, etc.
our $VERSION = '0.2.3';        # semantic version as string
```

Consumers can require versions:

```perl
use My::Thing 0.2 ();  # load >= 0.2, import nothing
```

---

### E. Namespaces, imports, and pragmas

- `use Foo qw(x y)` calls `Foo->import(qw/x y/)`.

- `no Foo qw(x)` calls `Foo->unimport(qw/x/)` (how pragmas work).

- Avoid multiple packages per file unless you’re doing symbol tricks on purpose.

---

### F. Object systems (Moo first, Moose if you need heavy guns)

**Moo class with types, lazy, builder, and `BUILD`**

```perl
package My::Thing;
use v5.36;
use Moo;
use Types::Standard qw(Str Int InstanceOf);

has name => ( is => 'ro', isa => Str, required => 1 );
has count => ( is => 'rw', isa => Int, default => sub { 0 } );

has dt => (
  is      => 'lazy',                                   # build once on first access
  isa     => InstanceOf['DateTime'],
  builder => sub { require DateTime; DateTime->now(time_zone=>'UTC') },
);

sub BUILD ($self, $args) { $self->count(1) unless defined $args->{count} }

sub greet ($self) { "Hi " . $self->name . " (#" . $self->count . ")" }

1;
```

Usage:

```perl
use My::Thing;
my $t = My::Thing->new( name => 'Jen' );
say $t->greet;         # Hi Jen (#1)
say $t->dt->iso8601;   # lazy-built DateTime in UTC
```

**Roles (composition, not inheritance)**

```perl
package My::Role::Log;
use Moo::Role;
requires 'component_name';

sub log_info ($self, $msg) { warn "[".$self->component_name."] $msg\n" }

package My::Worker;
use Moo;
with 'My::Role::Log';
sub component_name ($self) { 'Worker' }   # satisfies requires
```

**When Moose?**

- You need rich metaprogramming, type coercions everywhere, method modifiers galore, introspection.

- Otherwise, Moo+Types::Standard is fast and adequate for most services/scripts.

---

### G. Carp like a pro (better call sites)

```perl
use Carp qw(croak confess carp cluck);

sub must_be_even ($n) {
  croak "expected even, got $n" if $n % 2;
  return $n;
}
```

- `croak` reports as if the caller threw the error (clean API).

- `confess` adds a full stack trace (great for debugging).

---

### H. Constants & overloading

```perl
use constant PI => 3.1415926535;

package My::Vec2;
use v5.36; use Moo;
use overload '+' => 'add', '""' => 'as_string', fallback => 1;

has x => (is=>'ro'); has y => (is=>'ro');

sub add ($a,$b) { __PACKAGE__->new(x => $a->x + $b->x, y => $a->y + $b->y) }
sub as_string ($self) { "(" . $self->x . "," . $self->y . ")" }
```

Usage:

```perl
say "" . ( My::Vec2->new(x=>1,y=>2) + My::Vec2->new(x=>3,y=>4) );  # (4,6)
```

---

### I. Packaging for CPAN or internal deploys

**Makefile.PL** (ExtUtils::MakeMaker minimal)

```perl
use ExtUtils::MakeMaker;
WriteMakefile(
  NAME         => 'My::Util',
  VERSION_FROM => 'lib/My/Util.pm', # grabs $VERSION
  ABSTRACT     => 'Small numeric utilities',
  AUTHOR       => 'You <you@example>',
  LICENSE      => 'perl',
  PREREQ_PM    => {
    'Exporter::Tiny' => 0,
    'Test2::V0'      => 0,
  },
);
```

Build & test:

```
perl Makefile.PL
make
make test
make install
```

For internal apps, consider **App::FatPacker** or **PAR::Packer** to ship a single artifact.

**Local dev deps**:

- `cpanm --installdeps .` (Carton if you want a lockfile: `carton install`)

---

### J. Document with POD (don’t skip it)

Inside your module, after `1;`:

```perl
=pod

=head1 DESCRIPTION
One or two clear paragraphs of what the module does.

=head1 METHODS

=head2 sum(@nums) -> Num
Returns the total.

=head2 mean(@nums) -> Num
Average; dies on empty list.

=cut
```

Generate HTML/man: `perldoc -m My::Util`, `perldoc My::Util`.

---

### K. Performance & compile-time tricks

- `use v5.36;` gives signatures and cleaner syntax (no `my ($self, ...) = @_`).

- Put heavy `require` inside lazy builders or code paths that truly need them.

- Avoid global `%INC` churn; keep modules one-class-per-file.

- For hot paths that must be fast: consider **Time::Moment**, **XS** helpers, or caching/lazy init.

---

### L. Common “gotcha” checklist

- Always end modules with `1;`.

- Keep exports opt-in. Provide tags for bundles.

- Don’t modify `@INC` inside library files (only scripts/tests).

- Use `FindBin` in scripts to locate `../lib` reliably.

- Put tests under `t/` and run them with `prove`.

---

### M. Quick reference — object attribute options (Moo)

- `is => 'ro' | 'rw'`

- `required => 1`

- `isa => Type` (Types::Standard)

- `default => sub { ... }`

- `lazy => 1` + `builder => sub { ... }`

- `predicate => 'has_foo'` to test if set

- `clearer => 'clear_foo'` to unset

---

## 10) DBI Basics (Postgres example)

```perl
use DBI;
my $dbh = DBI->connect("dbi:Pg:dbname=$db;host=$host", $user, $pass, { RaiseError=>1, AutoCommit=>1 });
my $sth = $dbh->prepare('select id, title from dashboards where user_id = ? order by created_on desc limit ?');
$sth->execute($user_id, 20);
while (my $row = $sth->fetchrow_hashref) {
  say $row->{title};
}
```

Use placeholders (`?`) to prevent SQL injection.

ORM option: **DBIx::Class**.

---

## 11) Testing — From unit to integration (Test2 stack)

### A. Project layout (convention)

```
my-app/
├─ lib/                # your modules
├─ bin/                # scripts/CLIs
├─ t/                  # tests (unit + integration)
│  ├─ 00-load.t        # can modules load?
│  ├─ 10-util.t        # unit tests
│  ├─ 20-worker.t
│  ├─ 30-cli.t         # tests for bin/app.pl
│  ├─ helper/          # fixtures and shared bits
│  │  ├─ TestHelper.pm
│  │  └─ data/
│  │     └─ sample.json
└─ xt/                 # author/release tests (lint, pod, etc.)
   ├─ 10-pod.t
   └─ 20-kwalitee.t
```

Run tests:

```
prove -lvr t              # -l adds lib/, -v verbose, -r recurse
prove -lvr --jobs 4 t     # parallel
```

---

### B. Smoke tests (does it compile / load?)

**t/00-load.t**

```perl
use v5.36;
use Test2::V0;
require_ok 'My/Util.pm';
done_testing;
```

---

### C. Unit tests: assertions you actually use

**t/10-util.t**

```perl
use v5.36;
use Test2::V0;
use FindBin; use lib "$FindBin::Bin/../lib";
use My::Util qw(sum mean);

subtest 'sum() basics' => sub {
    is sum(2,2), 4, '2+2';
    is sum(1..5), 15, '1..5';
    is sum(), 0, 'empty list -> 0 (if designed so)';
};

subtest 'mean() behavior' => sub {
    is mean(2,4,6), 4, 'mean';
    like dies { mean() }, qr/no numbers/i, 'dies on empty';
};

done_testing;
```

Handy assertions from **Test2::V0**:

- `is`, `isnt`, `like`, `unlike`

- `dies { ... }`, `lives { ... }`, `throws { ... }`

- `array { ... }`, `hash { ... }` (deep comparisons with structure checks)

- `cmp_ok $x, '>=', 3`

---

### D. Table-driven tests (reduce repetition)

```perl
my @cases = (
  { in => [1,2,3], want => 6 },
  { in => [0],     want => 0 },
  { in => [-2,3],  want => 1 },
);

for my $i (0..$#cases) {
    my ($in,$want) = ($cases[$i]{in}, $cases[$i]{want});
    is sum(@$in), $want, "case $i: sum(@$in) = $want";
}
```

---

### E. Fixtures & helpers (shared setup/teardown)

**t/helper/TestHelper.pm**

```perl
package TestHelper;
use v5.36;
use Exporter 'import';
use File::Temp qw(tempdir);
our @EXPORT_OK = qw(temp_workspace sample_data);

sub temp_workspace () {
    my $dir = tempdir( CLEANUP => 1 );  # auto-delete
    return $dir;
}

sub sample_data () {
    return [ {x=>1}, {x=>2}, {x=>3} ];
}

1;
```

Use it:

```perl
use lib 't/helper';
use TestHelper qw(temp_workspace sample_data);

my $ws = temp_workspace();
ok -d $ws, 'got a temp dir';
```

---

### F. Capturing output (test CLIs & logging)

```perl
use Test2::V0;
use Test2::Tools::Capture qw(capture);

my ($out, $err, $ctx) = capture {
    say "hello";
    warn "oops";
};

is $out, "hello\n", 'STDOUT';
like $err, qr/oops/, 'STDERR';
```

---

### G. Testing command-line scripts (end-to-end)

**t/30-cli.t**

```perl
use v5.36;
use Test2::V0;
use IPC::Open3;
use Symbol 'gensym';

my $script = "$FindBin::Bin/../bin/app.pl";

sub run_cli (@args) {
    my $err = gensym;
    my $pid = open3(undef, \*OUT, $err, $^X, '-Ilib', $script, @args);
    local $/; my $stdout = <OUT>; my $stderr = <$err>;
    waitpid $pid, 0;
    return ($?, $stdout // '', $stderr // '');
}

my ($status, $out, $err) = run_cli('--version');
is $status >> 8, 0, 'exit 0';
like $out, qr/\b\d+\.\d+/, 'prints version';

done_testing;
```

---

### H. Mocking (cut external dependencies cleanly)

**Mock module subs with Test::MockModule**

```perl
use Test2::V0;
use Test::MockModule;

use My::Worker;

my $mock = Test::MockModule->new('My::Worker::HTTP');
$mock->redefine('get_json' => sub ($url) {
    return { ok => 1, data => [1,2,3] };   # canned response
});

is(My::Worker::pull_data(), array { item 1; item 2; item 3; end }, 'uses mock');
```

**Freeze time for deterministic tests**

```perl
use Test2::V0;
use Test::MockTime qw(set_fixed_time restore_time);

set_fixed_time(1750000000);  # epoch
is scalar localtime, 'Tue Jul 15 05:06:40 2025', 'frozen time';
restore_time();
```

---

### I. Warnings, exceptions, and edge behavior

**Fail tests on unexpected warnings**

```perl
use Test2::V0;
use Test::Warnings ':all';  # any warning becomes a test failure
use My::Util 'mean';

is mean(2,4,6), 4, 'no warnings surface';
done_testing;
```

**Precise exception matching**

```perl
use Test2::V0;
like dies { risky() }, qr/^config missing\b/, 'specific message';
```

**Deep data checks**

```perl
use Test2::V0;
use JSON::PP 'decode_json';

my $got = decode_json('{"a":1,"b":[2,3]}');
is $got, hash {
    field a => 1;
    field b => array { item 2; item 3; end };
    end
}, 'shape & content';
```

---

### J. Parallel tests, ordering, and randomness

- Run parallel: `prove -lvr --jobs 8 t`

- Keep tests independent (no shared state across files).

- If order matters, fix it or document it; Test2 runs files in lexical order by default—parallel mode scrambles timing.

---

### K. Code coverage (what did tests touch?)

Install **Devel::Cover** and run:

```
HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lvr t
cover -report html
```

Open `cover_db/coverage.html`.  
Target meaningful thresholds (e.g., 80%+), but chase *critical path* coverage, not cosmetics.

---

### L. Author/release tests (run locally or in CI)

**xt/10-pod.t**

```perl
use Test2::V0;
plan skip_all => 'Author test; set RELEASE_TESTING=1' unless $ENV{RELEASE_TESTING};
eval { require Test::Pod; Test::Pod->import; 1 } or plan skip_all => 'Test::Pod not installed';
all_pod_files_ok();
```

Run with:

```
RELEASE_TESTING=1 prove -lvr xt
```

---

### M. Quick patterns you’ll reuse

**1) “Arrange-Act-Assert” template**

```perl
subtest 'feature X' => sub {
    # Arrange
    my $ws = temp_workspace();
    # Act
    my $out = do_the_thing($ws);
    # Assert
    is $out, 'expected';
};
```

**2) Golden files (stable outputs)**

```perl
my $got = render_report(\%data);
open my $fh, '<', 't/helper/data/report.golden' or die $!;
local $/; my $want = <$fh>;
is $got, $want, 'report matches golden';
```

**3) Property-ish checks (lightweight)**

```perl
for (1..100) {
    my @nums = map int(rand 100), 1..10;
    my $s = sum(@nums);
    ok $s >= 0, 'sum non-negative for non-negative inputs';
}
```

---

### N. CI basics (GitHub Actions example)

**.github/workflows/test.yml**

```yaml
name: perl-tests
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        perl: [ "5.36", "5.38" ]
    steps:
      - uses: actions/checkout@v4
      - uses: shogo82148/actions-setup-perl@v1
        with: { perl-version: ${{ matrix.perl }} }
      - run: cpanm --quiet --notest --installdeps .
      - run: prove -lvr t
```

---

### O. Troubleshooting checklist

- A test hangs? Add `diag "pos=$i"` breadcrumbs or run `PERL5OPT=-d` to peek.

- Flaky time-based tests? Freeze time (Test::MockTime) and avoid `sleep`.

- Random failures under `--jobs`? There’s hidden global state—remove it or isolate with temp dirs and unique filenames.

- Can’t load modules in tests? Ensure `-Ilib` (or `prove -l`) and `FindBin` for script paths.

---

### P. Minimal “starter” you can paste into a new test file

```perl
use v5.36;
use Test2::V0;
use FindBin; use lib "$FindBin::Bin/../lib";

use_ok 'My::Util';

subtest 'sum' => sub {
    is My::Util::sum(1,2,3), 6;
};

done_testing;
```

---



## 12) One-Liners (superpower) — Expanded

### Cheat flags (quick memory)

- `-n` read file(s) line-by-line; run code for each line (no auto-print)

- `-p` same as `-n` **and** auto-print `$_` after your code

- `-l` auto-chomp input, auto-append `\n` on `print`

- `-a` autosplit line into `@F` (honors `-F` regex)

- `-F'RE'` set split regex for `-a`

- `-i[.bak]` in-place edit (optional backup extension)

- `-0777` slurp entire file as one string (paragraph mode “all bytes”)

- `-MModule` pre-load a module; `-MModule=arg1,arg2` import args

- `-E` enables `say`, `state`, etc. (same as `-e` but with `feature :5.10`)

---

## A) Grep-style filters (find stuff)

**Print matching lines**

```bash
perl -ne 'print if /todo/i' file.txt
```

**Print line numbers of matches**

```bash
perl -lne 'print $. if /todo/' file.txt
```

**Invert match (like grep -v)**

```bash
perl -ne 'print unless /DEBUG|TRACE/' app.log
```

**Context lines: N before/after (manual ring buffer)**

```bash
# 2 lines of context before and after 'ERROR'
perl -ne '
  push @buf, $_; shift @buf if @buf>2;
  if(/ERROR/){ print @buf; print $_; $next=2; next }
  print if $next-- > 0
' file.log
```

---

## B) Sed-style edits (search/replace)

**In-place edit with backup**

```bash
perl -i.bak -pe 's/\bfoo\b/bar/g' *.txt
```

**Multiple edits at once**

```bash
perl -i -pe 's/\t/    /g; s/\r$//' *.txt   # tabs→spaces, strip CR
```

**Only change first occurrence per file (stop after first hit)**

```bash
perl -i -pe 'if(!$done && s/foo/bar/){ $done=1 }' file.txt
```

**Change only within lines matching a guard**

```bash
perl -i -pe 's/\d{4}-\d{2}-\d{2}/<DATE>/g if /timestamp:/' app.log
```

---

## C) Awk-style field munching

**CSV (naïve, split on comma)**

```bash
perl -F, -lane '$sum += $F[2]; END{ say $sum }' data.csv
```

**Robust CSV (quotes/commas inside fields)**

```bash
perl -MText::CSV_XS=csv -E '
  my $sum=0; csv(in=>shift, headers=>"auto", cb=>sub{ $sum += $_->{amount} }); say $sum
' data.csv
```

**TSV to JSON lines**

```bash
perl -F'\t' -lane 'print qq|{"k":"$F[0]","v":"$F[1]"}|' input.tsv
```

**Select rows by numeric predicate**

```bash
perl -F, -lane 'print if $F[3] >= 100 && $F[1] eq "active"' data.csv
```

---

## D) JSON quickies

**Pretty-print JSON**

```bash
perl -MJSON::PP -0777 -ne 'print JSON::PP->new->pretty->encode(JSON::PP->new->decode($_))' data.json
```

**Extract field from each JSON line**

```bash
perl -MJSON::PP -ne 'my $o=decode_json $_; say $o->{user}{id} // "NA"' api.log.jsonl
```

**Filter JSON lines by regex**

```bash
perl -MJSON::PP -ne 'my $o=decode_json $_; print if ($o->{msg}//"") =~ /timeout/i' app.jsonl
```

---

## E) Multi-line / whole-file transforms

**Operate on entire file as a single string**

```bash
perl -0777 -pe 's/\n{3,}/\n\n/g' big.txt          # collapse 3+ blank lines to 2
```

**Strip everything between markers (greedy across lines)**

```bash
perl -0777 -pe 's/BEGIN_SECRET.*?END_SECRET//s' config.txt
```

**Find JSON blocks embedded in logs and pretty-print them**

```bash
perl -0777 -MJSON::PP -ne '
  print for ($_ =~ /(\{.*?\})/sg and do {
    my @m = /(\{.*?\})/sg;
    map { eval { decode_json($_) } ? JSON::PP->new->pretty->encode(decode_json($_)) : () } @m
  })
' app.log
```

---

## F) Counting, histogramming, dedupe

**Count unique lines**

```bash
perl -ne '$c{$_}++}{ END{ say "$_ $c{$_}" for sort keys %c }' file.txt
```

**Top-N by frequency**

```bash
perl -ne '$c{$_}++}{ END{ say for (sort { $c{$b}<=>$c{$a} } keys %c)[0..9] }' file.txt
```

**Unique (first occurrence only)**

```bash
perl -ne 'print unless $seen{$_}++' file.txt
```

**Case-insensitive unique (preserve first casing)**

```bash
perl -ne 'my $k=lc; print unless $seen{$k}++' file.txt
```

---

## G) File ops, rename, and paths

**Bulk rename by regex**

```bash
# foo-123.txt -> bar-123.txt
perl -E 'for(@ARGV){ (my $n=$_)=~s/^foo/bar/ and rename $_,$n }' foo-*.txt
```

**Touch only files older than N days**

```bash
# print candidates; swap print for utime to modify times
perl -e 'for(@ARGV){ next unless -f; print "$_\n" if -M $_ > 7 }' *
```

---

## H) Time & dates in one-liners

**Human timestamp → epoch (Strptime)**

```bash
perl -MDateTime::Format::Strptime -E '
  my $f=DateTime::Format::Strptime->new(pattern=>"%.4Y-%.2m-%.2d %.2H:%.2M:%.2S", time_zone=>"UTC");
  say $f->parse_datetime(shift)->epoch
' "2025-10-23 14:05:00"
```

**Epoch → local**

```bash
perl -MDateTime -E 'say DateTime->from_epoch(epoch=>shift,time_zone=>"local")->strftime("%F %T %Z")' 1761213900
```

---

## I) Logging gymnastics

**Only show lines between two timestamps (inclusive)**

```bash
perl -ne 'print if /2025-10-23T10:../ .. /2025-10-23T11:../' app.log
```

**Tail-like follow with filter (portable-ish)**

```bash
# On Unix: use tail -f | perl ...
tail -f app.log | perl -ne 'print if /ERROR|FATAL/'
```

---

## J) Hex, base64, and small encodings

**Hex dump of matching lines**

```bash
perl -ne 'print unpack("H*",$1),"\n" if /(payload:\s+)(.*)/' traffic.log
```

**Base64 decode column 2 (TSV)**

```bash
perl -MMIME::Base64 -F'\t' -lane '$F[1]=decode_base64($F[1]); print join "\t", @F' data.tsv
```

---

## K) Speed patterns & safety

**Pre-compile hot regex**

```bash
perl -ne 'state $re = qr/ERROR|FATAL/; print if /$re/' app.log
```

**Avoid catastrophic backtracking**

```bash
perl -ne 'print if /(?>\w+)=\d+/' file.txt
```

**Binary-safe slurp (no UTF-8 decoding)**

```bash
perl -0777 -ne 'print' file.bin > copy.bin
```

---

## L) BEGIN/END and tiny state machines

**Compute running average**

```bash
perl -lane 'BEGIN{ $s=0;$n=0 } $s+=$_ for @F; $n+=@F; END{ printf "%.3f\n",$s/$n }' nums.txt
```

**Block-wise processing (between markers)**

```bash
perl -ne '$in=1 if /BEGIN/; print if $in; $in=0 if /END/' file.txt
```

---

## M) Windows quoting cheat (since you’re on Win)

- **CMD.exe**: prefer double quotes for the whole program, escape inner quotes by doubling.

```cmd
perl -ne "print if /todo/i" file.txt
perl -i.bak -pe "s/\bfoo\b/bar/g" *.txt
```

- **PowerShell**: single quotes are literal; use them to avoid escaping `\`.

```powershell
perl -ne 'print if /todo/i' file.txt
perl -i.bak -pe 's/\bfoo\b/bar/g' *.txt
```

- If things get hairy, put the code in a `.pl` and run `perl script.pl`.

---

## N) Quality-of-life aliases

**Bash**

```bash
alias p='perl -Mstrict -Mwarnings -E'
```

Use:

```bash
p 'say 1+2'
```

**Windows (CMD)**

```cmd
doskey p=perl -Mstrict -Mwarnings -E $*
```

---

## O) Little “toolbox” you’ll reuse

**1) Grep by extension, recursive (find + perl)**

```bash
find . -type f -name '*.pl' -print0 | xargs -0 perl -ne 'print "$ARGV:$_" if /use\s+strict/'
```

**2) JSONL to CSV (keys fixed)**

```bash
perl -MJSON::PP -E '
  say "id,name";
  while(<>){ my $o=decode_json $_; say join ",", $o->{id}//"", $o->{name}//"" }
' data.jsonl
```

**3) Collapse duplicates but keep a count prefix**

```bash
perl -ne 'print if !$seen{$_}++; END{ warn scalar(keys%seen)," unique\n" }' file.txt
```

---

### Mental model refresh

- Treat `-n/-p` as your read loop; mutate `$_`, print it (or not).

- Reach for `-a -F` when you want Awk vibes; reach for modules (`-M...`) for correctness (CSV/JSON).

- For multiline transforms, think `-0777` and `s///s`.

- Keep dangerous edits safe with `-i.bak`—delete backups when you’re happy.



---

## 13) Web (Mojolicious quickie)

```perl
# myapp.pl
use Mojolicious::Lite;
get '/' => sub ($c) { $c->render(text => 'Hello Mojo!') };
app->start;
# run: morbo myapp.pl
```

---

## 14) Perf & Tooling

- Profile: `perl -d:NYTProf script.pl` → `nytprofhtml`

- Avoid needless string copying; use references.

- Cache compiled regex (`qr//`).

- Beware autovivification creating keys by accident:
  
  ```perl
  if (exists $h{maybe} && defined $h{maybe}) { ... }
  ```

---

## 15) Pitfalls

- `==` vs `eq` (numeric vs string).  
- `my` (lexical) vs `our` (package) vs `local` (temp. dynamic scope).  
- Params aliasing via `@_`.  
- Context changes return values (scalar vs list).  
- Smartmatch/given/when were experimental in older Perls—check your version before using.  
- Global match vars `$& $' $`` can slow regex engine.

— End —
