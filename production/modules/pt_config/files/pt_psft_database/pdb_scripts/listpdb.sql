
set termout on
set echo off
set verify off
set feedback off
set heading on
select name , open_mode From v$pdbs where open_mode in ('READ WRITE','MOUNTED');
exit