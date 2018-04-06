@echo off
rem ****************************************************************
rem  This software and related documentation are provided under a
rem  license agreement containing restrictions on use and
rem  disclosure and are protected by intellectual property
rem  laws. Except as expressly permitted in your license agreement
rem  or allowed by law, you may not use, copy, reproduce,
rem  translate, broadcast, modify, license, transmit, distribute,
rem  exhibit, perform, publish or display any part, in any form or
rem  by any means. Reverse engineering, disassembly, or
rem  decompilation of this software, unless required by law for
rem  interoperability, is prohibited.
rem  The information contained herein is subject to change without
rem  notice and is not warranted to be error-free. If you find any
rem  errors, please report them to us in writing.
rem  
rem  Copyright (C) 1988, 2017, Oracle and/or its affiliates.
rem  All Rights Reserved.
rem ******************************************************************
rem                                                                    
rem ******************************************************************
rem ******************************************************************
rem This script has to be run for creating all the Data Dictionary 
rem views for an Oracle12c database.
rem We need to run this script by entering into the directory 
rem    $ORACLE_HOME/rdbms/admin.                                                              
rem Replace the <mount> with the actual mount point.
rem ******************************************************************

cd %ORACLE_HOME%\rdbms\admin\
%ORACLE_HOME%\perl\bin\perl catcon.pl -d %ORACLE_HOME%\rdbms\admin\ -l <drive>:\oradata\<SID>\logs -b pdb catalog.sql
%ORACLE_HOME%\perl\bin\perl catcon.pl -d %ORACLE_HOME%\rdbms\admin\ -l <drive>:\oradata\<SID>\logs -b pdbproc catproc.sql
