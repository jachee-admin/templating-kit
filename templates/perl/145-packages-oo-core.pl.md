###### Perl

# Core OO: Packages, `bless`, Inheritance, Exporters, and Module Layout

Classic Perl OO without frameworks: define classes with `package` + `bless`, use `@ISA`/`SUPER::` for inheritance, and ship functions via `Exporter`. Great for understanding the foundations and working with legacy code.

## TL;DR

* A “class” is just a `package`; objects are refs blessed into that package.
* Use `our @ISA` or `use parent` for inheritance; call parent via `SUPER::method`.
* Keep state in hash-based objects; validate in `new`.
* Exporter is for function modules; object modules usually don’t export.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings;

# lib/My/Point.pm ---------------------------------------------------------------
# package-based class with constructor, methods, and validation
{
    package My::Point;
    use strict; use warnings;

    sub new {
        my ($class, %args) = @_;
        for my $req (qw/x y/) {
            die "missing $req" unless defined $args{$req};
            die "$req must be numeric" unless $args{$req} =~ /\A-?\d+(?:\.\d+)?\z/;
        }
        my $self = { x => 0 + $args{x}, y => 0 + $args{y} };   # force numeric
        bless $self, $class;
        return $self;
    }

    # Accessors (manual)
    sub x { $_[0]->{x} }
    sub y { $_[0]->{y} }

    sub dist { my ($s) = @_; sqrt($s->{x}**2 + $s->{y}**2) }
}

# lib/My/ColorPoint.pm ----------------------------------------------------------
{
    package My::ColorPoint;
    use strict; use warnings;
    use parent 'My::Point';          # sets @ISA and loads parent if needed

    sub new {
        my ($class, %args) = @_;
        $args{color} //= 'red';
        my $self = $class->SUPER::new(%args);
        $self->{color} = $args{color};
        return $self;
    }

    sub color { $_[0]->{color} }
    sub describe {
        my ($s) = @_; return sprintf "%s(%.1f,%.1f)", $s->{color}, $s->{x}, $s->{y};
    }
}

# lib/My/Util.pm (function module) ---------------------------------------------
{
    package My::Util;
    use strict; use warnings;
    use Exporter 'import';
    our @EXPORT_OK = qw(sum mean);
    sub sum  { my $t=0; $t+=$_ for @_; $t }
    sub mean { @_ ? sum(@_)/@_ : 0 }
}

# --- Usage ---------------------------------------------------------------------
use lib 'lib';
use My::Point;
use My::ColorPoint;
use My::Util qw(sum mean);

my $p  = My::Point->new(x=>3,y=>4);
my $cp = My::ColorPoint->new(x=>5,y=>12,color=>'blue');
say $p->dist;                 # 5
say $cp->describe;            # blue(5.0,12.0)
say mean(10, 20, 40);         # 23.333...
```

---

## Notes

* Prefer `use parent 'Base'` over manually setting `@ISA`.
* Hash-based objects are common; array-based are faster but unreadable.
* Avoid exporting from OO modules—namespaces get messy.
* This foundation explains why `Moo`/`Moose` are cleaner for larger systems.

---

```yaml
---
id: templates/perl/145-packages-oo-core.pl.md
lang: perl
platform: posix
scope: oo-core
since: "v0.1"
tested_on: "perl 5.36"
tags: [perl, oo, bless, packages, inheritance, exporter, parent]
description: "Classic Perl OO: packages + bless, inheritance via parent/@ISA, and clean Exporter-based function modules."
---
```
