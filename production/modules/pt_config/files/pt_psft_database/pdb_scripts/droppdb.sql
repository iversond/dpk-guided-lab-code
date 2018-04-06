
set termout on
set echo off
set verify off
set heading off
DROP PLUGGABLE DATABASE &1 including datafiles;
exit