 
 



set termout on
set echo off
set verify off
set heading off



create user &2 identified by &3 default tablespace &4
temporary tablespace pstemp;
grant PSADMIN TO &2;


grant unlimited tablespace to &2;


connect system/&5@&1

set echo off

@%ORACLE_HOME%\rdbms\admin\catdbsyn
@%ORACLE_HOME%\sqlplus\admin\pupbld


connect &2/&3@&1

set echo off

@%ORACLE_HOME%\rdbms\admin\utlxmv

exit