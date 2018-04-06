

SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET TERMOUT OFF
SET VERIFY OFF
set echo off
select 'CREATE_TEMP_TABLE ', RECNAME,';' from PSRECDEFN where RECTYPE =7 and regexp_like (RECNAME ,'^[A-G]');
select 'CREATE_TEMP_TABLE ', RECNAME,';' from PSRECDEFN where RECTYPE =7 and regexp_like (RECNAME ,'^[H-N]');
select 'CREATE_TEMP_TABLE ', RECNAME,';' from PSRECDEFN where RECTYPE =7 and regexp_like (RECNAME ,'^[O-T]');
select 'CREATE_TEMP_TABLE ', RECNAME,';' from PSRECDEFN where RECTYPE =7 and regexp_like (RECNAME ,'^[U-Z]');
exit
