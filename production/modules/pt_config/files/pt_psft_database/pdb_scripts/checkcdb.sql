
set termout on
set echo off
set verify off
set feedback off
set heading off
select 'CDB' from v$database where name='&1' and cdb='YES';
select 'PDBSEED' From v$pdbs where name='PDB$SEED' and open_mode = 'READ ONLY';
exit