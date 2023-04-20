#!/usr/bin/perl -s -w
use strict;
use v5.10;
use File::Basename qw<basename>;
use DBI;
use Cwd qw<cwd>;
use Excel::Grinder;
use lib 'lib';
use Dotenv;         # custom module since the one on CPAN doesnt work on windows

our # optional switches
(   $month, $year, $prefix
,   $h => $help
,   $v => $verbose
);

BEGIN
{   my $script = basename($0);
    my $usage = "Usage: $script [-month=M -year=Y -prefix=xxx -h[elp] ]\n";

    $h //= $help;
    $v //= $verbose;
    $h and warn $usage and exit 0;

    # valdate switches
    my @opts = (    [ \$month,  qr|^\d[0-2]?$| ]
               ,    [ \$year,   qr|^\d{4}$|    ]
               ,    [ \$prefix, qr|^\w+$|      ]
               );
    foreach my $opt (@opts)
    {   my ($var, $re) = @$opt;
        next unless defined $$var;
        $$var =~ /$re/ or warn $usage and exit 2;
        $$var = $&;
    }

    # defaults
    my @now = localtime;
    $month  //= $now[4];                        # month starts at 0; ok since we default to prev month
    $year   //= $now[5]+1900;                   # year starts at 1900
    $prefix //= 'wp_';                          # default wordpress prefix

    $month == 0 and $month = 12 and $year--;    # change month 0 to december the previous year

    $v and warn "Making report for $month/$year for site $prefix\n";
}

# inform compiler about our subroutines
sub slurp_file;
sub prepare_query;
sub run_query;

# set separator according to OS
my $sep = $^O eq 'MSWin32' ? '\\\\' : '/';

my %dotenv = Dotenv::Parse; # load dbi credentials from .env
die "Missing DB configuration in .env file\n"
    unless defined $dotenv{'DATA_SOURCE'}
        && defined $dotenv{'DB_USERNAME'}
        && defined $dotenv{'DB_PASSWORD'};

my @queries = grep { -f }                                         glob "queries$sep*.sql";
my @sheets  = map  { s| ^queries $sep (\w+) \.sql$ |\u$1|rx     } @queries;
my @data    = map  { [ run_query prepare_query slurp_file($_) ] } @queries;

$v and warn "$sheets[$_] has ". scalar $data[$_]->@* ." rows\n" for keys @sheets;

# prepare filename for report
my $path = cwd . $sep . "output" . $sep;
my @now = localtime;
my $timestamp = sprintf(   "%d" . ("%02d" x 5),
                       ,   $now[5]+1900     # year (starts at 1900)
                       ,   $now[4]+1        # month (starts at 0)
                       ,   $now[3]          # day
                       ,   $now[2]          # hour
                       ,   $now[1]          # minute
                       ,   $now[0]          # second
                       );
my $filename = "$prefix-$month-$year-$timestamp.xlsx";

# generate xlsx file from data
my $xlsx = Excel::Grinder->new($path);
my $file = $xlsx->write_excel(  'filename'          => $filename
                             ,  'headings_in_data'  => 1
                             ,  'worksheet_names'   => \@sheets
                             ,  'the_data'          => \@data
                             );

$v and warn "Report saved as $filename\n";


####### subroutines #######

sub slurp_file
{   my $file = shift;
    local $/ = undef;
    open my $fh, '<', $file or die "Could not open file $file: $!";
    my $content = <$fh>;
}

sub prepare_query
{   state $base_sql //= slurp_file('base.sql');
    my $query = shift;

    my $sql = "$base_sql\n$query";

    # insert month, year, and prefix into query
    # \Q turns off metachars, so that '{}' can be used without escaping
    $sql =~ s/\Q{{month}}/$month/g;
    $sql =~ s/\Q{{year}}/$year/g;
    $sql =~ s/\Q{{prefix}}/$prefix/g;

    return $sql;
}

sub run_query
{   my $sql = shift;

    # connect to database and run query
    my $dbh = DBI->connect($dotenv{'DATA_SOURCE'}, $dotenv{'DB_USERNAME'}, $dotenv{'DB_PASSWORD'})
        or die "failed to connect to database\n";
    my $sth = $dbh->prepare($sql)
        or die "prepare statement failed: $dbh->errstr()";
    $sth->execute()
        or die "execution failed: $dbh->errstr()";

    # get field names and add as the first row
    my $fields = $sth->{NAME_lc};
    my @data = ( $fields );

    # add values from each row
    while(my $row = $sth->fetchrow_hashref())
    {   push @data, [ map { $row->{$_} // '' } $fields->@* ];
    }

    $sth->finish;
    $dbh->disconnect;
    return @data;
}
