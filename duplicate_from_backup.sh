#!/bin/bash
# Created by: Gleb Otochkin - otochkin@pythian.com 
# Version 1.01 28-AUG-2017
#
# Script to refresh QA4 database using backup only located on a shared FS
# 
##################################
SCRIPT_NAME=`basename $0`
usage() {
cat<<EOF
$0: version 1.01
usage:
       $0 [DB_UNIQUE] [ORACLE_SID] [DATA_DISKGROUP] [FRA_DISKGROUP] [BACKUP_LOC] [UNTIL_TIME]
 
       ORACLE_SID - sid for the duplicated  database
       DB_UNIQUE - unique name for the duplicated  database
       DATA_DISKGROUP - ASM diskgroup for data
       FRA_DISKGROUP - ASM diskgroup for FRA
       BACKUP_LOC - Source backups location
       UNTIL_TIME - time for point of time recovery format 'mm/dd/yyyy hh24:mi:ss'
EOF
}

if [[ $# -ne 6 ]] ; then
  usage
  exit 1
fi

#Set environments
if [ $USER != 'oracle' ] ; then
        echo "script should be executed from oracle account"
        exit 0
fi

ORAENV_ASK=NO
ORACLE_SID=$1
. oraenv

# New database unique name
DB_UNIQUE=$2
# Diskgroup to place database files
DATA_DISKGROUP=$3
# Diskgroup to place FRA
FRA_DISKGROUP=$4
#Define backup location
#BACKUP_LOCATION=/u02/app/oracle/oradata/backup/CCXP
BACKUP_LOCATION=$5
# Time for point of time recovery format 'mm/dd/yyyy hh24:mi:ss'
UNTIL_TIME=$6


#Directory to store log files and log name
LOG_LOC=/home/oracle
LOG_NAME=refresh-${ORACLE_SID}-`date +%Y%m%d%H%M%S`.log

#Directory for scripts
SCRIPT_LOC=/u01/app/oracle/admin/ccxq4/scripts

echo "Starting refresh at `date +%Y/%m/%d-%H:%M:%S`" >${LOG_LOC}/${LOG_NAME} 2>&1


#Step to copy of an old pfile to the script directory 
echo "Step - copy of an old pfile to the script directory. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
cp $ORACLE_HOME/dbs/init${ORACLE_SID}.ora ${SCRIPT_LOC}/init${ORACLE_SID}.ora_before_refresh.ora >>${LOG_LOC}/${LOG_NAME} 2>&1

#Step to drop the existing CCXQ4 database.
echo "Step - drop the existing ${ORACLE_SID} database.Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba <<EOF >>${LOG_LOC}/${LOG_NAME} 2>&1
shutdown immediate
startup mount exclusive restrict 
EOF

rman target / <<EOF>>${LOG_LOC}/${LOG_NAME} 2>&1
drop database noprompt;
EOF

#Step to clean up the defined ASM disk groups from any leftovers.
echo "Step - clean up the defined ASM disk groups from any leftovers. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba <<EOF>>${LOG_LOC}/${LOG_NAME} 2>&1
startup nomount pfile='$ORACLE_HOME/dbs/init${ORACLE_SID}.ora' force
set serveroutput on
begin 
for cur in 
(SELECT 'ALTER DISKGROUP '||gname||' DROP FILE '''||full_path||'''' strsql FROM
(SELECT CONCAT('+'||gname, SYS_CONNECT_BY_PATH(aname,'/')) full_path, gname FROM
(SELECT g.name gname, a.parent_index, a.name aname,a.reference_index, a.alias_directory FROM
v\$asm_alias a, v\$asm_diskgroup g WHERE a.group_number = g.group_number)
WHERE alias_directory='N' START WITH (MOD(parent_index, POWER(2, 24))) = 0 CONNECT BY PRIOR reference_index = parent_index)  
WHERE full_path LIKE UPPER('%${DB_UNIQUE}%') and gname in (UPPER('${DATA_DISKGROUP}'),UPPER('${FRA_DISKGROUP}')))
loop 
dbms_output.put_line(cur.strsql);
execute immediate cur.strsql;
end loop;
end;
/
EOF

#Step to reset control files location in the pfile (optional - may work without it)
echo "Step - reset control files location in the pfile. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sed -i '/control_files/d' $ORACLE_HOME/dbs/init${ORACLE_SID}.ora
echo "*.control_files='+${DATA_DISKGROUP}','+${FRA_DISKGROUP}'" >>$ORACLE_HOME/dbs/init${ORACLE_SID}.ora

#Step to create a new spfile 
echo "Step - create a new spfile." >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba <<EOF>>${LOG_LOC}/${LOG_NAME} 2>&1
startup nomount pfile='$ORACLE_HOME/dbs/init${ORACLE_SID}.ora' force
create spfile from pfile='$ORACLE_HOME/dbs/init${ORACLE_SID}.ora';
startup nomount force
EOF

#Step - duplicate database from backup using backup location and defined time.
echo "Step - duplicate database from backup using defined backup location. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
echo "duplicate database to ccxq4 until time to_date('${UNTIL_TIME}','DD-MM-YYYY HH24:MI:SS') backup location '${BACKUP_LOCATION}'"
rman auxiliary / <<EOF>>${LOG_LOC}/${LOG_NAME} 2>&1
run {
allocate auxiliary channel c1 device type disk;
allocate auxiliary channel c2 device type disk;
allocate auxiliary channel c3 device type disk;
allocate auxiliary channel c4 device type disk;
allocate auxiliary channel c5 device type disk;
allocate auxiliary channel c6 device type disk;
allocate auxiliary channel c7 device type disk;
allocate auxiliary channel c8 device type disk;
allocate auxiliary channel c9 device type disk;
allocate auxiliary channel c10 device type disk;
allocate auxiliary channel c11 device type disk;
allocate auxiliary channel c12 device type disk;
duplicate database to ccxq4 until time "to_date('${UNTIL_TIME}','DD-MM-YYYY HH24:MI:SS')" backup location '${BACKUP_LOCATION}';
}
EOF

#Step to write new location of controlfiles to the pfile.
echo "Step - duplicate database from backup using backup location and defined time. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
SPFILE_LOC=`$ORACLE_HOME/bin/sqlplus -s "/ as sysdba"<< EOF
set timing off heading off feedback off pages 0 serverout on feed off
select value from v\\\$system_parameter where name='control_files';
exit;
EOF`
sed -i '/control_files/d' $ORACLE_HOME/dbs/init${ORACLE_SID}.ora 
echo "*.control_files=${SPFILE_LOC}" >>$ORACLE_HOME/dbs/init${ORACLE_SID}.ora 
grep -i control_files $ORACLE_HOME/dbs/init${ORACLE_SID}.ora >>${LOG_LOC}/${LOG_NAME} 2>&1

#Step to create new spfile from the pfile (old pfile is deleted by rman in the end of duplication - Oracle bug Doc ID 1951266.1)
echo "Step - create new spfile from the pfile (Oracle bug Doc ID 1951266.1). Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba << EOF >>${LOG_LOC}/${LOG_NAME} 2>&1
startup nomount pfile='$ORACLE_HOME/dbs/init${ORACLE_SID}.ora' force
create spfile from pfile='$ORACLE_HOME/dbs/init${ORACLE_SID}.ora';
shutdown immediate
startup
EOF

#Step to apply the db part of PSU 
echo "Step - apply the db part of PSU. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
cd $ORACLE_HOME/rdbms/admin
sqlplus / as sysdba << EOF >>${LOG_LOC}/${LOG_NAME} 2>&1
@catbundle.sql psu apply
@utlrp.sql
exit
EOF

#Run custom scripts and apply new parameters
#Step to drop all database links 
echo "Step - drop all database links. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba << EOF >>${LOG_LOC}/${LOG_NAME} 2>&1
set serveroutput on
DECLARE
  l_sql CLOB :=
   'CREATE PROCEDURE <OWNER>.drop_db_links_prc
    IS
    BEGIN
      FOR i IN (SELECT * FROM user_db_links)
      LOOP
        dbms_output.put_line(''to drop ''||i.db_link);
        EXECUTE IMMEDIATE ''DROP DATABASE LINK ''||i.db_link;
      END LOOP;
    END;';
  l_sql1 clob;  
BEGIN
  FOR i in (SELECT DISTINCT owner FROM dba_objects WHERE  object_type='DATABASE LINK')
  LOOP
    l_sql1 := REPLACE(l_sql, '<OWNER>', i.owner);
    dbms_output.put_line(l_sql1);
    EXECUTE IMMEDIATE l_sql1;
    l_sql1 := 'BEGIN '||i.owner||'.drop_db_links_prc; END;';
    EXECUTE IMMEDIATE l_sql1;
    l_sql1 := 'DROP PROCEDURE '||i.owner||'.drop_db_links_prc';
    EXECUTE IMMEDIATE l_sql1;
  END loop;
END;
/
EOF

#Step to drop all directories
echo "Step - drop all directories. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba << EOF  >>${LOG_LOC}/${LOG_NAME} 2>&1
set serveroutput on
declare
l_sql varchar2(300);
begin
for i in (select * from dba_directories)
loop
l_sql := 'drop directory '||i.directory_name;
execute immediate l_sql;
dbms_output.put_line(i.directory_name||' directory '|| i.directory_path||' is dropped');
end loop;
end;
/
EOF

#Step to change scheduler for gathering statistics
echo "Step - change scheduler for gathering statistics. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba << EOF  >>${LOG_LOC}/${LOG_NAME} 2>&1
SELECT STATE FROM DBA_SCHEDULER_JOBS WHERE JOB_NAME = 'GATHER_STATS_JOB';
EXEC DBMS_SCHEDULER.DISABLE('GATHER_STATS_JOB');
SELECT STATE FROM DBA_SCHEDULER_JOBS WHERE JOB_NAME = 'GATHER_STATS_JOB';
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('MONDAY_WINDOW','repeat_interval','freq=daily;byday=MON;byhour=20;byminute=30;bysecond=0');
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('TUESDAY_WINDOW','repeat_interval','freq=daily;byday=TUE;byhour=20;byminute=30;bysecond=0');
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('WEDNESDAY_WINDOW','repeat_interval','freq=daily;byday=WED;byhour=20;byminute=30;bysecond=0');
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('THURSDAY_WINDOW','repeat_interval','freq=daily;byday=THU;byhour=20;byminute=30;bysecond=0');
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('FRIDAY_WINDOW','repeat_interval','freq=daily;byday=FRI;byhour=20;byminute=30;bysecond=0');
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('WEEKNIGHT_WINDOW','repeat_interval','freq=daily;byday=MON,TUE,WED,THU,FRI;byhour=20;byminute=30;bysecond=0');
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('SATURDAY_WINDOW','repeat_interval','freq=daily;byday=SAT;byhour=00;byminute=30;bysecond=0');
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('SUNDAY_WINDOW','repeat_interval','freq=daily;byday=SUN;byhour=08;byminute=00;bysecond=0');
-- change the duration based on requirements from Raj.
exec dbms_scheduler.set_attribute('SATURDAY_WINDOW','DURATION','+000 23:00:00');
exec dbms_scheduler.set_attribute('SUNDAY_WINDOW','DURATION','+000 12:00:00');
exec dbms_stats.lock_table_stats('ONW','TBLELIGSTRUCTBENHIST_H');
exit;
EOF


#Step to increase UNDO retention
cho "Step - increase UNDO retention. Time: `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
sqlplus / as sysdba << EOF >>${LOG_LOC}/${LOG_NAME} 2>&1
alter system set undo_retention=90000 sid='*' scope=both;
exit;
EOF

echo "Finished at `date +%Y/%m/%d-%H:%M:%S`" >>${LOG_LOC}/${LOG_NAME} 2>&1
