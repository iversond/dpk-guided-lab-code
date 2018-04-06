
set termout on
set echo off
set verify off
set feedback off
set heading off
select 'DBNAME' , DBNAME From PS.PSDBOWNER;
select 'TOOLSREL' , TOOLSREL from PSSTATUS;
select 'OPRID'  from PSOPRDEFN where OPRID='&1';
select 'OPRID-LOCKED' , ACCTLOCK from PSOPRDEFN where OPRID='&1';
select 'UNICODE_ENABLED' , UNICODE_ENABLED from PSSTATUS;
select 'DATABASE_OPTIONS' , DATABASE_OPTIONS from PSSTATUS;
select 'ACCESSID-ENCRYPTED-8.54' , ENCRYPTED from PSACCESSPRFL;
select 'ACCESSID-ENCRYPTED-8.55' , ENCRYPTED from PSACCESSPROFILE;
select 'OPRID-ENCRYPTED', ENCRYPTED from PSOPRDEFN where OPRID='&1';
select 'MV', TABLE_NAME from user_tables where TABLE_NAME='MV_CAPABILITIES_TABLE';
exit