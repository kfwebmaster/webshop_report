#! perl -s -w

use strict; 
use feature qw( refaliasing declared_refs );
no warnings qw( experimental::refaliasing experimental::declared_refs );

#dependencies
use Cwd qw( cwd );
use DBI;
use Excel::Grinder;

#custom Dotenv module, since the one on cpan does not work on windows
our %dotenv;
require qw( .\Dotenv.pm );


#defaults
my @now = localtime;
our ($month, $year, $prefix) = (
    $now[4],        #month starts at 0, we leave it alone to default to prev month
    1900+$now[5],   #year starts at 1900
    'wp_'           #default wordpress prefix
);

#change month 0 to december previous year
$month == 0 and $month = 12 and $year--;

BEGIN {
    my $usage = "Usage: $0 [-month=M -year=Y -prefix=xxx]";
    
    #validate switches, if provided
    $month and $month   !~ /^\d[0-2]?$/ and warn $usage and exit 1;
    $year and $year     !~ /^\d{4}$/    and warn $usage and exit 1;
    $prefix and $prefix !~ /^\w+$/      and warn $usage and exit 1;
}



my $dbh = DBI->connect($dotenv{'DATA_SOURCE'}, $dotenv{'DB_USERNAME'}, $dotenv{'DB_PASSWORD'})
    or die "failed to connect to database\n";


#load base sql
my $sql;
open my $fhsql, '<', 'query.sql';
$sql.= $_ for (<$fhsql>);
close $fhsql;

#insert prefix, date and year into sql query
#\Q turns of metachars, so that '{}' can be used without escaping
$sql =~ s/\Q{{month}}/$month/g;
$sql =~ s/\Q{{year}}/$year/g;
$sql =~ s/\Q{{prefix}}/$prefix/g;


my $sth = $dbh->prepare($sql) 
    or die "prepare statement failed: $dbh->errstr()";
$sth->execute() 
    or die "execution failed: $dbh->errstr()";

my @overview = ();

#get field names
my $fields = $sth->{NAME_lc};

#add field names as the first row
push @overview, $fields;

while(my $row = $sth->fetchrow_hashref()){
    my @vals = ();
    
    #using $fields to ensure the values come in the same order for each row
    push @vals, $_ foreach map { $row->{$_} } $fields->@*;

    push @overview, \@vals;
}

$sth->finish;
$dbh->disconnect;


my $path = cwd; #current working directory
my $filename = "report-$prefix-$month-$year.xlsx";

my $xlsx = Excel::Grinder->new($path);
my $file = $xlsx->write_excel(
    'filename' => $filename, 
    'headings_in_data' => 1, 
    'worksheet_names' => ['Overview'],
    'the_data' => [
        [@overview]
    ],
);

