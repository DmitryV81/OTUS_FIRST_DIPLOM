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



#PATH=$PATH:/usr/local/bin

#DIR=`date +"%Y-%m-%d"` 
#DATE=`date +"%Y%m%d"`

#MYSQL='mysql -uroot -pHunter1981! --skip-column-names'
#if [ ! -d "/$DIR" ]; then mkdir -p "$DIR"; fi;
#for b in  $(mysql -uroot -pHunter1981! -e "show databases like '%\_db'" -s --skip-column-names);
#	do
#	for t in $(mysql -uroot -pHunter1981! -e "show tables from $b");
#	do
#	if [ ! -d "$DIR/$b" ]; then mkdir -p "$DIR/$b"; fi;
#	mysqldump -uroot -pHunter1981! --add-drop-table --add-locks --create-options --disable-keys --extended-insert --single-transaction --quick --set-charset --events --routines --triggers --source-data=2 $b $t | gzip -1 > $DIR/$b/$t.gz;
#	done
#done
