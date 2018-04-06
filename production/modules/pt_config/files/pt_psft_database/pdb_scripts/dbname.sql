
set termout on
set echo off
set verify off
set heading off
ALTER SESSION SET CONTAINER = &1;
UPDATE PS.PSDBOWNER SET DBNAME='&1';
exit