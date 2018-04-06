
set termout on
set echo off
set verify off
set feedback off
set heading off
select FILE_NAME from dba_data_files where TABLESPACE_NAME='SYSTEM';
exit