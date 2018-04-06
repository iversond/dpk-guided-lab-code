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
REMARK -- This script has to run as "sqlplus / as sysdba" immediately after psroles.sql
 
set echo on
spool psroles2.log

ALTER SESSION SET CONTAINER = <PDB_SERVICE_NAME>; 
GRANT SELECT ON V_$MYSTAT to PSADMIN;
GRANT SELECT ON  USER_AUDIT_POLICIES to PSADMIN;
GRANT SELECT ON FGACOL$  to PSADMIN;
GRANT EXECUTE ON DBMS_FGA to PSADMIN;

REM -- If using 12c (12.1.0.2.0 or higher) with the IMDB feature, 
REM -- the following two grants will be applied:
REM

SET SERVEROUTPUT ON
SET FEEDBACK ON

DECLARE
   Vdollarversion VARCHAR2(17);
BEGIN
    SELECT version 
    into  Vdollarversion
    FROM v$instance;
    DBMS_OUTPUT.PUT_LINE('Oracle Version: '|| Vdollarversion);
    IF Vdollarversion >= '12.1.0.2.0'
    THEN 
    DBMS_OUTPUT.PUT_LINE('EXEC 12c IMDB specific GRANTS');
    EXECUTE IMMEDIATE ('GRANT SELECT ON v_$im_column_level to PSADMIN');
    EXECUTE IMMEDIATE ('GRANT SELECT ON v_$im_user_segments to PSADMIN');
    ELSE
    DBMS_OUTPUT.PUT_LINE('IMDB grants not executed. IMDB feature is not available in this Oracle version.');
    END IF;   
END;
/

grant execute on DBMS_METADATA to PSADMIN;
grant execute on DBMS_MVIEW to PSADMIN;
grant execute on DBMS_SESSION to PSADMIN;
grant execute on DBMS_STATS to PSADMIN;
grant execute on DBMS_XMLGEN to PSADMIN;
grant execute on DBMS_APPLICATION_INFO to PSADMIN;
grant execute on dbms_refresh to PSADMIN;
grant execute on dbms_job to PSADMIN;
grant execute on dbms_lob to PSADMIN;
grant execute on DBMS_OUTPUT to PSADMIN;
grant select,insert,update,delete on PS.PSDBOWNER  to PSADMIN;
spool off