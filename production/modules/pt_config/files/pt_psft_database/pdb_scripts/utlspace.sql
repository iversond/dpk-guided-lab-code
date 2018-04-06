 
 


REM * Set terminal output and command echoing on; log output of this script.
REM *
set termout on
set echo off
set verify off
set heading off

REM * The database should already be started up at this point from createdb.sql


REM * Alter the session to connect to the PDB
ALTER SESSION SET CONTAINER = &2; 

REM * Creates views of oracle locks
REM @%ORACLE_HOME%\rdbms\admin\catblock.sql;

REM * Create a temporary tablespace for database users.
REM *
CREATE TEMPORARY TABLESPACE PSTEMP
TEMPFILE              '&3\&1\&2\pstemp01.dbf'            SIZE 300M
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 128K
;

REM * Create a tablespace for database users default tablespace.
REM *
CREATE TABLESPACE       PSDEFAULT
DATAFILE              '&3\&1\&2\psdefault.dbf'           SIZE 100M
EXTENT MANAGEMENT LOCAL AUTOALLOCATE
SEGMENT SPACE MANAGEMENT AUTO
;

exit