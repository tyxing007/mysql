=================完整的数据备份===========================================
备份指令(所有数据库)：
	/usr/local/mysql/bin/mysqldump -u用户名 -p密码 数据库名 -l -F > '备份目录及备份文件名名称(/tmp/user.sql)';
	  -F : 等价于flush logs指令,可以重新生成新的日志文件，当然还包括log-bin日志
	  -l : 堵锁，备份时，禁止写入数据，此时可以正常读取数据

刷新日志表：
	flush logs;--备份前必须刷新bin-log日志
	
查看log-bin日志：
	show master status;--查看最后一个日志表文件
	reset master;--清空所有日志文件
	bin-log日志文件形式：mysql-bin.000013  表示有13个日志文件
    /usr/local/mysql/bin/mysqlbinlog mysql-bin.0000xx;查看log二进制文件内容
案例：
   在服务器上执行：
      /usr/local/mysql/mysqldump -u用户名 -p密码 数据库名 -l -F > '备份目录及备份文件名名称(/tmp/user.sql)' --已备份到当前数据
	
	恢复：
	  假设上次备份mysql-bin.000013 文件日志
	  而从上次备份到本次数据库崩溃，中间又产生了许多新数据，恢复步骤：
	  a、先恢复备份文件：
		/usr/local/mysql/mysqldump -u用户名 -p密码 数据库名 -v -f < '备份目录及备份文件名名称(/tmp/user.sql)'  --恢复上一次备份的数据
		参数说明：-v:查看导入的详细信息，-f:如果执行过程中发生错误，跳过继续执行。
		
	  b、然后在恢复从上次备份到数据崩溃这段时间未备份的数据：
		在备份时，记录当前备份的mysql-bin.0000x的数字( 查看mysqlbinlog日志)，即从第几个文件备份的，加上和上次是：mysql-bin.00013日志文件，则本次恢复从
		mysql-bin.00013日志文件开始恢复(恢复二进制文件,是以管道的方式导入)：
		    /usr/local/mysql/bin/mysqlbin/log --on-defaults mysql-bin.00014 |/usr/local/mysql/bin/mysql -u用户名 -p密码 数据库名
			即恢复了从上次备份到本次未备份数据的恢复。
			
	   c、恢复完成。

		d、高级恢复(查看binlog表，即mysql-bin.00014文件)：
		  1、按pos之间的数据
		     说明：position 值在 mysql-bin.00000x文件中是以：#at 数字  形式存在
			--stop-position='值(数字)'
			--start-position='值(数字)'
			
			假设要恢复从 128 - 379的数据：
			  分析查看：
				/usr/local/mysql/bin/mysqlbin/log --on-defaults mysql-bin.00014 --start-position='128' --stop-position='379' |more
			
			恢复：
			 /usr/local/mysql/bin/mysqlbin/log --on-defaults mysql-bin.00014 --start-position='128' --stop-position='379' |/usr/local/mysql/bin/mysql -u用户名 -p密码 数据库名			
	   
		  2、按时间点恢复：
			--start-date="日期(2012-06-12 12:32:34)"
	        --stop-date="日期(2012-06-12 17:32:34)"
			
			/usr/local/mysql/bin/mysqlbin/log --on-defaults mysql-bin.00014 --start-date="2012-06-12 12:32:34" --stop-date="2012-06-12 17:32:34"|/usr/local/mysql/bin/mysql -u用户名 -p密码 数据库名
	   
		mysql集群技术属于冗余技术
		mysql主从复制属于负载均衡技术
		查看mysql是否启动：pstree |grep mysql   --其它进程类似
		端口测试：netstat  -tunpl | grep :3306 或者 端口测试：netstat  -tunpl | grep :80  即能看到对应的程序运行 
	

	
===================完整的主从复制====================================================
1、主从复制的有点：
	a、如果主服务器发生故障，则可以快速切换到从服务器提供服务
	b、可以再从服务器上执行查询，降低服务器压力，主服务器一般担任写、更新、删除操作
	c、可以在从服务器上做备份，避免影响主服务器性能   
	   注意：一般只有更新不频繁或者对数据的实时性要求不高时，采用从服务器查询，实时性高的时间仍需从主服务器查询。
	d、执行控制： 是从主服务器上执行sql还是从服务器执行sql，由php代码控制
	   
