package Dotenv;
use strict;
use Carp;

our (@ISA, @EXPORT, @EXPORT_OK);

require Exporter; @ISA = ( 'Exporter' ); # export/import service

@EXPORT = qw( Parse );
@EXPORT_OK = qw();

sub Parse {
    my ($file) = @_;
    $file or $file = '.env'; # default file
    my %dotenv;
    open my $fh, "<", $file
        or croak __PACKAGE__, ": Could not open $file. $!";
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
        }xx;

        croak __PACKAGE__, ": Could not parse file '$file'"
            unless defined $+{'key'} and defined $+{'val'};

        $dotenv{$+{'key'}} = $+{'val'};
    }
    close $fh
        or croak __PACKAGE__, ": Could not close $file. $!";
    return %dotenv;
}

1;
