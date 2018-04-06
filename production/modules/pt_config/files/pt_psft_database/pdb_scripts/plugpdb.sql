
set termout on
set echo off
set verify off
set heading off
CREATE PLUGGABLE DATABASE &1 AS CLONE USING '&2' 
  SOURCE_FILE_NAME_CONVERT=NONE
  NOCOPY
  STORAGE UNLIMITED 
  TEMPFILE REUSE;
alter pluggable database &1 open; 
ALTER PLUGGABLE DATABASE &1 SAVE STATE;
exit