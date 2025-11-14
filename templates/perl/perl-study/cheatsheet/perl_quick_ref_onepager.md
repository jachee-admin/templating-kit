# Perl Daily Quick‑Ref (One‑Pager)

## Strict, warnings, say

```perl
use strict; 
use warnings; 
use feature qw(say);
```

## Scalars, arrays, hashes

```perl
my $s = "x"; 
my @a = (1,2); 
my %h = (k=>1);
$a[0]; 
$h{k};
my @slice = @a[0,1];
my @hk = @h{qw/k/};
```

## Context

```perl
my $n = @a;         # scalar context -> length
my @t = localtime;  # list context
```

## Comparisons

- Numeric: `== != < <= > >=`
- String:  `eq ne lt le gt ge`
- Defined‑or: `//` (`//=`)

## References

```perl
my $aref = [1, 2]; 
my $href = {k => 1};
my $arr = [1, 2];
push $arr->@*, 3;
push @$aref, 3; 
$href->{k} = 2;
```

## Subroutines

```perl
sub add { my ($a,$b)=@_; $a+$b }
# with signatures (newer):
sub add2 ($a,$b){ $a+$b }
```

## Regex

```perl
if ($s =~ /(?<w>\w+)/) {  # named capture
    say $+{w} 
}  
$s =~ s/\s+/-/g;
my $re = qr/\bfoo\b/; 
$s =~ $re;
```

## I/O

```perl
use autodie;
open my $fh,'<:encoding(UTF-8)',$file;
while (my $line=<$fh>){ chomp $line; ... }
```

## JSON & CLI

```perl
use JSON::PP qw(encode_json decode_json);
use Getopt::Long qw(GetOptions);
GetOptions("verbose!"=>\my $v);
```

## DBI (Pg)

```perl
use DBI;
my $dbh=DBI->connect("dbi:Pg:dbname=$db",$u,$p,{RaiseError=>1});
my $ary=$dbh->selectall_arrayref("select 1");
```

## One‑liners

```bash
perl -ne 'print if /todo/' file
perl -i.bak -pe 's/foo/bar/g' *.txt
perl -F, -lane '$s+=$F[2]; END{print $s}' data.csv
```

## Pitfalls

- `==` vs `eq`
- Params aliasing via `@_`
- `$& $' $`` slow regex
- Context matters
