# webshop report generating script

## usage 

### preparation (first time)

0. set up .env file with credentials for the database

### generate report (every time)

1. run tunnel.bat
    _this makes a ssh tunnel to the servebolt server_
2. run report.pl
    _this makes the connection to the database, through the tunnel and fetches the data, generates the report and saves it to an Excel-compatible format_
