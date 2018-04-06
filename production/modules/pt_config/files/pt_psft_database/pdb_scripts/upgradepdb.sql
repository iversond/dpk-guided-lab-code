
set termout on
set echo off
set verify off
set heading off
alter session set container=&1;
alter pluggable database open upgrade;
exit