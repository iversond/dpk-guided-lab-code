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

REMARK -- This script sets up the PeopleSoft Owner ID.  An Oracle DBA is
REMARK -- required to run this script.
REMARK -- Replace <MANAGERPWD> with your password for system schema.



set echo on
spool psadmin.log

ACCEPT ADMIN CHAR FORMAT 'A8' -
PROMPT 'Enter name of PeopleSoft Owner ID(max. 8 characters): '
ACCEPT PASSWORD CHAR FORMAT 'A30' -
PROMPT 'Enter PeopleSoft Owner ID password(max. 30 characters): '
PROMPT
PROMPT Enter a desired default tablespace for this user.
PROMPT
PROMPT Please Note:  The tablespace must already exist
PROMPT               If you are unsure, enter PSDEFAULT or SYSTEM
PROMPT
ACCEPT TSPACE CHAR PROMPT 'Enter desired default tablespace:'


REMARK -- Create the PeopleSoft Administrator schema.

create user &ADMIN identified by &PASSWORD default tablespace &TSPACE
temporary tablespace pstemp;
grant PSADMIN TO &ADMIN;

REMARK -- PeopleSoft Administrator needs unlimited tablespace in order to
REMARK -- create the PeopleSoft application tablespaces and tables in Data
REMARK -- Mover.  This system privilege can only be granted to schemas, not
REMARK -- Oracle roles.

grant unlimited tablespace to &ADMIN;

REMARK -- Run the commands below to create database synonyms.
REMARK -- Modify the connect string appropriately for your organization.
REMARK -- Replace <PDB_SERVICE_NAME> with your Pluggable database name.
REMARK -- Replace <systempwd> with your system password

connect system/<MANAGERPWD>@<PDB_SERVICE_NAME>

set echo off

@%ORACLE_HOME%\rdbms\admin\catdbsyn
@%ORACLE_HOME%\sqlplus\admin\pupbld

REMARK -- Run the commands below to create materialized view analysis table 
REMARK -- Modify the connect string appropriately for your organization.

connect &ADMIN/&PASSWORD@<PDB_SERVICE_NAME>

set echo off

@%ORACLE_HOME%\rdbms\admin\utlxmv

spool off
