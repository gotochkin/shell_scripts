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
#  Created and tested on macOS 
#  Please take a backup copy of files 
#
#   MODIFIED   (yyyy/mm/dd)
#   Gleb Otochkin   2021/04/24 - added support for Solaris, Linux and Mac

usage() {
cat<<EOF
clear_awr_miner.sh: version 1.00
usage:
       $0 [awr miner file *.out name] [new db name] [new hosts name]
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
    db_new_name="ORADB"
else 
    db_new_name=$2
fi
if [[ $# -lt 3 ]] ; then
    hosts_new="hostname"
else
    hosts_new=$3
fi
if [[ $# -gt 3 ]] ; then
    echo "Wrong number of arguments!"
    usage
    exit 1
fi

db_name=`grep DB_NAME $1 | awk '{print $2}'`
hosts=`grep HOSTS $1 | awk '{print $2}'`
PLATFORM=`uname`
case $PLATFORM in
Darwin)
        db_name_lowcase=`echo $db_name | awk '{print tolower($0)}'`
        db_new_name_lowcase=`echo $db_new_name | awk '{print tolower($0)}'`
        echo $db_name $hosts $db_name_lowcase $db_new_name $db_new_name_lowcase
        sed -i .bak "s/${db_name}/${db_new_name}/g"  "$1"
        sed -i .bak "s/${db_name_lowcase}/${db_new_name_lowcase}/g"  "$1"
        sed -i .bak "s/${hosts}/${hosts_new}/g"  "$1"
        rm "$1".bak
        ;;
SunOS)
        db_name_lowcase=`echo $db_name | gawk '{print tolower($0)}'`
        db_new_name_lowcase=`echo $db_new_name | gawk '{print tolower($0)}'`
        echo $db_name $hosts $db_name_lowcase $db_new_name $db_new_name_lowcase
        sed "s/${db_name}/${db_new_name}/g"  "$1" > "$1".bak && cat "$1".bak > "$1"
        sed "s/${db_name_lowcase}/${db_new_name_lowcase}/g" "$1" > "$1".bak && cat "$1".bak > "$1"
        sed "s/${hosts}/${hosts_new}/g" "$1" > "$1".bak && cat "$1".bak > "$1"
        rm "$1".bak
        ;;
Linux)
        db_name_lowcase=`echo $db_name | awk '{print tolower($0)}'`
        db_new_name_lowcase=`echo $db_new_name | awk '{print tolower($0)}'`
        echo $db_name $hosts $db_name_lowcase $db_new_name $db_new_name_lowcase
        sed -i "s/${db_name}/${db_new_name}/g"  "$1"
        sed -i "s/${db_name_lowcase}/${db_new_name_lowcase}/g"  "$1"
        sed -i "s/${hosts}/${hosts_new}/g"  "$1"
        ;;
*)
        echo "Unknown OS!"
        ;;
esac



