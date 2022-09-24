Дипломная работа
Описание исходной системы.
Имеется 4 виртуальных машины с установленной OS CentOS 7. На каждой из них настроен ssh. В каталоге /root/.ssh/ создан файл authorized_keys, в который добавлен ssh-ключ виртуальной машины управляющей развертыванием и настройкой системы. Firewalld и SeLinux изначально активированы и работают. Дополнительных изменений в системные файлы, процессы, каталоги пользователей не внесено. Никакого дополнительного программного обеспечения не установлено. Перечень ВМ:
1.	WebServer(nginx, apache,wordpress, mysql master, node_exporter, filebeat)
2.	MySQL Slave(apache,wordpress, mysql slave, node_exporter, filebeat)
3.	Prometheus
4.	ELK(kibana, logstash, elasticsearch)
Дополнительно создана виртуальная машина под управлением CentOs 7. На которой установлен Ansible, а также расположены скрипты для выполнения развертывания ПО по первому варианту решения, настройки виртуальных машин входящих в проект.
Вариант 1.
Решение с использованием bash-скриптов.
В директории /root/ расположены файлы и каталоги необходимые для выполнения задания.
 
Файл install.sh – главный, запускается изначально и руководит запуском дочерних скриптов, а также процессом установки и настройки необходимого ПО на подчиненных серверах.
#!/bin/bash
MYSQLSLAVE=”root@192.168.56.118”; # Переменная для ssh-подключения
WEBSERVER="root@192.168.56.117"; # Переменная для ssh-подключения
ELK="root@192.168.56.116"; # Переменная для ssh-подключения
PROMETHEUS=”root@192.168.56.115”; # Переменная для ssh-подключения
SOURCE_HOST_FOR_REPLICA="192.168.56.117"; # Адрес ВМ Мастер MySQL
DB="wordpress"; # Имя БД на сервере
USER="root"; # Пользователь БД
PASS="Hunter1981!"; # Пароль пользователя БД
DIR="/root/backupdb/wordpress"; # Каталог, в котором находится резервная копия БД
# Блок настройки ВМ MySQLSlave
scp mysqlslave.sh $MYSQLSLAVE:/root/mysqlslave.sh;
scp -r files $MYSQLSLAVE:/root/;
ssh $MYSQLSLAVE 'bash -s' < mysqlslave.sh

# Блок настройки ВМ Webserver
scp webserver.sh $WEBSERVER:/root/webserver.sh;
scp -r files $WEBSERVER:/root/;
scp -r backupdb $WEBSERVER:/root/;
scp -r filebeat $WEBSERVER:/root/;
ssh $WEBSERVER 'bash -s' < webserver.sh;

# Блок настройки ВМ ELK
scp elk.sh $ELK:/root/elk.sh;
scp -r elk $ELK:/root/;
ssh $ELK 'bash -s' < elk.sh;

# Блок настройки ВМ Prometheus
scp prometheus.sh $PROMETHEUS:/root/prometheus.sh;
scp -r prometheus $PROMETHEUS:/root/;
ssh $PROMETHEUS 'bash -s' < prometheus.sh;
Настройка ВМ MySQLSlave.(Файл mysqlslave.sh)
#!/bin/bash
# Install httpd
yum -y install epel-release yum-utils;
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm;
yum-config-manager --enable remi-php72;
yum -y update;
yum -y install httpd php-mcrypt php-cli php-gd php-curl php-ldap php-zip php-fileinfo php php72 php-fpm php-mbstring php-IDNA_Convert php-PHPMailer php-process php-simplepie php-xml php-mysql;
systemctl stop firewalld;
systemctl disable firewalld;
sestatus 0;
cp files/default_httpd.conf /etc/httpd/conf.d/main.conf;
cp files/httpd.conf /etc/httpd/conf/httpd.conf;
systemctl restart httpd;
chown -R apache.apache /var/www/html;
systemctl enable httpd --now;

