 
 

set termout on
set echo on
set verify off

create pluggable database &2 ADMIN  user &2  identified by &2
FILE_NAME_CONVERT = ('&3\&1\pdbseed\', '&3\&1\&2\');

ALTER PLUGGABLE DATABASE &2 open;

exit
