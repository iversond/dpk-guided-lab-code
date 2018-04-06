
set termout on
set echo off
set verify off
set heading off
ALTER PLUGGABLE DATABASE &1 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE &1 SAVE STATE;
exit