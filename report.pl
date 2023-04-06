#!/usr/bin/perl -s -w
use strict;
use File::Basename qw<basename>;

our
(   $month, $year, $prefix
,   $h => $help
,   $v => $verbose
);              # optional switches
my $sep = '/';  # path separator

BEGIN
{   my $script = basename($0);
    my $usage = "Usage: $script [-month=M -year=Y -prefix=xxx -h[elp] ]\n";

    $h //= $help;
    $v //= $verbose;
    $h and warn $usage and exit 0;

    # validate switches, if provided
    # avoid compilation error by using warn and exit instead of die
    $month  and $month  !~ /^\d[0-2]?$/ and warn $usage and exit 1;
    $year   and $year   !~ /^\d{4}$/    and warn $usage and exit 1;
    $prefix and $prefix !~ /^\w+$/      and warn $usage and exit 1;

    # defaults
    my @now = localtime;
    $month  or $month = $now[4];                # month starts at 0, we leave it alone to default to prev month
    $year   or $year = $now[5]+1900;            # year starts at 1900
    $prefix or $prefix = 'wp_';                 # default wordpress prefix

    $month == 0 and $month = 12 and $year--;    # change month 0 to december the previous year

    $^O eq 'MSWin32' and $sep = '\\';           # change path separator for windows

    push @INC, '.' . $sep . 'lib' . $sep;       # load modules from /lib

    $v and warn "Making report for $month/$year for site $prefix\n";
}

# load modules
use Cwd qw<cwd>;
use DBI;
use Excel::Grinder;
use Dotenv;         # custom module since the one on CPAN doesnt work on windows

my %dotenv = Dotenv::Parse; # load dbi credentials from .env

# load list of query files
my @queries = glob "queries$sep*.sql";
0 < @queries or die "No files found in queries$sep. ";

# run queries and add data
my @data;
foreach my $file (@queries){
    my $query = load_file_content($file);
    my $sql   = prepare_query($query);
    my @rows  = run_query($sql);
    $v and warn "Found ", scalar @rows, " rows when running $file\n";
    push @data, \@rows;
}

# generate sheet names from query filenames
# queries/sales.sql -> Sales
my @sheets = map { s|^queries$sep(\w+)\.sql$|\u$1|r } @queries;

$v and warn "Report contains the following sheets: @sheets\n";

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
my $file = $xlsx->write_excel(
    'filename'          => $filename,
    'headings_in_data'  => 1,
    'worksheet_names'   => \@sheets,
    'the_data'          => \@data,
);

$v and warn "Report saved as $filename\n";


####### subroutines #######

sub load_file_content
{   my ($file) = @_;
    local $/ = undef;
    open my $fh, '<', $file or die "Could not open file $file: $!";
    my $content = <$fh>;
}

{   my $base_sql;
    sub prepare_query {
        $base_sql //= load_file_content('base.sql');
        my ($query) = @_;

        my $sql = "$base_sql\n$query";

        # insert month, year, and prefix into query
        # \Q turns off metachars, so that '{}' can be used without escaping
        $sql =~ s/\Q{{month}}/$month/g;
        $sql =~ s/\Q{{year}}/$year/g;
        $sql =~ s/\Q{{prefix}}/$prefix/g;

        return $sql;
    }
}

sub run_query {
    my ($sql) = @_;

    # connect to database and run query
    my $dbh = DBI->connect($dotenv{'DATA_SOURCE'}, $dotenv{'DB_USERNAME'}, $dotenv{'DB_PASSWORD'})
        or die "failed to connect to database\n";
    my $sth = $dbh->prepare($sql)
        or die "prepare statement failed: $dbh->errstr()";
    $sth->execute()
        or die "execution failed: $dbh->errstr()";

    # get field names and add as the first row
    my $fields = $sth->{NAME_lc};
    my @data = ();
    push @data, $fields;

    # add values from each row
    while(my $row = $sth->fetchrow_hashref()){
        push @data, [ map { $row->{$_} // '' } $fields->@* ];
    }

    $sth->finish;
    $dbh->disconnect;
    return @data;
}
