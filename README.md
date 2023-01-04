## Description

This script generates a sales report for a specified month from a WooCommerce webshop.

The report is saved in .xlsx format.

## Required software

- perl
- cpan modules:
    - DBI
    - Excel::Grinder
    - Cwd

## Optional software

- cpan modules
    - DBD::MariaDB
- plink
- pageant

## How to use

### Set up project

1. Copy all files from `sample/` dir to project root
2. Add database credentials to `.env` file in root

### Generate report

1. set up ssh tunnel if needed
2. run `report.pl` to generate report

**Syntax and examples:**

```
.\report.pl [-month=M -year=Y -prefix=xx]
```

All switches are optional.

By default, the script generates report for the last month using prefix `wp_`.

The command below generates report for august 2021 for site 2 in a multisite WP.

```
.\report.pl -month=8 -year=2021 -prefix=wp_2_
```

## How it works

### base.sql

MySQL does not have the `PIVOT` feature I've grown to love in PostgresSQL and MSSQL. This is especially annoying when working with WordPress and WooCommerce, since most data is stored in "unpivoted" tables.

The `base.sql` file (provided under `sample/`) preloads an SQL query with some useful _shortcuts_ for pivoting and simplifying queries for WordPress and WooCommerce.

**Instead of this:**
```SQL
SELECT id
    ,post_title                                                         AS title
    ,MAX(CASE WHEN meta_key = '_sku'    THEN meta_value ELSE '' END)    AS sku
    ,MAX(CASE WHEN meta_key = '_price'  THEN meta_value ELSE '' END)    AS price
FROM wp_posts
LEFT JOIN wp_postmeta ON post_id = id AND meta_key IN ('_sku', '_price')
WHERE post_type = 'product'
GROUP BY id
```

**We can do this:**
```SQL
SELECT id, title, sku, price FROM product
```

To allow selection of prefix when generating reports, the sql files have `{{prefix}}` in place of `wp_` in all table names. This gets replaced before the queries are run. The same is done with `{{year}}` and `{{month}}`.

### report.pl

The `report.pl` builds a query from `base.sql` and each of the queries under `queries/` in turn and runs them. Each set of results is added as a worksheet to an xlsx file using `Excel::Grinder` and saves the file under `output/`.

The script relies on `DBI` which does not support multiple statements in a single query. We're assuming the use of `MariaDB` since it is more reliable, even for MySQL servers, but this is not required.

## SSH tunneling

**Software:**

- plink
- pageant

_Installing Putty will also install plink and pageant_

**Preparations:**

1. add server connection to `tunnel.bat`
2. generate an RSA key and add it to `.ssh\authorized_keys` on the server

**Set up connection:**

1. run pageant and add private RSA key
2. run `tunnel.bat` to set up an ssh tunnel to the server

## Misc

the Dotenv module on cpan is not used because it does not work on windows
