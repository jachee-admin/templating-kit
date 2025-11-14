# Perl Deep Dive (Context, Regex Engine, OO, Tooling)

## 1) Context & `wantarray`

Functions behave differently in scalar vs list vs void.

```perl
sub demo {
  return wantarray ? (1,2,3) : 4;
}
my @x = demo();   # (1,2,3)
my $n = demo();   # 4
```

List assignment vs scalar:

```perl
my ($first) = some_list();    # first element
my $count   = some_list();    # number of elements
```

## 2) Regex engine tricks

- `/x` for readable patterns (whitespace & comments)

- Lookarounds `(?=...) (?!...) (?<=...) (?<!...)`

- Atomic groups `(?>...)` and possessive quantifiers `++` to prevent catastrophic backtracking

- Global scan with `\G` and `/g`
  
  Absolutely. Here’s a tight, example-driven upgrade for that cheatsheet block—each item shows what it does, a compact example, and the key takeaway.
  
  ### `/x` — readable patterns (whitespace & comments)
  
  ```perl
  my $s = "Name: John  Age: 39";
  my $re = qr/
      Name: \s* (?<name>\w+)   # capture the name
      \s+ Age: \s* (?<age>\d+) # capture the age
  /x;
  
  $s =~ $re and printf "%s is %d\n", $+{name}, $+{age};  # John is 39
  ```
  
  **Note:** With `/x`, spaces and `# comments` are ignored—escape literal spaces as `\` or use `\s`.
  
  ---
  
  ### Lookarounds `(?=...) (?!...) (?<=...) (?<!...)`
  
  **Positive lookahead `(?=...)`: match a word only if followed by digits**
  
  ```perl
  my $t = "foo1 foo foo2";
  say for ($t =~ /\b\w+(?=\d)/g);   # foo, foo
  ```
  
  **Negative lookahead `(?!...)`: match `foo` not followed by digits**
  
  ```perl
  say for ($t =~ /\bfoo(?!\d)\b/g); # foo
  ```
  
  **Positive lookbehind `(?<=...)`: grab digits only if preceded by `$`**
  
  ```perl
  my $p = "Cost: $12, was 9";
  say for ($p =~ /(?<=\$)\d+/g);    # 12
  ```
  
  **Negative lookbehind `(?<!...)`: digits not preceded by `-`**
  
  ```perl
  my $n = "3 -4 5 -6";
  say for ($n =~ /(?<!-)\b\d+\b/g); # 3, 5
  ```
  
  **Tip:** Perl’s fixed-width lookbehind is strict (unless you’re on a build with variable-length lookbehind enabled). Keep it simple: constant-length patterns.
  
  ---
  
  ### Atomic groups `(?>...)` and possessive quantifiers `++`
  
  **Goal:** stop the engine from backtracking inside a piece once it’s matched, avoiding catastrophic backtracking on tricky inputs.
  
  **Atomic group `(?>...)`:**
  
  ```perl
  my $s = "aaaaaaaaab";
  # Greedy-but-atomic 'a+' then literal 'b'
  say "match" if $s =~ /(?>a+)\b/;     # fails (no backtrack into the atomic group)
  say "match" if $s =~ /(?>a+)b/;      # matches (ends with b)
  
  # Compare with non-atomic (may backtrack heavily on pathological inputs)
  ```
  
  **Possessive quantifier `++`:** same idea, shorter syntax.
  
  ```perl
  my $s = "aaaaaaaaab";
  say "match" if $s =~ /a++b/;         # matches; 'a++' won't backtrack
  say "no"    if $s !~ /a++\b/;        # fails; no backtrack allowed
  ```
  
  **When to use:**
  
  - You’re matching a big “blob” you never want to split (e.g., `\w++`, `.+?` vs `.++`)
  
  - You’re defending against exponential backtracking in nested alternations.
  
  ---
  
  ### Global scan with `\G` and `/g`
  
  **Goal:** continue a match exactly where the previous `/g` left off—great for tokenizers or anchored, stepwise parses.
  
  **Tokenize step-by-step:**
  
  ```perl
  my $s = "foo, 42;bar";
  my @tok;
  
  # Global match with \G to force contiguous scanning
  while (
      $s =~ /\G
          \s*                    # skip space
          (?:                    # one token:
              (?<word>[A-Za-z]+) # word
            | (?<num>\d+)        # number
            | (?<punc>[,;])      # punctuation
          )
      /xg
  ) {
      push @tok, $+{word} // $+{num} // $+{punc};
  }
  
  # If we didn't consume everything, report where it failed
  die "Unexpected at pos $+[0]" if pos($s) != length($s);
  
  say join " | ", @tok;  # foo | , | 42 | ; | bar
  ```
  
  **“Sticky” sub-matches on a line:**
  
  ```perl
  my $s = "a=1 b=2 c=3";
  my %kv;
  while ($s =~ /\G\s*([a-z])=([0-9]+)/g) {
      $kv{$1} = $2;
  }
  # pos($s) now points at end of last match
  ```
  
  **Anchored replacements with `/g` + `\G`:** only replace in sequence, stop on first gap.
  
  ```perl
  my $s = "abc  def   ghi";
  $s =~ s/\G([a-z]+)\s+/$1_/g;  # turns leading run into "abc_def_ghi"
  # stops when sequence breaks (if there were junk characters)
  ```
  
  ---
  
  ### Quick performance guardrail example
  
  **Catastrophic backtracking candidate:**
  
  ```perl
  my $bad = "a" x 30 . "!" ;
  # /(a+)+b/ on $bad will thrash; protect inner with possessive:
  $bad =~ /(a++)+b/ or say "safe fail without backtracking storm";
  ```

**Avoid:** `$& $' $`` in hot paths (they enable slow match tracking).

