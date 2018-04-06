
set termout on
set echo off
set verify off
set heading off
set feedback off
SET SERVEROUTPUT ON
DECLARE
  compatible CONSTANT VARCHAR2(3) := 
    CASE DBMS_PDB.CHECK_PLUG_COMPATIBILITY(
           pdb_descr_file => '&2',
           pdb_name       => '&1')
    WHEN TRUE THEN 'YES'
    ELSE 'NO'
END;
BEGIN
  DBMS_OUTPUT.PUT_LINE(compatible);
END;
/
SET SERVEROUTPUT OFF
select TRIM(CAUSE) , TRIM(TYPE) from PDB_PLUG_IN_VIOLATIONS where name = '&1';
exit