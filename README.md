# Various shell scripts for automation and administration
duplicate_from_backup.sh - Script to duplicate/refresh database using source backup. The script required to have at least pfile for the new database.
                           The cleaning from the old database using 2 steps where the first is a standard RMAN command to delete database and 
                           the second is for cleaning from any orphan files in two diskgroups. 