## 3) Error handling

```perl
use Try::Tiny;

try {
    risky();
}
catch {
    warn "Error: $_";
}
or do {
    # else-equivalent block
    say "Ran only if try succeeded";
};
```

```perl
# autodie to turn failures into exceptions:
use autodie; open my $fh,'<',$file;  # dies on error
```

Also try out Syntax::Keyword::Try (core as of perl 5.36):

```perl
use v5.36;
use experimental 'try';

try {
    say "Trying risky task...";
    risky();
    say "This runs only on success";
    1;
}
catch ($e) {
    warn "Error: $e";
    0;
}
and do {
    say "ELSE-equivalent: executed only if try succeeded";
};
```

## 4) OO options

- **Moo** (fast, minimal), **Moose** (rich), **Mojo::Base** (light for Mojolicious)
- Role composition with `Moo::Role`
- Builders, lazy attributes, type checks via `Types::Standard`

```perl
use Moo;
use Types::Standard qw(Str Int);
has name => (is=>'ro', isa=>Str, required=>1);
has count => (is=>'rw', isa=>Int, default=>sub{0});
```

## 5) Data handling

- `JSON::PP` (pure Perl), `Cpanel::JSON::XS` (fast XS)
- Dates: `DateTime` or `Time::Piece` (core) for lighter needs
- Paths: `Path::Tiny` for sane file ops

## 6) CLI ergonomics

- `Getopt::Long` for flags
- `Pod::Usage` to show usage from embedded POD
- `perl -MDDP -e 'p %ENV'` quick debug

## 7) Performance

- Profile with `Devel::NYTProf`

- Precompile regexes with `qr//`

- Avoid autovivification surprises:
  
  ```perl
  exists $h{foo} && defined $h{foo} and ...;
  ```

- Use hash lookups instead of grep for membership:
  
  ```perl
  my %set = map { $_ => 1 } @list;
  if ($set{$item}) { ... }
  ```

## 8) Testing stack

- `Test2::V0` (modern), `Test::More` (classic)
- `prove -lvr t` to run tests with lib & verbose

## 9) Packaging & CPAN

- Minimal module: package, `Exporter`, return true (`1;`)
- Dist tools: `Dist::Zilla` or `Minilla` (if publishing)
- Version in `$VERSION` or `our $VERSION = '0.1.0';`

## 10) Encoding & Unicode

- `use utf8;` for source
- Always set I/O layers: `open my $fh, "<:encoding(UTF-8)", $file`
- `binmode STDOUT, ":encoding(UTF-8)"`

## 11) Taint mode (legacy but useful)

- Run with `-T` to taint external data until untainted
- Sanitize with regex before use in sensitive ops

## 12) Concurrency & async

- Threads are heavy; prefer processes or event loops
- `Mojolicious` has `Mojo::IOLoop` for async timers and non‑blocking I/O
- For parallel work: `Parallel::ForkManager`, `MCE` (multi core)

— End —