2、	主从服务器配置
	主服务器：192.168.80.1
	从服务器：192.168.80.2
	主服务器授权给从服务器的用户：user01  密码：123456
	a、登陆数据库：
		mysql -h ip -u 登陆名 -p密码 -P 端口 数据库名
	b、给从服务器设置授权用户
	c、mysql日志文件所在位置：/usr/local/mysql/var
	d、修改主数据库服务器的配置文件：my.cnf //my.cnf位置：/etc/my.cnf
	    开启binglog日志，并设置server-id的值，即：
			log-bin=mysql-bin
			server-id=1
			一般把前面的#去掉即可
	e、在主服务器上设置读锁定有效，确保没有数据库操作，以便获得一致性快照(选做)
	   mysql>flush tables with read lock;
	f、目前备份主数据库服务器数据有两种方式：
	   1、cp全部数据;
	   2、mysqldump备份数据；
	   如果主数据库服务可以停止操作(insert、update、delete),那么可以直接cp数据
	   文件，速度应该是最快的生成快照。
	   tar -cvf data.tar.data
	   
	g、解锁：unlock tables;
	
	h、一般最好采用mysqldump备份，不影响线上数据
	  1、备份主服务器test数据库：
	    root@localhost/  mysqldump -uroot -p123456 test > /tmp/test.sql
	  2、将test.sql复制到从服务器(将主服务器的test.sql复制到从服务器的tmp目录下)
	     scp /tmp/test.sql 192.168.80.2:/tmp/ --确认yes，输入从服务器密码
	  3、恢复备份的文件(看上面的数据恢复)
	  4、配置从服务器my.cnf文件(前提是：确保主服务器中已有授权给从服务器的用户,假设为：user01，密码：123456)
		   server-id=2 --配置文件的此id不能重复，此页面有两个serverid，只开启第一个即可
		   master-host     =   192.168.80.1 --主服务器ip
		   master-user     =   user01 --主服务器授权给从服务器的用户名
		   master-password =   123456 --授权用户(user01)密码
		   master-port     =  3306  --主服务器数据库端口
		   --测试一下能否从从服务器登陆到主服务器数据库(test)：
		      mysql -uuser01 -h 192.168.80.1 -p123456 test;
		   --查看mysql进程：ps -ef |grep mysqld
		   --停止mysql进程：pkill mysqld
		   --重启mysql：mysqld_safe  --user=mysql & 还有其它方式重启mysql
		   --查看是否能自动同步:
		   登陆从服务器数据库，执行：
		       mysql> show slave status\G
			 如果显示的结构中：
			  Slave_10_Running:Yes
			  show slave status\G
			  这个字段同时是yes，则表示主从服务配置成功。一般60秒同步一次
			--常用命令：
			 mysql>: 
			     start slave --启动复制线程
				 stop slave --停止复制线程
				 show slave status --查看从数据库状态
				 show master logs --查看主数据库bin0log日志
				 change master to --动态改变到主服务器的配置
				 show processlist --查看从数据库运行进程
			
			--常见错误
				a、如果从数据库无法同步：
				   show slave status 显示 Slave_SQL_Running 为：NO,
				   Seconds_Behind_Master为null时
				   原因：
				      1、程序可能在slave上进行了写操作
					  2、也有可能是slave机器重启后，事务回滚造成的
					  解决方法一(从数据库执行)：
					    mysql>slave stop;
						mysql>set GLOBAL SQL_SLAVE_SKIP_COUNTER=1;
						mysql>slave start;
					  解决方法二(主数据库执行)：
					    msyql>slave stop;
						mysql>show master status;--得到主服务器上当前的二进制日志名和偏移量
						接着转移到从服务器数据库：
						 手动执行同步
						 mysql>change master to master_host='主数据库ip',
								master_user='user01',
								master_password='123457',
								master_port=3306,
								master_log_file='mysql-bin.000003',--要同步的文件
								master_log_pos=98;
								然后启动slave服务器：
						 mysql>slave start;
						 通过show slave status 查看
							Slave_SQL_Running 为 Yes，	
							Seconds_Behind_Master为0时，问题已经解决
						
================mysql用户授权=======================================================
a、登陆数据库：
		mysql -h ip -u 登陆名 -p密码 -P 端口 数据库名
b、查看授权表及用户
		select user,host,password from.user; //mysql数据库的user表
		show grants for user01@192.168.80.2;//查看是否存在.2服务器上的用户
		
c、给从服务器用户授权(可以使该账号从从服务器登录到主服务器,在主服务器上添加如下账号)
		--所有权限：
		grant all on *.* to user01@192.168.1.102 identified by '123456';  --*.*:所有库及所有表 ,user01:用户名
		--之后就可以从192.168.1.102登陆到主服务器
		
		--主从复制权限：
		grant all slave on *.* to user01@192.168.1.102 identified by '123456'; 或者
		grant replicatio slave on *.* user01@192.168.1.102 identified by '123456';

		
================mysql分区技术=======================================================
1、特多：mysql5.1后的版本，都自带了分区技术，分区技术基本上可以取代分库分表技术。
2、如果一张表记录超过一千万条数据，操作系统的性能会急剧下降。
3、操作系统的检索文件特点：把一个大文件分成有规律的n个小文件，在检索时,
	后者的效率要比前者高很多，并且系统性能也要低得多。所以就出现了拆分技术。
4、目前，针对海量数据库数据优化主要有两种：
    a、达标拆小表
	b、sql语句优化，如增加索引，但数据量增大会导致索引的维护代价增大

垂直分表：
	拆分表字段，将一个表字段拆分为多个表(基本上不会用)
	
水平分表：
将一个表拆分为多个表(一般采用求模技术实现或一定的hash计算)，影响：对程序控制
	带来了一定的难度
	
分区：
	a.分区不同于分表技术，它是在逻辑层进行的水平分表，对于应用程序而言还是一张表.
    b.mysql最新版本的分区类型：
		1、RANGE分区：基于属于一个给定连续区间的列值，把多行分配给分区
		2. LIST分区：类似于按RANGE分区，区别在于LIST分区是基于列值匹配一个离散值集合中的某个值来进行选择。
		3. HASH分区：基于用户定义的表达式的返回值来进行选择的分区，该表达式使用将要插入到表中的这些行的列值进行计算。
		4. KEY分区：类似于按HASH分区，区别在于KEY分区只支持计算一列或多列，且MySQL 服务器提供其自身的哈希函数。
		5. 子分区：子分区是分区表中每个分区的再次分割。

















