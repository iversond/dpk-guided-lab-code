
set termout on
set echo off
set verify off
set feedback off
set heading off
select d.name from V$datafile d, v$pdbs p  where d.con_id=p.con_id  and p.name ='&1' and d.ts#=0;
exit