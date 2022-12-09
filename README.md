# webshop report generating script

## usage 

this script generates a sales report from the webshop for a specified month.

the report is saved as an excel file.


### preparation (first time)

1. rename `.env-sample` to .env and add credentials for the database
2. install plink and pageant - _by installing Putty_
3. generate an RSA key and add it to `.ssh\authorized_keys`

### generate report (every time)

1. run pageant and add key
2. run tunnel.bat to set up an ssh tunnel to the server
3. run report.pl to generate report

## syntax and examples

syntax for report.pl: 

```
report.pl [-month=M -year=Y -prefix=xx]
```

all switches are optional. 

by default, the script generates report for the last month using prefix `wp_` 

the command below generates report for august 2021 for site 2 in multisite WP

```
report.pl -month=8 -year=2021 -prefix=wp_2_
```


