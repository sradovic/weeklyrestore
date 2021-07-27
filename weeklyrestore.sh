#!/bin/bash


function usage()
{
  echo "Command Syntax: ";
  echo;
  echo "    $0 -h <site> -m <db_user> -D <db_host> -d <db_service> -s <db_sid> -S <db_scan_addr> -t <type> ";
  echo;
  echo "      where: ";
  echo "             -h site             Fully qualified name of site being built ";
  echo "             -d restore date/time "
  echo "             -c jdbc connection string"
  echo;
  echo "      example: ";
  echo "             $0 -h lpl-custsupport-005.web.dem.ch3.bmi ";
  echo;
  exit;
}

echo ""
echo "  Server bmsrv0212 is in UTC time zone. Restore time has to be in UTC timezone"
echo ""
printf "Enter date of restore (mm/dd/yyyy): \n";
                                        read x ;
printf "Enter time of restore (hh(0-24):mm(0-59)): \n";
                                        read y ;
printf "Enter fqdn site name: \n";
                                        read z ;
printf "Enter jdbc string: \n";
                                        read w ;

#"12:15 12/19/2018"

d="$y $x"
h=$z
jdbc=$w
printf "\n\n\n\n\n\n";
printf "========================================================\n";
echo "Restore time:  $d"
echo "Site that  is going to be restore fqdn: $h"
echo "jdbc string for restored db: $jdbc"
printf "========================================================\n";

printf "Looks good?: (y/n) \n";
                        read x ;
                        if [[ ${x} == 'y' ]]
                                then
                                   DATA_CENTER=`echo ${z} | cut -d. -f4`;
                                   if [[ ${DATA_CENTER} == 'dc3' ]]; then
                                       ./cleanVm_weeklyrestore ;
                                       ./frontend_weeklyrestore_DC3.sh -f $h -d "$d" ;
                                       ./Container_restore_weeklyrestore_jdbc_DC3.sh $jdbc ;
                                   elif [[ ${DATA_CENTER} == 'ch3' ]]; then
                                       ./cleanVm_weeklyrestore ;
                                       ./frontend_weeklyrestore_CH3.sh -f $h -d "$d" ;
                                       ./Container_restore_weeklyrestore_jdbc.sh $jdbc ;
                                   elif  [[ ${DATA_CENTER} == 'com' ]]; then
                                        echo " AM3 data center"
                                   else
                                       echo "Wrong data center ID!!!!"
                                       exit 1;
                                   fi
                        fi;

echo ""

echo ""
