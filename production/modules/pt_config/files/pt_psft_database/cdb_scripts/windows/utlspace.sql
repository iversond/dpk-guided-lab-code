-- ***************************************************************
--  This software and related documentation are provided under a
--  license agreement containing restrictions on use and
--  disclosure and are protected by intellectual property
--  laws. Except as expressly permitted in your license agreement
--  or allowed by law, you may not use, copy, reproduce,
--  translate, broadcast, modify, license, transmit, distribute,
--  exhibit, perform, publish or display any part, in any form or
--  by any means. Reverse engineering, disassembly, or
--  decompilation of this software, unless required by law for
--  interoperability, is prohibited.
--  The information contained herein is subject to change without
--  notice and is not warranted to be error-free. If you find any
--  errors, please report them to us in writing.
--  
--  Copyright (C) 1988, 2017, Oracle and/or its affiliates.
--  All Rights Reserved.
-- ***************************************************************
 
 
--                                                                    
-- ******************************************************************
-- ******************************************************************
--
--                          
--
--                                                                  
--
-- ******************************************************************

REMARK -- Replace <PDB_SERVICE_NAME> with your Pluggable database name.
REMARK -- Replace <drive> with your Windows Drive.
REMARK -- This script has to run as "sqlplus / as sysdba" 

REM * Set terminal output and command echoing on; log output of this script.
REM *
set termout on

REM * The database should already be started up at this point from createdb.sql

set echo off

REM * Alter the session to connect to the PDB
ALTER SESSION SET CONTAINER = <PDB_SERVICE_NAME>; 

REM * Creates views of oracle locks
REM @%ORACLE_HOME%\rdbms\admin\catblock.sql;

set echo on
spool utlspace.log

REM * Create a temporary tablespace for database users.
REM *
CREATE TEMPORARY TABLESPACE PSTEMP
TEMPFILE              '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\pstemp01.dbf'            SIZE 300M
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 128K
;

REM * Create a tablespace for database users default tablespace.
REM *
CREATE TABLESPACE       PSDEFAULT
DATAFILE              '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\psdefault.dbf'           SIZE 100M
EXTENT MANAGEMENT LOCAL AUTOALLOCATE
SEGMENT SPACE MANAGEMENT AUTO
;

spool off