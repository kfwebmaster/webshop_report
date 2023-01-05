#! perl -s -w

use strict; 
use v5.10;

use feature qw( refaliasing declared_refs );
no warnings qw( experimental::refaliasing experimental::declared_refs );

#load modules
use Cwd qw( cwd );
use DBI;
use Excel::Grinder;

#custom Dotenv module, since the one on cpan doesn't work on windows
our %dotenv;
require qw( ./lib/Dotenv.pm );

#optional switches
our ($month, $year, $prefix);

BEGIN {
    my $usage = "Usage: $0 [-month=M -year=Y -prefix=xxx]";

    #validate switches, if provided
    #avoid compilation error by using warn and exit instead of die
    $month  and $month  !~ /^\d[0-2]?$/ and warn $usage and exit 1;
    $year   and $year   !~ /^\d{4}$/    and warn $usage and exit 1;
    $prefix and $prefix !~ /^\w+$/      and warn $usage and exit 1;

    #defaults
    my @now = localtime;
    $month  or $month = $now[4];        #month starts at 0, we leave it alone to default to prev month
    $year   or $year = $now[5]+1900;    #year starts at 1900
    $prefix or $prefix = 'wp_';         #default wordpress prefix

    #change month 0 to december the previous year
    $month == 0 and $month = 12 and $year--;
}

#load list of query files
my @queries = <queries/*.sql>;
0 < @queries or die "No files found in queries/. ";

#run queries and add data
our @data;
foreach my $file (@queries){
    my $query = load_file_content($file);
    my $sql = prepare_query($query);
    push @data, [ run_query($sql) ];
}

#generate sheet names from query filenames
#queries/sales.sql -> Sales
my @sheets = map { s|^queries/(\w+)\.sql$|\u$1|r } @queries;

#prepare filename for report
my $path = cwd . "/output/";
my @now = localtime;
my $timestamp = sprintf("%d" . ("%02d" x 5),
    $now[5]+1900,   #year (starts at 1900)
    $now[4]+1,      #month (starts at 0)
    $now[3],        #day
    $now[2],        #hour
    $now[1],        #minute
    $now[0]         #second
);
my $filename = "$prefix-$month-$year-$timestamp.xlsx";

#generate xlsx file from data
my $xlsx = Excel::Grinder->new($path);
my $file = $xlsx->write_excel(
    'filename'          => $filename,
    'headings_in_data'  => 1,
    'worksheet_names'   => [ @sheets ],
    'the_data'          => [ @data ],
);

####### subrouties #######

sub load_file_content {
    my ($file) = @_;
    my $content;
    open my $fh, '<', $file
        or die "Could not open file $file: $!";
    while(my $line = (<$fh>)){
        $content.= $line;
    }
    close $fh 
        or die "Could not close file $file: $!";
    return $content;
}

sub prepare_query {
    state $base_sql = load_file_content('base.sql');
    my ($query) = @_;

    my $sql = "$base_sql\n$query";

    #insert month, year, and prefix into query
    #\Q turns off metachars, so that '{}' can be used without escaping
    $sql =~ s/\Q{{month}}/$month/g;
    $sql =~ s/\Q{{year}}/$year/g;
    $sql =~ s/\Q{{prefix}}/$prefix/g;

    return $sql;
}

sub run_query {
    my ($sql) = @_;

    #connect to database and run query
    my $dbh = DBI->connect($dotenv{'DATA_SOURCE'}, $dotenv{'DB_USERNAME'}, $dotenv{'DB_PASSWORD'})
        or die "failed to connect to database\n";
    my $sth = $dbh->prepare($sql)
        or die "prepare statement failed: $dbh->errstr()";
    $sth->execute()
        or die "execution failed: $dbh->errstr()";

    #get field names and add as the first row
    my $fields = $sth->{NAME_lc};
    my @data = ();
    push @data, $fields;

    #add values from each row
    while(my $row = $sth->fetchrow_hashref()){
        push @data, [ map { $row->{$_} } $fields->@* ];
    }

    $sth->finish;
    $dbh->disconnect;
    return @data;
}
