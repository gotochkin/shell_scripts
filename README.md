# Various shell scripts for automation and administration
duplicate_from_backup.sh - Script to duplicate/refresh database using source backup. The script required to have at least pfile for the new database.
                           The cleaning from the old database using 2 steps where the first is a standard RMAN command to delete database and 
                           the second is for cleaning from any orphan files in two diskgroups. 
clear_awr_miner.sh  -   Script to clear AWR miner ".out" file from database and host name replacing by a predefined bogus names
clear_awr_miner_dir.sh  -   Script to clear multiple  AWR miner ".out" files in a directory replacing atabase and host name by a predefined bogus names
