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
REMARK -- Replace <PDB_SERVICE_NAME> with your Pluggable database name.
REMARK -- Replace <mount> with your target mount point.
REMARK -- Replace <SID> with your SID


create pluggable database <PDB_SERVICE_NAME> ADMIN  user <PDB_SERVICE_NAME>  identified by <PDB_SERVICE_NAME>
FILE_NAME_CONVERT = ('/<mount>/oradata/<SID>/pdbseed/', '/<mount>/oradata/<SID>/<PDB_SERVICE_NAME>/');

ALTER PLUGGABLE DATABASE <PDB_SERVICE_NAME> open;
