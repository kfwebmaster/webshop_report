## description

this script generates a sales report for a specified month from a woocommerce webshop.

the report is saved in .xlsx format.

## requirements

- perl
- cpan modules:     
    - DBI
    - DBD::MariaDB
    - Excel::Grinder
    - Cwd

## how to use

### first time:

1. duplicate `.env-sample` to `.env`
2. add database credentials to `.env`

### every time:

1. set up ssh tunnel if needed
2. run `report.pl` to generate report

**syntax and examples:**

```
.\report.pl [-month=M -year=Y -prefix=xx]
```

all switches are optional. 

by default, the script generates report for the last month using prefix `wp_` 

the command below generates report for august 2021 for site 2 in a multisite WP

```
.\report.pl -month=8 -year=2021 -prefix=wp_2_
```

## ssh tunneling

**software:**

- plink
- pageant

_installing Putty will also install plink and pageant_

**preparations:**

1. duplicate `.tunnel-sample.bat` to `tunnel.bat`
2. add server connection to `tunnel.bat` 
3. generate an RSA key and add it to `.ssh\authorized_keys` on the server

**set up connection:**

1. run pageant and add private RSA key
2. run `tunnel.bat` to set up an ssh tunnel to the server

## misc

the Dotenv module on cpan is not used because it does not work on windows
