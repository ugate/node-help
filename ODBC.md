### Linux
ODBC connectivity on Linux can be accomplished using the [unixODBC](http://www.unixodbc.org/) implementation of ODBC. Execute the following commands to install/setup ODBC using the credentials provided for the database connection being installed.

```sh
# Example using Intersystems Cachè
sudo su
# download/extract the driver files
mkdir -p /usr/cachesys && curl -L ftp://ftp.intersystems.com/pub/cache/odbc/2018/ODBC-2018.1.2.309.0-lnxrhx64.tar.gz | tar -C /usr/cachesys -zxv
# install unixODBC and unixODBC-devel
# sudo apt-get update -y && sudo apt-get install -y unixodbc unixodbc-dev
yum install unixODBC unixODBC-devel
# check for the loc of the odbc.ini file(s)
odbcinst -j
# using the loc of the System Data Sources from the prior step, edit the odbc.ini to add the driver config (see subsequent supplement)
vi /etc/odbc.ini
# check the connection using single quotes around the password (CTRL + C to exit isql)
isql -v Labdash svc_myusername 'INSERT_REAL_PASSWORD_HERE'
```

Example/supplemental __odbc.ini__ [configuration for Cachè](https://cedocs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls?KEY=BGOD_unixodbc):

```ini
[ODBC Data Sources]
Cache=Cache
 
[Cache]
Driver=/usr/cachesys/bin/libcacheodbc35.so
Description=Cache (TEST)
Host=example.com
Namespace=MY_DB
UID=svc_myusername
Password=INSERT_REAL_PASSWORD_HERE
Port=41000
Protocol=TCP
Query Timeout=1
Static Cusrsors=0
Trace=off
TraceFile=iodbctrace.log
Authentication Method=0
Security Level=2
Service Principal Name=example.com
 
[Default]
Driver=/usr/cachesys/bin/libcacheodbc35.so
```
