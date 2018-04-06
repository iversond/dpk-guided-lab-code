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
REMARK -- Replace <MANAGERPWD> with your password for system schema.

set echo on
spool dbowner.log

GRANT CREATE SESSION, CREATE TABLE TO PS IDENTIFIED BY PS;
CONNECT PS/PS@<PDB_SERVICE_NAME>;
CREATE TABLE PSDBOWNER (DBNAME VARCHAR2(8) NOT NULL, OWNERID VARCHAR2(8) NOT NULL ) TABLESPACE PSDEFAULT;
CREATE UNIQUE INDEX PS_PSDBOWNER ON PSDBOWNER (DBNAME) TABLESPACE PSDEFAULT;
CONNECT system/<MANAGERPWD>@<PDB_SERVICE_NAME>;
REVOKE CREATE SESSION, CREATE TABLE FROM PS;
ALTER USER PS QUOTA UNLIMITED ON PSDEFAULT;

spool off