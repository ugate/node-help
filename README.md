[Node.js](https://nodejs.org/) is typically installed as a standalone container without any other external dependencies. Under the hood, Node runs within the same [V8 JavaScript Engine](https://v8.dev/) that the Google Chrome, Microsoft Edge and many other web browsers use. Node is also [non-blocking](https://nodejs.org/en/docs/guides/blocking-vs-non-blocking/) which essentially translates to a [substantial increase I/O throughput](https://nodejs.org/en/about/). A typical non-blocking web application will run much faster and use a lot less memory than their blocking counterparts. Node achieves this through what is referred to as an event-loop. Instead of spawning a new thread on every request, node's event-loop handles queued requests withing a single thread. There are, however many threads running within a single node process that handle things like file system I/O, [worker threads](https://nodejs.org/dist/latest/docs/api/worker_threads.html) created by the application itself for computational heavy operations, etc. These aspects of node, among other benefits such as server/browser code re-usability, feature specific hot deployments, etc. help make Node an ideal choice for the web.

# Node.js Installation:
There are a few different ways to install Node.js. The most flexible is to use [nvm (Node Version Management)](https://github.com/nvm-sh/nvm) so that multiple versions of Node can run on a single box (local user account). The other is to install a single instance of Node globally for all users.

## Multiple Node versions (using [nvm](https://github.com/nvm-sh/nvm)):
Installing [nvm](https://github.com/nvm-sh/nvm) will allow switching back and forth between `node` versions from the command line. By default, `nvm` is installed locally under the current user account.

### Local user nvm (install/upgrade):
```
# see https://access.redhat.com/sites/default/files/attachments/rh_yum_cheatsheet_1214_jcs_print-1.pdf
sudo su
# install/upgrade C/C++ compiler for native Node modules
# apt-get install -y gcc-c++ make
yum install -y gcc-c++ make
# optionally switch to the user acct where nvm will be installed
# su someuser
# ensure there is a bash profile
touch ~/.bash_profile
# installs/updates nvm (node version management)
# replace ### with the nvm version- e.g. 0.35.2)
curl -o- https://raw.githubusercontent.com/creationix/nvm/v###/install.sh | bash
# activate nvm (alt reload terminal)
source ~/.bashrc
# install latest LTS node.js version
nvm install lts/*
# verify default node version
node -v
```

## Single Node Version
To install/upgrade Node globally for accessibility across all users, follow the steps below.

### Global Node Install:
```sh
# see https://access.redhat.com/sites/default/files/attachments/rh_yum_cheatsheet_1214_jcs_print-1.pdf
# globally install single version of node
sudo su
curl -sL https://rpm.nodesource.com/setup_##.x | sudo -E bash -
# apt-get intall -y nodejs
yum install -y nodejs
```

### Global Node Update:
```sh
# globally install single version of node
sudo su
rm -rf /var/cache/yum
yum remove -y nodejs
rm /etc/yum.repos.d/nodesource*
yum clean all
curl --silent --location https://rpm.nodesource.com/setup_##.x | sudo bash -
yum -y install nodejs
```

## Database Connectivity

There are a few different options for database connectivity within Node for DBMS, NoSQL, GDB (Graph Database), etc.  When dealing with DBMS, many vendors like Oracle, MS SQL Server, etc. provide their own native and/or protocol-specific drivers. Native drivers provided by implementing vendors are the preferred method for DBMS connectivity within Node since they provide maximum performance and feature sets. However, there are some vendors that provide alternative ODBC drivers, OLE DB drivers, etc. which can provide a near-native experience when direct native driver implementations are not provided by a specific database vendor. Below are few of the most commonly used database drivers provided by various database vendors:

| DBMS          | Node.js Module                                                                                 | Driver
| :---          | :---:                                                                                          | :---
| PostgreSQL    | [sqler-postgres](https://ugate.github.io/sqler-postgres)                                       | [pg](https://www.npmjs.com/package/pg)
| MySQL/MariaDB | [sqler-mdb](https://ugate.github.io/sqler-mdb)                                                 | [mariadb](https://www.npmjs.com/package/mariadb)
| MS SQL Server | [sqler-mssql](https://ugate.github.io/sqler-mssql)                                             | [mssql](https://www.npmjs.com/package/mssql)
| Oracle        | [sqler-oracle](https://ugate.github.io/sqler-oracle)                                           | [oracledb](https://www.npmjs.com/package/oracledb)
| ODBC          | [sqler-odbc](https://ugate.github.io/sqler-odbc)                                               | [odbc](https://www.npmjs.com/package/odbc) ([see ODBC](ODBC.md))

## Application Installation/Deployment
Each node application can be scaled vertically by deploying multiple node application processes that match the number of physical CPUs allocated on the physical server where the application resides. Each of those processes should reference the same code base and remain stateless throughout the application's life-cycle. This helps to ensure consistency across application deployments and enables the possibility for zero-downtime for potential application upgrades.

Application/service deployment instances should contain separate environmental variables that control accessibility and how each vertically scaled process interacts with internal database connections, services, etc. Consider the following deployment for a single application/service that assumes two physical CPU cores (typically there will be more than two, but the example uses only two for illustrative purposes):

```sh
NODE_ENV=test
NODE_HOST=127.0.0.1
NODE_PORT=9090
```
```sh
NODE_ENV=test
NODE_HOST=127.0.0.1
NODE_PORT=9091
```

Each process instance should point to the same directory where the application/service is deployed. The application can review the set environmental variables via "process.env.NODE_ENV" and perform setup tasks accordingly.

### Service Installation<sub id="service"></sub>
As discussed earlier, the number of `node` processes for a particular app should match the number of physical CPU cores for optimal performance. A service can be setup using `systemd`/`systemctl` using a single `/etc/systemd/system/myapp@.service` to achieve multiple app instances running on different ports. The `@` symbol indicates that there will be multiple instances of the same `systemd` _unit_ will be ran. The following service demonstrates the use of a single `.service` for all of the node processes that will be spawned (see [`systemd` specifiers](https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Specifiers)).

> The `WorkingDirectory` should contain a [`.nvmrc` file](https://github.com/nvm-sh/nvm#nvmrc) that contains `lts/CODE_NAME` where `CODE_NAME` is a valid value from [Node.js codenames](https://github.com/nodejs/Release/blob/master/CODENAMES.md). This will ensure that the app will be constrained to the desired major node version (e.g. `lts/fermium` would run the latest version of `14.x`).

```sh
# /etc/systemd/system/myapp@.service
[Unit]
Description="My Node App (%H:%i)"
Documentation=https://example.com
After=network.target
# Wants=redis.service
PartOf=myapp.target

[Service]
Environment=NODE_ENV=test
Environment=NODE_HOST=%H
Environment=NODE_PORT=%i
Type=simple
# user should match the user where nvm was installed
User=someuser
WorkingDirectory=/opt/apps/myapp
# run node using the node version defined in working dir .nvmrc
ExecStart=/bin/bash -c '~/.nvm/nvm_exec node .'
Restart=on-failure
RestartSec=5
StandardError=syslog

[Install]
WantedBy=multi-user.target
```
For convenience, a `myapp.target` file can be used so the target can be indicated instead of all of the `myapp@.service` instances (e.g. `systemctl start myapp@9090.service`, `systemctl start myapp@9091.service`, etc.).

```sh
# /etc/systemd/system/myapp.target
[Unit]
Description="My Node App"
Wants=myapp@9090.service myapp@9091.service myapp@9092.service myapp@9093.service

[Install]
WantedBy=multi-user.target
```

Now all that's left is to install/run the service(s).
```sh
# check that the selected target ports are not in use
sudo ss -tulwn
# write the service contents
sudo vi /etc/systemd/system/myapp@.service
# write the target contents
sudo vi /etc/systemd/system/myapp.target
# reload the systemd configuration
sudo systemctl daemon-reload
# enable the target/service
sudo systemctl enable myapp.target
# start the target (could also start each service individually: sudo systemctl start myapp@9090.service)
sudo systemctl start myapp.target
# check the status of the target/services
systemctl status myapp.target
systemctl status myapp@9090.service myapp@9091.service myapp@9092.service myapp@9093.service
```

To check the logs/output for a `target`/`service`:

```sh
# the entire log for the target/service
journalctl -u myapp@9090.service
# the log since the last boot for the target/service
journalctl -u myapp@9090.service -b
# the end of the log for the target/service
journalctl -u myapp@9090.service -e
```

## Redis installation:
Redis is an in-memory database that is typically used in conjunction with Node applications/microservices in order to achieve autonomy between vertically and horizontally scaled Node application processes. Redis is typically much more efficient at delegating and managing resources for things like sessions, temporary objects, etc. than an application memory space. Redis also will enable users of an application to remain logged in between application/service restarts.

```sh
# install
sudo yum install -y redis
# enable/start redis service
sudo systemctl enable --now redis
# check that port 6379/TCP is open in the firewall
sudo iptables -S
# search redis.conf, uncomment "requirepass" and set value
# requirepass REDIS_PASSWORD_HERE
sudo vi /etc/redis.conf
sudo systemctl restart redis.service
# check status of redis service (ping should return PONG)
sudo systemctl status redis.service
redis-cli -a 'REDIS_PASSWORD_HERE' ping
```

# Continuous Integration/Deployment
An automated/portable shell [node-app.sh](https://github.com/ugate/repo/tree/master/nodejs) can be used for CICD.