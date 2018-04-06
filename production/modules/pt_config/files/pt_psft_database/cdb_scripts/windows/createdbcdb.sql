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

REMARK -- Review the parameters in this file and edit
REMARK -- for your environment.
REMARK -- Specifically -
REMARK -- Edit the MAXDATAFILES parameter to use the max
REMARK -- allowed by the operating system platform.
REMARK -- Replace <SID> with your SID.
REMARK -- Replace <mount> with your target mount point.
REMARK -- Edit logfile and datafile names.
REMARK -- Modify the CHARACTER SET if necessary.
REMARK -- This script is using character set WE8ISO8859P15.

set termout on
set echo on
spool createdbcdb.log

REMARK startup nomount pfile=%ORACLE_HOME%\dbs\init<SID>.ora

CREATE DATABASE   <SID>
    maxdatafiles  1021
    maxinstances  1
    maxlogfiles   8
    maxlogmembers 4
    CHARACTER SET WE8ISO8859P15
    NATIONAL CHARACTER SET UTF8
DATAFILE '<drive>:\oradata\<SID>\system01.dbf' SIZE 2000M REUSE AUTOEXTEND ON NEXT 10240K MAXSIZE UNLIMITED
EXTENT MANAGEMENT LOCAL
SYSAUX DATAFILE '<drive>:\oradata\<SID>\sysaux01.dbf' SIZE 120M REUSE AUTOEXTEND ON NEXT  10240K MAXSIZE UNLIMITED
DEFAULT TEMPORARY TABLESPACE TEMP TEMPFILE '<drive>:\oradata\<SID>\temp01.dbf' SIZE 20M REUSE AUTOEXTEND ON NEXT  640K MAXSIZE UNLIMITED
UNDO TABLESPACE "PSUNDOTS" DATAFILE '<drive>:\oradata\<SID>\psundots01.dbf' SIZE 300M REUSE AUTOEXTEND ON NEXT  5120K MAXSIZE UNLIMITED
LOGFILE GROUP 1 ('<drive>:\oradata\<SID>\redo01.log') SIZE 100M,
        GROUP 2 ('<drive>:\oradata\<SID>\redo02.log') SIZE 100M,
        GROUP 3 ('<drive>:\oradata\<SID>\redo03.log') SIZE 100M
enable pluggable database
seed file_name_convert=('<drive>:\oradata\<SID>\system01.dbf',
'<drive>:\oradata\<SID>\pdbseed\system01.dbf',
'<drive>:\oradata\<SID>\sysaux01.dbf',
'<drive>:\oradata\<SID>\pdbseed\sysaux01.dbf',
'<drive>:\oradata\<SID>\temp01.dbf',
'<drive>:\oradata\<SID>\pdbseed\temp01.dbf',
'<drive>:\oradata\<SID>\undotbs01.dbf',
'<drive>:\oradata\<SID>\pdbseed\undotbs01.dbf');
spool off
