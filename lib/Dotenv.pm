package Dotenv;
use strict;
use Carp;

sub Parse {
    my $file = shift // '.env'; # defaulting to .env
    my %dotenv;
    open my $fh, "<", $file or croak __PACKAGE__, ": Could not open $file. $!";
    while(<$fh>){
        chomp;
        m{
            \A
            (?<key>[\w-]+)      #key
            \s*=\s*             #=
            (?<q>['"]?)         #optional quotes
            (?<val>[^'"]+)      #value
            \k<q>               #same quote character as before
            \z
        }x or croak __PACKAGE__, ": Could not parse file '$file'";

        $dotenv{$+{'key'}} = $+{'val'};
    }
    close $fh;
    return %dotenv;
}

1;
