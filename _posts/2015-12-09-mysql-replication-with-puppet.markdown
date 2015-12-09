---
layout: post
status: publish
published: true
title: MySQL Replication with (Mostly) Puppet
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---


Nothing ground breaking here, but I had to struggle getting master-slave replication with 
[Puppet](https://puppetlabs.com/) going in [Vagrant](https://www.vagrantup.com/) to test something, 
so I decided to put together a short tutorial in case it's useful to others (and in case
I ever need to do this again and need something to refer back to).

<!--more-->

Follow along below, and you'll end up with two nodes managed by vagrant (named `mysqlmaster` and `mysqlslave`) that
are wired up to replicate a database named `demo`. 

Unfortunately, Puppet can only get us to having a node configured as a master and another as a slave.
We still have to shell in there to get them talking to each other.

## Getting Started

	git clone https://github.com/benschw/mysql-replication-vagrant.git
	cd mysql-replication-vagrant
	./deps.sh   
	vagrant up  

_`./deps.sh` clones the mysql-puppet module and its dependencies._


This will configure your two nodes with MySQL, setting one up as a master (`mysqlmaster`/`172.10.10.10`)
and the other as a slave (`mysqlslave`/`172.10.20.10`).

### MySQL Master
The puppet code we are applying to `mysqlmaster`

	class mysqlprofile::mysqlmaster {

	  class { 'mysql::server':
		restart          => true,
		root_password    => 'changeme',
		override_options => {
		  'mysqld' => {
			'bind_address'                   => '0.0.0.0',
			'server-id'                      => '1',
			'binlog-format'                  => 'mixed',
			'log-bin'                        => 'mysql-bin',
			'datadir'                        => '/var/lib/mysql',
			'innodb_flush_log_at_trx_commit' => '1',
			'sync_binlog'                    => '1',
			'binlog-do-db'                   => ['demo'],
		  },
		}
	  }

	  mysql_user { 'slave_user@%':
		ensure        => 'present',
		password_hash => mysql_password('changeme'),
	  }

	  mysql_grant { 'slave_user@%/*.*':
		ensure     => 'present',
		privileges => ['REPLICATION SLAVE'],
		table      => '*.*',
		user       => 'slave_user@%',
	  }

	  mysql::db { 'demo':
		ensure   => 'present',
		user     => 'demo',
		password => 'changeme',
		host     => '%',
		grant    => ['all'],
	  }
	}


### MySQL Slave
The puppet code we are applying to `mysqlslave`

	class mysqlprofile::mysqlslave {

	  class { 'mysql::server':
		restart          => true,
		root_password    => 'changeme',
		override_options => {
		  'mysqld' => {
			'bind_address' => '0.0.0.0',
			'server-id'         => '2',
			'binlog-format'     => 'mixed',
			'log-bin'           => 'mysql-bin',
			'relay-log'         => 'mysql-relay-bin',
			'log-slave-updates' => '1',
			'read-only'         => '1',
			'replicate-do-db'   => ['demo'],
		  },
		}
	  }

	  mysql::db { 'demo':
		ensure   => 'present',
		user     => 'demo',
		password => 'changeme',
		host     => '%',
		grant    => ['all'],
	  }
	}


## Wire Them Together

Now that our nodes are provisioned, we have to do a few things to get them talking to each other.

Since the slave will essentially be replaying operations run on the master (and recorded in the bin log)
we need to make sure it is starting from a known state.

Below, we will manually synchronize the slave to the master to provide a starting point
and then have the slave start following the bin log at the position it's currently at. 
(We will also lock the master during part of this to make sure our known starting point is stable.)


### On MySQL Master
Make sure database is locked down, take note of the bin log `File` and `Position`, and grab an export.

	vagrant ssh mysqlmaster

	$ mysql -u root -pchangeme
	mysql> FLUSH TABLES WITH READ LOCK;
	Query OK, 0 rows affected (0.00 sec)

	mysql> SHOW MASTER STATUS;
	+------------------+----------+--------------+------------------+
	| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
	+------------------+----------+--------------+------------------+
	| mysql-bin.000002 |     1467 | demo         |                  |
	+------------------+----------+--------------+------------------+
	1 row in set (0.00 sec)

	mysql> EXIT;

	$ mysqldump -u root -pchangeme --opt demo > /vagrant/demo.sql
	$ mysql -u root -pchangeme
	
	mysql> UNLOCK TABLES;
	
### On MySQL Slave
Import the export just taken from the master and configure the slave

- The mysql master host ip, `172.10.10.10`, is the ip configured in the `Vagrantfile`
- The user created in puppet, `slave_user`, is specified in puppet for `mysqlmaster`
- The bin log position info (`mysql-bin.000002` / `1467`) came from running `SHOW MASTER STATUS` on `mysqlmaster` (see above)


<!-- clear -->


	vagrant ssh mysqlslave
	
	$ mysql -u root -pchangeme
	mysql> SLAVE STOP;
	Query OK, 0 rows affected (0.00 sec)
	mysql> EXIT;
	
	$ mysql -u root -pchangeme demo < /vagrant/demo.sql
	$ mysql -u root -pchangeme
	mysql> CHANGE MASTER TO MASTER_HOST='172.10.10.10', \
	  MASTER_USER='slave_user', MASTER_PASSWORD='changeme', \
	  MASTER_LOG_FILE='mysql-bin.000002', MASTER_LOG_POS=1467;
	Query OK, 0 rows affected (0.00 sec)
	mysql> START SLAVE;
	Query OK, 0 rows affected (0.00 sec)

And to verify it's hooked up:

	mysql> SHOW SLAVE STATUS\G


## Verify Replication

That's it! continue on to create a new table on the master node, insert a record, and see it show up on the slave.

### On MySQL Master
	
	vagrant ssh mysqlmaster
	
	$ mysql -u root -pchangeme
	
	mysql USE demo;
	mysql> CREATE TABLE IF NOT EXISTS Content ( msg VARCHAR(255) ) ENGINE=InnoDB;
	mysql> INSERT INTO Content (`msg`) VALUES ('hello world');
	
	
### On MySQL Slave

	vagrant ssh mysqlslave
	
	$ mysql -u root -pchangeme
	mysql> USE demo;
	mysql> SELECT * FROM Content;
	+-------------+
	| msg         |
	+-------------+
	| hello world |
	+-------------+
	1 row in set (0.00 sec)