# Install SQL-Server Slave
yum install -y http://dev.mysql.com/get/mysql80-community-release-el7-6.noarch.rpm; 
rpm --import http://repo.mysql.com/RPM-GPG-KEY-mysql-2022;
yum install -y mysql-community-server mysql-community-client MySQL-python;
systemctl enable mysqld --now;
password_match=`awk '/A temporary password is generated for/ {a=$0} END{ print a }' /var/log/mysqld.log | awk '{print $(NF)}'`;
mysql -uroot -p$password_match --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Hunter1981!'; flush privileges; ";
cp files/my_slave.cnf /etc/my.cnf;
systemctl restart mysqld;
mysql -uroot -pHunter1981! -e "SET @@GLOBAL.read_only = ON; CHANGE REPLICATION SOURCE TO SOURCE_HOST='192.168.56.117', SOURCE_USER='replication_user', SOURCE_PASSWORD='Hunter1981!', SOURCE_AUTO_POSITION=1; start replica;";

# Install worpress
curl -LO https://wordpress.org/latest.tar.gz;
tar -xzvf latest.tar.gz;
cp -R wordpress/* /var/www/html/
cp files/wp-config.php /var/www/html/wp-config.php
/usr/bin/find /var/www/html/ -type d -exec chmod 750 {} \\;
/usr/bin/find /var/www/html/ -type f -exec chmod 640 {} \\;

# Install Node Exporter
useradd -d /dev/null -s /usr/sbin/nologin node_exporter;
mkdir /etc/node_exporter;
chown node_exporter.node_exporter /etc/node_exporter;
######mkdir /usr/local/bin/node_exporter;
#####chown node_exporter.node_exporter /usr/local/bin/node_exporter/*;
cp files/node_exporter /usr/local/bin/;
chown node_exporter.node_exporter /usr/local/bin/node_exporter;
cp files/node_exporter.service /etc/systemd/system/node_exporter.service;
systemctl enable node_exporter --now;

Настройка ВМ Webserver. (Файл webserver.sh)
#!/bin/bash
# Install httpd & nginx
yum -y install epel-release yum-utils;
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm;
yum-config-manager --enable remi-php72;
yum -y update;
yum install -y nginx;
yum -y install httpd php-mcrypt php-cli php-gd php-curl php-ldap php-zip php-fileinfo php php72 php-fpm php-mbstring php-IDNA_Convert php-PHPMailer php-process php-simplepie php-xml php-mysql;
systemctl stop firewalld;
systemctl disable firewalld;
sestatus 0;
cp files/default_nginx.conf /etc/nginx/conf.d/default.conf;
cp files/default_httpd.conf /etc/httpd/conf.d/main.conf;
cp files/httpd.conf /etc/httpd/conf/httpd.conf;
systemctl restart httpd;
systemctl restart nginx;
chown -R apache.apache /var/www/html;
systemctl enable nginx --now;
systemctl enable httpd --now;

# Install MySQL Master
yum install -y http://dev.mysql.com/get/mysql80-community-release-el7-6.noarch.rpm; 
rpm --import http://repo.mysql.com/RPM-GPG-KEY-mysql-2022;
yum install -y mysql-community-server mysql-community-client MySQL-python
systemctl enable mysqld --now;
password_match=`awk '/A temporary password is generated for/ {a=$0} END{ print a }' /var/log/mysqld.log | awk '{print $(NF)}'`;
cp files/my_master.cnf /etc/my.cnf;
systemctl restart mysqld;
mysql -uroot -p$password_match --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Hunter1981!'; flush privileges; ";
mysql -uroot -pHunter1981! -e "CREATE USER 'replication_user'@'%' IDENTIFIED WITH mysql_native_password BY 'Hunter1981!'; GRANT REPLICATION SLAVE ON *.* TO 'replication_user'@'%'; FLUSH PRIVILEGES; CREATE DATABASE wordpress; CREATE USER 'wordpress'@'localhost' IDENTIFIED WITH mysql_native_password BY 'PassW0rd1!'; GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost'; FLUSH PRIVILEGES;";
for s in `ls -1 /root/backupdb/wordpress`;
 do
 echo "--> $s restoring... ";
 zcat /root/backupdb/wordpress/$s | /usr/bin/mysql --user='root' --password='Hunter1981!' wordpress;
done

# Install wordpress
curl -LO https://wordpress.org/latest.tar.gz;
tar -xzvf latest.tar.gz;
cp -R wordpress/* /var/www/html/
cp files/wp-config.php /var/www/html/wp-config.php
/usr/bin/find /var/www/html/ -type d -exec chmod 750 {} \\;
/usr/bin/find /var/www/html/ -type f -exec chmod 640 {} \\;

# Install Filebeat
yum -y install filebeat/filebeat_7.17.3_x86_64-224190-4c3205.rpm;
cp filebeat/filebeat.yml /etc/filebeat/filebeat.yml;
systemctl enable filebeat --now;

# Install Node Exporter
useradd -d /dev/null -s /usr/sbin/nologin node_exporter;
mkdir /etc/node_exporter;
chown node_exporter.node_exporter /etc/node_exporter;
######mkdir /usr/local/bin/node_exporter;
#####chown node_exporter.node_exporter /usr/local/bin/node_exporter/*;
cp files/node_exporter /usr/local/bin/;
chown node_exporter.node_exporter /usr/local/bin/node_exporter;
cp files/node_exporter.service /etc/systemd/system/node_exporter.service;
systemctl enable node_exporter --now;
Настройка ВМ Prometheus(Файл prometheus.sh)

#!/bin/bash
systemctl stop firewalld;
systemctl disable firewalld;
setenforce 0;
useradd -d /dev/null -s /usr/sbin/nologin prometheus;
mkdir /tmp/prometheus;
mkdir /etc/prometheus;
mkdir /var/lib/prometheus;
chown -R prometheus:prometheus /tmp/prometheus;
chown -R prometheus:prometheus /etc/prometheus;
chown -R prometheus:prometheus /var/lib/prometheus;
cp prometheus/prometheus /usr/local/bin/;
cp prometheus/promtool /usr/local/bin/;
cp prometheus/prometheus.j2 /etc/systemd/system/prometheus.service;
cp prometheus/prometheus.yml /etc/prometheus/prometheus.yml;
systemctl enable prometheus --now;
cp prometheus/grafana.repo /etc/yum.repos.d/grafana.repo;
yum -y install grafana;
systemctl enable grafana-server --now;
sleep 1m;
grafana-cli admin reset-admin-password hunter1981;

Настройка ВМ ELK (Файл elk.sh)
#!/bin/bash
systemctl stop firewalld;
systemctl disable firewalld;
sestatus 0;
yum -y install elk/elasticsearch_7.17.3_x86_64-224190-9bcb26.rpm;
cp elk/jvm.options /etc/elasticsearch/jvm.options.d/jvm.options;
systemctl enable elasticsearch --now;
yum -y install elk/kibana_7.17.3_x86_64-224190-b13e53.rpm;
cp elk/kibana.yml /etc/kibana/kibana.yml;
systemctl enable kibana --now;
yum -y install elk/logstash_7.17.3_x86_64-224190-3a605f.rpm;
cp elk/logstash.yml /etc/logstash/logstash.yml;
cp elk/logstash-nginx-es.conf /etc/logstash/conf.d/logstash-nginx-es.conf;
systemctl enable logstash --now;

Ссылка на проект в github:
https://github.com/DmitryV81/OTUS_DIPLOM_VERSION_2.git



Вариант 2.
Решение с использованием Ansible
В директории /root/git/OTUS_FIRST_DIPLOM/otus/ расположены файлы и каталоги необходимые для выполнения задания.

 
 
Для старта настройки системы необходимо выполнить команду:
ansible-playbook –i hosts site.yml
Далее описание содержимого некоторых каталогов проекта.
Каталог backupdb содержит резервную копию БД
Каталог group_vars содержит информацию обо всех переменных используемых в проекте.
Файл hosts служит для объявления ВМ и разбивки их по функциональным группам
Каталог host_vars  содержит файлы с записями вида:  имя_машины-ip_address. Выполняет привязку Имя_используемое_в_ansible – ip_address ВМ
Каталог roles содержит подкаталоги именованные по устанавливаемым системам. Роль Ansible — это набор файлов, задач, шаблонов, переменных и обработчиков, которые вместе служат определенной цели. В данном случае каждая роль служит для установки настройки отдельных компонентов рабочего проекта.
Ссылка на проект в github:
https://github.com/DmitryV81/OTUS_FIRST_DIPLOM.git

В целом установка и настройка системы в первом и втором варианте занимает около 25 минут. Однако, вариант с использованием Ansible более предпочтителен, так как обеспечивает иммутабельность системы, т.е.  инфраструктура всегда находится в одном состоянии.
Замечание. Перед запуском скриптов необходимо убедится в соответствии ip-адресов в скриптах и реальных ip-адресов ВМ.
В первой версии проекта изменения необходимо внести в install.sh, mysqlslave.sh, files/default_nginx.conf, files/my_master.cnf, filebeat/filebeat.yml, prometheus/prometheus.yml
Во второй версии: group_vars/all, во всех файлах в каталоге host_vars, roles/prometheus/templates/prometheus.yml.j2, roles/mysql/tasks/main.yml,
Замечание 2. В обеих версиях используется GTID Репликация mySQL Server. Она проще в настройке, не требует отслеживания позиции бинлога. В первом варианте её настройка происходит в блоке mysqlslave.sh и webserver.sh, во втором варианте в роли mysql. При подготовке бекапа БД следует учитывать тот момент, что нужно включить в него параметр --set-gtid-purged=OFF, в противном случае восстановление БД из резервной копии будет заканчиваться ошибкой восстановления.
Замечание 3. После восстановления БД wordpress из резервной копии следует учитывать, что адреса master и slave ВМ могли измениться. Если так, то при навигации по страницам будет появляться ошибка, так как будет происходить обращение к несуществующему ip-адресу. Для того чтобы привести данные в соответствие необходимо войти в консоль mysql на ВМ webserver(роль master MySQL) и внести корректировки:
UPDATE wp_options SET option_value = replace(option_value, 'http://СТАРЫЙ', 'http://НОВЫЙ') WHERE option_name = 'home' OR option_name = 'siteurl';
UPDATE wp_posts SET guid = replace(guid, 'http://СТАРЫЙ', 'http://НОВЫЙ');
UPDATE wp_posts SET post_content = replace(post_content, 'http://СТАРЫЙ', 'http://НОВЫЙ');
UPDATE wp_postmeta SET meta_value = replace(meta_value, 'http://СТАРЫЙ', 'http://НОВЫЙ');


 
Приложение. Скрипт потабличного резервного копирования базы данных wordpress.
#!/bin/bash
# MySql backup script

USER='root'
PASS='Hunter1981!'
 
MYSQL="mysql --user=$USER --password=$PASS --skip-column-names";
DIR="/root/backupdb"
 
for s in mysql `$MYSQL -e "SHOW DATABASES"`;
    do
    if [ ! -d "$DIR/$s" ]; then mkdir -p "$DIR/$s"; fi;
    for t in `$MYSQL -e "SHOW TABLES FROM $s"`;
    do
        /usr/bin/mysqldump --user="$USER" --password="$PASS" --set-gtid-purged=OFF --add-drop-table --add-locks --create-options --disable-keys --extended-insert --single-transaction --quick --set-charset --events --routines --triggers --source-data=2  --opt $s $t | /usr/bin/gzip -c > $DIR/$s/$t.sql.gz;
    done
    done

Приложение. Добавление задания в crontab.\
Скрипт помещаем в домашнюю директорию пользователя root. Далее:
crontab -e
59 23 * * * /root/b.sh
Выполняется ежедневно в 23:59
