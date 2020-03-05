[Node.js](https://nodejs.org/) is typically installed as a standalone container without any other external dependencies. Under the hood, Node runs within the same [V8 JavaScript Engine](https://v8.dev/) that the Google Chrome, Microsoft Edge and many other web browsers use. Node is also [non-blocking](https://nodejs.org/en/docs/guides/blocking-vs-non-blocking/) which essentially translates to a [substantial increase I/O throughput](https://nodejs.org/en/about/). A typical non-blocking web application will run much faster and use a lot less memory than their blocking counterparts. Node achieves this through what is referred to as an event-loop. Instead of spawning a new thread on every request, node's event-loop handles queued requests withing a single thread. There are, however many threads running within a single node process that handle things like file system I/O, [worker threads](https://nodejs.org/dist/latest/docs/api/worker_threads.html) created by the application itself for computational heavy operations, etc. These aspects of node, among other benefits such as server/browser code re-usability, feature specific hot deployments, etc. help make Node an ideal choice for the web.

# Node.js Installation:
There are a few different ways to install Node.js. The most flexible is to use [nvm (Node Version Management)](https://github.com/nvm-sh/nvm) so that multiple versions of Node can run on a single box. The other is to install a single instance of Node globally for all users.

## Multiple Node versions (using [nvm](https://github.com/nvm-sh/nvm)):
There are two recommended ways to install [nvm](https://github.com/nvm-sh/nvm). One is to install `nvm` globally so that it is accessible to all users. The other is to install nvm using the local user account.

### Global nvm (install/upgrade):
```sh
sudo su
# install/upgrade C/C++ compiler for native Node modules
yum install -y gcc-c++ make
# ensure there is a bash profile
touch ~/.bash_profile
# installs/updates nvm (node version management, replace ### with the nvm version- e.g. 0.35.2)
mkdir -p /usr/local/nvm && curl -o- https://raw.githubusercontent.com/creationix/nvm/v###/install.sh | NVM_DIR=/usr/local/nvm bash && source ~/.profile
# install latest LTS node.js version
nvm install lts/*
# verify default node version
node -v
```

### Local nvm (install/upgrade):
```
sudo su
# install/upgrade C/C++ compiler for native Node modules
yum install -y gcc-c++ make
# ensure there is a bash profile
touch ~/.bash_profile
# installs/updates nvm (node version management, replace ### with the nvm version- e.g. 0.35.2)
mkdir -p /usr/local/nvm && curl -o- https://raw.githubusercontent.com/creationix/nvm/v###/install.sh | NVM_DIR=/usr/local/nvm bash && source ~/.profile
# install latest LTS node.js version
nvm install lts/*
# verify default node version
node -v
```

## Single Node Version
To install/upgrade Node globally for accessibility across all users, follow the steps below.

### Global Node Install:
```sh
# globally install single version of node
sudo su
curl -sL https://rpm.nodesource.com/setup_##.x | sudo -E bash -
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

| DBMS          | Node.js Module                                                                                 | Language
| Oracle        | [oracledb](https://oracle.github.io/node-oracledb/)                                            | C/C++
| MS SQL Server | [tedious](https://docs.microsoft.com/en-us/sql/connect/node-js/node-js-driver-for-sql-server)  | C/C++/[MS-TDS](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/b46a581a-39de-4745-b076-ec4dbb7d13ec)
| ODBC          | [odbc](https://www.npmjs.com/package/odbc)                                                     | C/C++ (see ODBC)

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

### POSIX
```sh
[Unit]
Description=hello_env.js - making your environment variables rad
Documentation=https://example.com
After=network.target
# Wants=redis.service

[Service]
Environment=NODE_PORT=3001
Type=simple
User=ubuntu
ExecStart=/usr/bin/node /home/ubuntu/hello_env.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
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
