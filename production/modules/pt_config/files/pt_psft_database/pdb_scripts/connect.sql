 
 


set termout on
set echo off
set verify off
set heading off



create USER &1 identified by &2 default tablespace PSDEFAULT
temporary tablespace PSTEMP;

GRANT CREATE SESSION to &1;
GRANT SELECT ON PS.PSDBOWNER TO &1;

exit