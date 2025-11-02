###### Perl

# Roles & Interfaces: `Role::Tiny`, `Moo::Role`, Requirements, and Composition

Roles compose behavior without deep inheritance. Declare required methods, mix into classes, and avoid fragile hierarchies.

## TL;DR

* Roles are composable units of behavior; they’re not classes.
* Declare `requires` to enforce an “interface”.
* `Role::Tiny` is minimal; `Moo::Role` integrates with `Moo`.
* Resolve method conflicts explicitly when multiple roles collide.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings;

# Role::Tiny (no object system required) ---------------------------------------
{
    package R::Identifiable;
    use Role::Tiny;
    requires 'id';                       # class must provide ->id

    sub ident ($self) { sprintf "%s#%s", ref($self), $self->id }
}

# Consumer using classic package-based OO --------------------------------------
{
    package Thing;
    use Role::Tiny::With;               # enable 'with'
    with 'R::Identifiable';

    sub new { bless { id => $_[1] // 'n/a' }, $_[0] }
    sub id  { $_[0]->{id} }
}

my $t = Thing->new('X42');
say $t->ident;                          # Thing#X42

# Moo::Role works the same but integrates with Moo attributes -------------------
{
    package R::Timestamped;
    use Moo::Role;
    requires 'id';
    has created_at => (is=>'ro', default => sub { time });
    sub as_hash ($self){ +{ id=>$self->id, created_at=>$self->created_at } }
}

{
    package Doc;
    use Moo;
    with 'R::Timestamped';
    has _id => (is=>'ro', required=>1);
    sub id ($self){ $self->_id }
}

my $d = Doc->new(_id => 'D9');
say $d->as_hash->{id};                  # D9
```

---

## Notes

* Roles reduce diamond-inheritance pain by composing behavior laterally.
* If two roles provide the same method, the last `with` wins—be explicit.
* Use roles for cross-cutting concerns: identity, timestamps, caching, logging.

---

```yaml
---
id: templates/perl/146-roles-interfaces.pl.md
lang: perl
platform: posix
scope: oo-roles
since: "v0.1"
tested_on: "perl 5.36, Role::Tiny 2.2, Moo 2.005"
tags: [perl, roles, interfaces, role-tiny, moo-role, composition, requires]
description: "Behavior composition with roles: Role::Tiny and Moo::Role, required methods, and conflict handling."
---
```

