#!/bin/bash
###########################################################################
#    Copyright (C) 2021  Gleb Otochkin
#
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>
###########################################################################
#  Script to clean database and host names in the AWR miner output 
#  Works with multiple files in the provided directory. 
#  All files have to have ".out" extension 
#  Created and tested on macOS 
#  Please take a backup copy of files 
#
#   MODIFIED   (yyyy/mm/dd)
#   Gleb Otochkin   2021/04/24 - added support for Solaris, Linux and Mac

usage() {
cat<<EOF
clear_awr_miner.sh: version 1.00
usage:
       $0 [awr miner dir with the *.out file names] [new db name] [new hosts name]
       awr miner file *.out name  - file name to clean up (required)
       new db name - new bogus database name (optional)
       new hosts name - new bogus hosts name (optional)
EOF
}


if [[ $# -lt 1 ]] ; then
    echo "Wrong number of arguments!"
    usage
    exit 1
fi
if [[ $# -lt 2 ]] ; then
    db_new_name_tpl="ORADB"
else 
    db_new_name_tpl=$2
fi
if [[ $# -lt 3 ]] ; then
    hosts_new_tpl="hostname"
else
    hosts_new_tpl=$3
fi
if [[ $# -gt 3 ]] ; then
    echo "Wrong number of arguments!"
    usage
    exit 1
fi
db_new_name_lowcase=`echo $db_new_name | awk '{print tolower($0)}'`
i=1
for file in "$1"/*.out
do
    db_name=`grep DB_NAME $file | awk '{print $2}'`
    hosts_nxt=`grep HOSTS $file | awk '{print $2}'`
    if [[ $hosts_nxt == $hosts ]] ; then
        hosts=$hosts
    else
        hosts_new=$hosts_new_tpl$i
        hosts=$hosts_nxt
    fi
    db_new_name=$db_new_name_tpl$i
    PLATFORM=`uname`
    case $PLATFORM in
    Darwin)
            db_name_lowcase=`echo $db_name | awk '{print tolower($0)}'`
            db_new_name_lowcase=`echo $db_new_name | awk '{print tolower($0)}'`
            echo $db_name $hosts $db_name_lowcase $db_new_name $db_new_name_lowcase
            sed -i .bak "s/${db_name}/${db_new_name}/g"  "$file"
            sed -i .bak "s/${db_name_lowcase}/${db_new_name_lowcase}/g"  "$file"
            sed -i .bak "s/${hosts}/${hosts_new}/g"  "$file"
            rm "$file".bak
            ;;
    SunOS)
            db_name_lowcase=`echo $db_name | gawk '{print tolower($0)}'`
            db_new_name_lowcase=`echo $db_new_name | gawk '{print tolower($0)}'`
            echo $db_name $hosts $db_name_lowcase $db_new_name $db_new_name_lowcase
            sed "s/${db_name}/${db_new_name}/g"  "$file" > "$file".bak && cat "$file".bak > "$file"
            sed "s/${db_name_lowcase}/${db_new_name_lowcase}/g" "$file" > "$file".bak && cat "$file".bak > "$file"
            sed "s/${hosts}/${hosts_new}/g" "$file" > "$file".bak && cat "$file".bak > "$file"
            rm "$file".bak
            ;;
    Linux)
            db_name_lowcase=`echo $db_name | awk '{print tolower($0)}'`
            db_new_name_lowcase=`echo $db_new_name | awk '{print tolower($0)}'`
            echo $db_name $hosts $db_name_lowcase $db_new_name $db_new_name_lowcase
            sed -i "s/${db_name}/${db_new_name}/g"  "$file"
            sed -i "s/${db_name_lowcase}/${db_new_name_lowcase}/g"  "$file"
            sed -i "s/${hosts}/${hosts_new}/g"  "$file"
            ;;
    *)
            echo "Unknown OS!"
            ;;
    esac
    let i++
done


