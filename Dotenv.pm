#! perl -w

our %dotenv;

my $file = '.env';
@_ and $file = shift;

open my $fh, "<", $file;
while(<$fh>){
    chomp;
    m{
        \A              
        (?<key>[\w-]+)              #key
        \s*=\s*                     #=
        (?<q>['"]?)                 #optional quotes
        (?<val>[^'"]+)              #value
        \k<q>                       #same quote character as before
        \z
    }xx;
    
    die "Dotenv failure: invalid variables in $file\n" unless defined $+{'key'} and defined $+{'val'};

    $dotenv{$+{'key'}} = $+{'val'};
}
close $fh;
