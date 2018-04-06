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

REMARK -- These are the minimum privileges required to run PeopleSoft
REMARK -- applications.  If you plan to run SQL<>Secure, you will need to
REMARK -- grant "execute any procedure" to PSUSER and PSADMIN.

set echo on
spool psroles.log

DROP ROLE PSADMIN;
CREATE ROLE PSADMIN;
GRANT 
CREATE SESSION, 
CREATE  TABLE, 
CREATE  PROCEDURE, 
CREATE  SYNONYM,
CREATE  VIEW, 
CREATE  TRIGGER, 
CREATE DATABASE LINK,
CREATE MATERIALIZED VIEW 
TO PSADMIN ;

EXEC DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SYSTEM_PRIVILEGE -
    (GRANTEE_NAME => 'PSADMIN', PRIVILEGE_NAME => 'ADMINISTER_RESOURCE_MANAGER', -
     ADMIN_OPTION => TRUE);
spool off