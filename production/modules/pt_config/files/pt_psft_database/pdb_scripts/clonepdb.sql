
set termout on
set echo off
set verify off
set heading off
alter pluggable database &2 open read only force; 
CREATE PLUGGABLE DATABASE &1 FROM &2
  PATH_PREFIX = '&4'
  FILE_NAME_CONVERT = ('&3', '&4')
 STORAGE UNLIMITED ;
alter pluggable database &1 open; 
ALTER PLUGGABLE DATABASE &1 SAVE STATE;
alter pluggable database &2 close immediate; 
alter pluggable database &2 open; 
ALTER PLUGGABLE DATABASE &2 SAVE STATE;
exit