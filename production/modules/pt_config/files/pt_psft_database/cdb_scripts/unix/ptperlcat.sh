#!/bin/sh
# ***************************************************************
#  This software and related documentation are provided under a
#  license agreement containing restrictions on use and
#  disclosure and are protected by intellectual property
#  laws. Except as expressly permitted in your license agreement
#  or allowed by law, you may not use, copy, reproduce,
#  translate, broadcast, modify, license, transmit, distribute,
#  exhibit, perform, publish or display any part, in any form or
#  by any means. Reverse engineering, disassembly, or
#  decompilation of this software, unless required by law for
#  interoperability, is prohibited.
#  The information contained herein is subject to change without
#  notice and is not warranted to be error-free. If you find any
#  errors, please report them to us in writing.
#  
#  Copyright (C) 1988, 2017, Oracle and/or its affiliates.
#  All Rights Reserved.
# ***************************************************************

# This script has to be run for creating all the Data Dictionary views for an Oracle12c database.
# We need to run this script by entering into the directory $ORACLE_HOME/rdbms/admin.
# Replace the <mount> with the actual mount point.
cd $ORACLE_HOME/rdbms/admin
$ORACLE_HOME/perl/bin/perl catcon.pl -d $ORACLE_HOME/rdbms/admin -l /<mount>/oradata/<SID>/logs -b pdb catalog.sql
$ORACLE_HOME/perl/bin/perl catcon.pl -d $ORACLE_HOME/rdbms/admin -l /<mount>/oradata/<SID>/logs -b pdbproc catproc.sql
