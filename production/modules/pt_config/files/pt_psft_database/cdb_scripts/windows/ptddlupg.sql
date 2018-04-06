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
--  PEOPLESOFT 8 DATABASE UPGRADE DDL TO CREATE TABLESPACES - PT
-- ******************************************************************
-- ******************************************************************
--
--                          
--
--   $Header:
--
-- ******************************************************************
--
--  THIS SCRIPT BUILDS NEW TABLESPACES AS PART OF THE  UPGRADE.  THE REL%.SQL 
-- SCRIPT(S) CREATE TABLES IN THESE NEW TABLESPACE(S) AND IT IS NECESSARY TO RUN
--  THIS SCRIPT PRIOR TO RUNNING ANY REL%.SQL SCRIPTS. OTHERWISE YOU WILL RECEIVE
--  TABLESPACE NOT FOUND ERROR MESSAGES. RUN THIS SCRIPT ON ORACLE
--  USING SQLPLUS.
--
--  REQUIREMENTS
--        RUN THIS SCRIPT BEFORE RUNNING ANY REL%.SQL SCRIPTS
--
--  FOR YOUR INFORMATION
--        1) CREATE ALL TABLESPACE(S) BELOW. IF THE TABLESPACE(S)
--           ALREADY EXIST THEN YOU CAN REMOVE THESE TABLESPACE(S) FROM THE SCRIPT
--        2) PEOPLESOFT RECOMMENDS USING STANDARD TABLESPACE NAMES
--           AS SPECIFIED BELOW
--        3) GLOBALLY MAKE THE FOLLOWING EDITS:
--
--           CHANGE <drive> AND <SID> TO THE APPROPRIATE VALUES FOR YOUR SYSTEM

set echo on
spool ptddlupg.log

CREATE TABLESPACE PSIMAGE2 DATAFILE '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\psimage2.dbf' SIZE 400M
EXTENT MANAGEMENT LOCAL AUTOALLOCATE
SEGMENT SPACE MANAGEMENT AUTO
;
REMARK ALTER DATABASE DATAFILE '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\psimage2.dbf'
REMARK AUTOEXTEND ON NEXT 5M MAXSIZE UNLIMITED
REMARK ;

CREATE TABLESPACE PSMATVW  DATAFILE '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\psmatvw.dbf' SIZE 250M
EXTENT MANAGEMENT LOCAL AUTOALLOCATE
SEGMENT SPACE MANAGEMENT AUTO
;

REMARK ALTER DATABASE DATAFILE '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\psmatvw.dbf'
REMARK AUTOEXTEND ON NEXT 5M MAXSIZE UNLIMITED
REMARK ;

CREATE TEMPORARY TABLESPACE PSGTT01 TEMPFILE '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\psgtt01.dbf' SIZE 500M
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 128K
;

REMARK 
REMARK If this tempfile needs to be altered it can only be done with an Oracle User that has SYSDBA privileges.
REMARK 
REMARK ALTER DATABASE TEMPFILE '<drive>:\oradata\<SID>\<PDB_SERVICE_NAME>\psgtt01.dbf'
REMARK AUTOEXTEND ON NEXT 5M MAXSIZE UNLIMITED
REMARK ;
spool off
