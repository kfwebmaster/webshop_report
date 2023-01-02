# webshop report generating script

## usage 

this script generates a sales report from the webshop for a specified month.

the report is saved in .xlsx format

### prerequisites

- perl
- cpan modules:     
    - DBI
    - DBD::MariaDB
    - Excel::Grinder
    - Cwd
- plink
- pageant

_installing Putty will also install plink and pageant_

### preparation (first time)

1. duplicate `.tunnel-sample.bat` to `tunnel.bat`, and add server connection
2. duplicate `.env-sample` to `.env`, and add database credentials
3. generate an RSA key and add it to `.ssh\authorized_keys` on the server

### generate report (every time)

1. run pageant and add private RSA key
2. run `tunnel.bat` to set up an ssh tunnel to the server
3. run `report.pl` to generate report

## syntax and examples

syntax for report.pl: 

```
.\report.pl [-month=M -year=Y -prefix=xx]
```

all switches are optional. 

by default, the script generates report for the last month using prefix `wp_` 

the command below generates report for august 2021 for site 2 in a multisite WP

```
.\report.pl -month=8 -year=2021 -prefix=wp_2_
```

## other

the Dotenv module on cpan is not used because it does not work on windows
