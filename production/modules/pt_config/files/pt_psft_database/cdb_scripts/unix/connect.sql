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

REMARK -- This script sets up the PeopleSoft Connect ID.
REMARK -- An Oracle DBA is required to run this script prior
REMARK -- to loading a PSOFT database.
REMARK -- Create the PeopleSoft Administrator schema.

set echo on
spool connect.log

ACCEPT CONNECTID CHAR FORMAT 'A8' -
PROMPT 'Enter name of PeopleSoft Connect ID(max. 8 characters): '
ACCEPT CONNECTPWD CHAR FORMAT 'A30' -
PROMPT 'Enter PeopleSoft Connect ID password(max. 30 characters): '
PROMPT

create USER &CONNECTID identified by &CONNECTPWD default tablespace PSDEFAULT
temporary tablespace PSTEMP;

GRANT CREATE SESSION to &CONNECTID;
GRANT SELECT ON PS.PSDBOWNER TO &CONNECTID;

spool off

