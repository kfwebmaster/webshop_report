#! perl

use warnings; use strict; 

#dependencies
use Cwd qw( cwd );
use DBI;
use Excel::Grinder;
use Data::Dumper;

#load variables in .env into $env
my %env = ();
open my $fh, "<", ".env";
while(<$fh>){
    chomp;
    m{
        \A              
        (?<key>[a-z A-Z 0-9 _-]+)   #key
        \s*=\s*                     #=
        (?<q>['"]?)                 #optional quotes
        (?<val>[^'"]*)              #value
        \k<q>?                      #same quote character as before
        \z
    }xx;

    $env{$+{'key'}} = $+{'val'} if defined $+{'key'} and defined $+{'val'};
}
close $fh;


#set up defaults for switches
my @now = localtime;

#year starts at 1900
#month is index (starts at 0)
my ($month, $year, $prefix) = ($now[4], 1900+$now[5], 'wp_');
#change month 0 to december previous year
if ($month == 0) {
    $month = 12; 
    $year--;
}


my $dbh = DBI->connect($env{'DATA_SOURCE'}, $env{'DB_USERNAME'}, $env{'DB_PASSWORD'})
    or die "failed to connect to database\n";

my $sql = qq(
WITH postmeta AS (
    SELECT post_id
        ,MAX(CASE WHEN meta_key = '_sku'            THEN meta_value ELSE '' END) AS sku
        ,MAX(CASE WHEN meta_key = '_tax_status'     THEN meta_value ELSE '' END) AS tax_status
        ,MAX(CASE WHEN meta_key = '_wc_cog_cost'    THEN meta_value ELSE '' END) AS cost
        ,MAX(CASE WHEN meta_key = '_price'          THEN meta_value ELSE '' END) AS price
        ,MAX(CASE WHEN meta_key = '_stock'          THEN meta_value ELSE '' END) AS stock
    FROM wp_postmeta 
    WHERE meta_key IN ('_sku', '_tax_status', '_wc_cog_cost', '_price', '_stock')
    GROUP BY post_id
)
,order_items AS (
    SELECT oi.order_id
        ,oi.order_item_id
        ,MAX(CASE WHEN oim.meta_key = '_qty'        THEN ABS(oim.meta_value) ELSE 0 END)    AS quantity 
        ,MAX(CASE WHEN oim.meta_key = '_line_total' THEN ABS(oim.meta_value) ELSE 0 END)    AS line_total 
        ,MAX(CASE WHEN oim.meta_key = '_line_tax'   THEN ABS(oim.meta_value) ELSE 0 END)    AS line_tax 
        ,MAX(CASE WHEN oim.meta_key = '_product_id' THEN oim.meta_value ELSE '' END)        AS product_id 
    FROM wp_woocommerce_order_items oi
    INNER JOIN wp_woocommerce_order_itemmeta oim ON oi.order_item_id = oim.order_item_id 
    WHERE 1 = 1
        AND meta_key IN ('_qty', '_line_total', '_line_tax', '_product_id')
        AND oi.order_item_type = 'line_item'
    GROUP BY order_item_id
)
,shop_order AS (
    SELECT id 
        ,post_date AS order_date
        ,CASE WHEN post_type    = 'shop_order_refund' 
                OR post_status  = 'wc-refunded' 
        THEN 1 ELSE 0 END AS refund
    FROM wp_posts 
    WHERE 1 = 1
        AND post_type       IN ('shop_order', 'shop_order_refund')
        AND post_status     IN ('wc-completed', 'wc-processing', 'wc-refunded') 
)
,postterms AS (
    SELECT object_id
        ,term_tax.taxonomy
        ,terms.`name`
    FROM wp_term_relationships term_rel 
    JOIN wp_term_taxonomy term_tax  ON term_tax.term_taxonomy_id    = term_rel.term_taxonomy_id  
    JOIN wp_terms terms             ON terms.term_id                = term_tax.term_id 
)
,product AS (
    SELECT p.id 
        ,p.post_title AS title
        ,postmeta.sku
        ,postmeta.tax_status
        ,postmeta.cost
        ,postmeta.price
        ,postterms.`name` AS category
        ,SUM(IFNULL(vm.stock, postmeta.stock)) AS total_stock
    FROM wp_posts p 
    LEFT JOIN postmeta      ON postmeta.post_id     = p.id
    LEFT JOIN postterms     ON postterms.object_id  = p.id AND postterms.taxonomy   = 'product_cat'
    LEFT JOIN wp_posts v    ON v.post_parent        = p.id AND v.post_type          = 'product_variation'
    LEFT JOIN postmeta vm   ON vm.post_id           = v.id
    WHERE p.post_type = 'product'
    GROUP BY p.id 
)
,sales AS (
    SELECT product.id
        ,product.title
        ,product.sku
        ,product.tax_status
        ,product.cost
        ,(ABS(order_items.line_total) + ABS(order_items.line_tax)) / ABS(order_items.quantity) AS price_point
        ,SUM(order_items.quantity) AS quantity
        ,SUM(order_items.line_total) AS line_total
        ,SUM(order_items.line_tax) AS line_tax
        ,shop_order.refund
        ,product.category
        ,CONCAT(YEAR(shop_order.order_date),'-',MONTH(shop_order.order_date)) AS period
        ,product.total_stock
    FROM shop_order
    INNER JOIN order_items  ON order_items.order_id = shop_order.id
    INNER JOIN product      ON product.id           = order_items.product_id 
    GROUP BY product.id
        ,ROUND(order_items.line_total / order_items.quantity, 2)
        ,product.tax_status
        ,product.sku
        ,shop_order.refund
        ,CONCAT(YEAR(shop_order.order_date),'-',MONTH(shop_order.order_date))
)






#generate sales report for a month
SELECT 
    title                               AS `product_title` 
    ,sku
    ,CONCAT('=', REPLACE(SUM(
        quantity * IF(refund, -1, 1)
    ), '.', ','))                       AS `quantity` 
    ,CONCAT('=', REPLACE(ROUND(SUM(
        line_total * IF(refund, -1, 1)
    ), 2), '.', ','))                   AS `net_sales` 
    ,CONCAT('=', REPLACE(ROUND(SUM(
        (line_total + line_tax) 
        * IF(refund, -1, 1)
    ), 2), '.', ','))                   AS `gross_sales`
    ,CONCAT('=', REPLACE(ROUND(SUM(
        line_tax * IF(refund, -1, 1)
    ), 2), '.', ','))                   AS `total_vat` 
    ,tax_status
    ,CONCAT('=', REPLACE(ROUND(
        price_point
    , 2), '.', ','))                    AS `price`
    ,CONCAT('=', REPLACE(ROUND(
        cost
    , 2), '.', ','))                    AS `cost`
    ,category
    ,total_stock                        AS `stock`
FROM sales

WHERE period = '$year-$month'

GROUP BY sku
    ,title
    ,tax_status
    ,cost
    ,price_point
    ,category
    ,period

ORDER BY sku DESC
);

my $sth = $dbh->prepare($sql)
    or die "prepare statement failed: $dbh->errstr()";
$sth->execute() or die "execution failed: $dbh->errstr()";

my @overview = [
    'Product name', 
    'SKU',
    'Number sold',
    'Net sales',
    'Gross sales',
    'Total VAT',
    'Tax status',
    'Price including tax',
    'Cost',
    'Product category',
    'Remaining inventory'
];

while(my (
    $product_title, 
    $sku, 
    $quantity, 
    $net_sales,
    $gross_sales, 
    $total_vat, 
    $tax_status, 
    $price, 
    $cost, 
    $category,
    $stock
) = $sth->fetchrow()){
    push @overview, [
        $product_title, 
        $sku, 
        $quantity, 
        $net_sales,
        $gross_sales, 
        $total_vat, 
        $tax_status, 
        $price, 
        $cost, 
        $category,
        $stock
    ];
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
        \@overview
    ],
);

