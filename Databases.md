DATABASES

Mariadb install perfectly. Can use these installation recommendations. Postgresql - no.

Mariadb https://www.percona.com/blog/2017/12/07/hands-look-zfs-with-mysql/

~~~
apt install mariadb-server -y
systemctl stop mysql
mkdir /{sql-log,sql-data}

mv /var/lib/mysql/ib_logfile* /sql-log/
mv /var/lib/mysql/aria* /sql-log/
mv /var/lib/mysql/* /sql-data

zfs create -o canmount=noauto -o mountpoint=/var/lib/mysql rpool/USERDATA/mysql
zfs create -o recordsize=16k -o primarycache=metadata rpool/USERDATA/mysql/mysql-data
zfs create rpool/USERDATA/mysql/mysql-log

mv /sql-log/* /var/lib/mysql/mysql-log
mv /sql-data/* /var/lib/mysql/mysql-data


chown mysql:mysql -R /var/lib/mysql
chown root:root /var/lib/mysql/mysql-data/{mysql_upgrade_info,*.flag}
~~~
edit /etc/mysql/mariadb.conf.d/50-server.cnf  
change values;
log_error = /var/lib/mysql/mysql-log/error.log  
server-id = 1  
log_bin = /var/lib/mysql/mysql-log/binlog  
slow_query_log_file = /var/lib/mysql-log/slow.log  
datadir = /var/lib/mysql/mysql-data  
  

ADD these new lines to [mysqld]:  
innodb_log_group_home_dir = /var/lib/mysql/mysql-log  
innodb_doublewrite = 0  
innodb_checksum_algorithm = none  
  
relay_log=/var/lib/mysql-log/relay-bin  

symbolic-links=0  

innodb_log_write_ahead_size = 16384  
innodb_use_native_aio = 0  
innodb_use_atomic_writes = 0  
aria-log-dir-path = /var/lib/mysql/mysql-log  
log_warnings = 3  

Securing:
https://www.digitalocean.com/community/tutorials/how-to-install-mariadb-on-ubuntu-20-04





POSTGRESQL

For optimization, build from source :/ There is not other way. Or install default from ubunu source. It's not hurts.
UPDATE: hurts compilation from source. Compiling without issues, but regresion tests failed. After some experiments found that can # change only one blocksize - data or wal. both - no. Event installation from repositories, I think is good to reduce zfs recordsize for data to 32k, for wal - 64 k.

PostgreSQL block size to 32k and WAL block size to 64k
apt install build-essential zlib1g-dev libreadline6-dev
OPTIMAL: for systemd support apt install libsystemd-dev
for nls (native language support, others than english) apt install gettext

cd
wget https://ftp.postgresql.org/pub/source/v13.4/postgresql-13.4.tar.gz
tar xf v13.4/postgresql-13.4.tar.gz
cd postgresql-13.4
add languages or remove --enable-nls='de lt'

./configure --prefix=/usr/local --exec-prefix=/usr/local --with-blocksize=32 --with-wal-blocksize=64 --with-systemd --enable-nls='de lt' --with-llvm

this will make and additional modules (contrib). Without contrib, remove world-bin
make world-bin

make check


zfs create -o canmount=noauto -o mountpoint=/var/lib/postgresql rpool/USERDATA/postgresql
zfs create -o recordsize=32k -o redundant_metadata=most rpool/USERDATA/postgresql/psql-data
zfs create -o recordsize=64k -o redundant_metadata=most rpool/USERDATA/postgresql/psql-wal

su postgres
initdb -D /var/lib/postgresql/psql-data -U postgres -X /var/lib/postgresql/psql-wal
pg_ctl -D /var/lib/postgresql/psql-data/ -l /var/lib/postgresql/start.log start
