 
 


set termout on
set echo on
set verify off

startup nomount pfile=&1\admin\&2\init&2..ora

CREATE DATABASE   &2
    maxdatafiles  1021
    maxinstances  1
    maxlogfiles   8
    maxlogmembers 4
    CHARACTER SET AL32UTF8
    NATIONAL CHARACTER SET UTF8
DATAFILE '&1\&2\system01.dbf' SIZE 2000M REUSE AUTOEXTEND ON NEXT 10240K MAXSIZE UNLIMITED
EXTENT MANAGEMENT LOCAL
SYSAUX DATAFILE '&1\&2\sysaux01.dbf' SIZE 120M REUSE AUTOEXTEND ON NEXT  10240K MAXSIZE UNLIMITED
DEFAULT TEMPORARY TABLESPACE TEMP TEMPFILE '&1\&2\temp01.dbf' SIZE 20M REUSE AUTOEXTEND ON NEXT  640K MAXSIZE UNLIMITED
UNDO TABLESPACE "PSUNDOTS" DATAFILE '&1\&2\psundots01.dbf' SIZE 300M REUSE AUTOEXTEND ON NEXT  5120K MAXSIZE UNLIMITED
LOGFILE GROUP 1 ('&1\&2\redo01.log') SIZE 100M,
        GROUP 2 ('&1\&2\redo02.log') SIZE 100M,
        GROUP 3 ('&1\&2\redo03.log') SIZE 100M
enable pluggable database
seed file_name_convert=('&1\&2\system01.dbf',
'&1\&2\pdbseed\system01.dbf',
'&1\&2\sysaux01.dbf',
'&1\&2\pdbseed\sysaux01.dbf',
'&1\&2\temp01.dbf',
'&1\&2\pdbseed\temp01.dbf',
'&1\&2\undotbs01.dbf',
'&1\&2\pdbseed\undotbs01.dbf');
exit