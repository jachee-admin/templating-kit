###### Perl

# Object Orientation Quickstart: `Moo` + `Type::Tiny` (Light, Modern OO)

Small, modern Perl OO using Moo — fast to load, clean attributes, type constraints, and compatible with Moose.

## TL;DR

* `Moo` + `Type::Tiny` gives you strong OO with minimal overhead.
* Use `has` for attributes, `is => 'ro'|'rw'`.
* Add `isa =>` for lightweight type checks.
* Inherit by `extends 'BaseClass';`, compose with `with 'Role';`.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings;

{
    package Point;
    use Moo;
    use Types::Standard qw(Num);

    has x => (is=>'ro', isa=>Num, required=>1);
    has y => (is=>'ro', isa=>Num, required=>1);

    sub dist ($self) { sqrt($self->x**2 + $self->y**2) }
}

my $p = Point->new(x=>3, y=>4);
say "distance=", $p->dist;

# --- Inheritance --------------------------------------------------------------
{
    package ColoredPoint;
    use Moo;
    extends 'Point';
    use Types::Standard qw(Str);
    has color => (is=>'ro', isa=>Str, default=>'red');
    sub describe ($self) { sprintf "%s point at (%.1f,%.1f)", $self->color, $self->x, $self->y }
}

my $cp = ColoredPoint->new(x=>5, y=>12, color=>'blue');
say $cp->describe;

# --- Roles --------------------------------------------------------------------
{
    package Drawable;
    use Moo::Role;
    requires 'draw';
}

{
    package Square;
    use Moo;
    with 'Drawable';
    has side => (is=>'ro', isa=>Num, required=>1);
    sub draw ($self){ say "Drawing square side=",$self->side }
}
Square->new(side=>2)->draw;
```

---

## Notes

* `Moo` defers heavy Moose meta-object logic until needed — fast startup.
* Combine with `Type::Tiny` for validation, or skip for speed in hot paths.
* Upgrade path: changing `Moo` to `Moose` often “just works.”

---

```yaml
---
id: templates/perl/150-moo-quickstart.pl.md
lang: perl
platform: posix
scope: oo
since: "v0.1"
tested_on: "perl 5.36, Moo 2.005, Type::Tiny 2.004"
tags: [perl, moo, type-tiny, oop, roles, inheritance, attributes]
description: "Modern lightweight OO: Moo + Type::Tiny for typed attributes, inheritance, and roles."
---
```
