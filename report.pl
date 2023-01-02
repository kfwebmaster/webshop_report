#! perl -s -w

use strict; 
use Cwd qw( cwd );
use DBI;
use Excel::Grinder;

use feature qw( refaliasing declared_refs );
no warnings qw( experimental::refaliasing experimental::declared_refs );

#custom Dotenv module, since the one on cpan doesn't work on windows
our %dotenv;
require qw( .\Dotenv.pm );

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

#load sql query
our $base_sql = load_file_content('base.sql');

our @data;
my %queries = (
    'Overview' => 'overview.sql',
);

#run queries and add data
foreach my $key (sort keys %queries){
    my $file = $queries{$key};
    my $query = load_file_content($file);
    my $sql = prepare_query($query);

    push @data, [ run_query($sql) ];
}

#generate xlsx file from data
my $path = cwd; #current working directory
my $filename = "report-$prefix-$month-$year.xlsx";

my $xlsx = Excel::Grinder->new($path);
my $file = $xlsx->write_excel(
    'filename' => $filename,
    'headings_in_data' => 1,
    'worksheet_names' => [ sort keys %queries ],
    'the_data' => [
        @data
    ],
);


sub prepare_query {
    my ($query) = @_;

    #make sql query
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

    #get field names
    my $fields = $sth->{NAME_lc};

    my @data = ();

    #add field names as the first row
    push @data, $fields;

    while(my $row = $sth->fetchrow_hashref()){
        my @vals = ();

        #using $fields to ensure the values come in the same order for each row
        push @vals, $_ foreach map { $row->{$_} } $fields->@*;

        push @data, \@vals;
    }

    $sth->finish;
    $dbh->disconnect;

    return @data;
}

sub load_file_content {
    my ($file) = @_;
    my $content;
    open my $fh, '<', $file
        or die "Could not open file $file: $!";
    while(my $line = (<$fh>)){
        $content.= $line;
    }
    close $fh;
    return $content;
}
