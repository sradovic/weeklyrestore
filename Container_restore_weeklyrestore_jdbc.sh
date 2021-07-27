#!/bin/bash
#
jdbc=$1
tHost='weeklyrestore.web.dem.ch3.bmi';
sshOpts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null';

function usage()
{
  echo "Command Syntax: ";
  echo;
  echo "    $0 -h <site> -m <db_user> -D <db_host> -d <db_service> -s <db_sid> -S <db_scan_addr> -t <type> ";
  echo;
  echo "      where: ";
  echo "             -h site             Fully qualified name of site being built ";
  echo;
  echo "      example: ";
  echo "             $0 -h lpl-custsupport-005.web.dem.ch3.bmi ";
  echo;
  exit;
}

#while getopts "h:" o; do
#  case "${o}" in
#    h)
#      tHost=${OPTARG};
#      hTest=$(ssh ${sshOpts} ${tHost} "hostname" 2>/dev/null);
#      if [[ "${tHost}" != "${hTest}" ]]; then
#        echo " Target host ${tHost} failed hostname test with a return of: ${hTest} " && usage;
#      fi
#      g_target=$(host ${hTest} | cut -f4 -d' ');
#      ;;
#     *)
#       usage;
#       ;;
#  esac
#done

[[ -z ${tHost} ]]          && ( echo "Site name (host) not provided!!!"; usage );

hTest=$(ssh ${sshOpts} ${tHost} "hostname" 2>/dev/null);
 if [[ "${tHost}" != "${hTest}" ]]; then
   echo " Target host ${tHost} failed hostname test with a return of: ${hTest} " && usage;
 fi
g_target=$(host ${hTest} | cut -f4 -d' ');


g_cpq_companyname=$(ssh ${sshOpts} -t -t ${tHost} "cd /bmfsweb ; sudo find  -maxdepth 1 -mindepth 1 ! -type l | grep -v jsmessage | grep -v mod.sh | head -1" )
g_cpq_companyname=$(basename ${g_cpq_companyname})
g_cpq_companyname="${g_cpq_companyname%%[[:cntrl:]]}"

echo "company name :$g_cpq_companyname"

site_version="`ssh ${sshOpts} ${tHost} 'grep ^bigmac.version /bigmac/conf/build.properties | cut -f2 -d='`"
echo " site_version   :$site_version"

case "${site_version}" in
    19.4.6|20.1.5|20.2.4|20.3.4|20.3.5|20.3.6|21.1.0|21.1.1|21.1.2|21.1.3)
      java_ver="1.8.0_271";
      ;;
    20.2.5|20.3.8|21.1.4|21.1.5|21.1.6|21.1.7|21.1.8|21.2.0|21.2.1|21.2.2|21.2.3)
      java_ver="1.8.0_281";
      ;;
    21.1.9|21.2.4|21.2.5|21.2.6|21.2.7)
      java_ver="1.8.0_291";
      ;; 
esac


echo "Java version is $java_ver"

###echo "Running steps to make sure Java is there and RNGD is running"

retIp=$(ssh ${sshOpts} -t -t ${tHost} "echo \$SSH_CLIENT" | cut -f1 -d' ')
ssh ${sshOpts} -t -t ${tHost} "cd /; ssh ${retIp} 'cat /Repo_Ops/components/java/$java_ver/jdk.tar.gz' | sudo tar xzf - " 2>/dev/null
ssh ${sshOpts} -t -t ${tHost} "sudo systemctl start rngd " 2>/dev/null
ssh ${sshOpts} -t -t ${tHost} "
                              sudo sed -i '/db_url=/c\db_url=${jdbc}' /bmfs/cpqShared/conf/database.properties;
                              "
#
#   Set up weave
#
echo "ssh ${sshOpts} -t -t ${tHost} "sudo /bigmac/container-setup/setupVm.sh" 2>/dev/null "
echo ""
ssh ${sshOpts} -t -t ${tHost} "sudo /bigmac/container-setup/setupVm.sh" 2>/dev/null 
#
#   Prep for creating the container
#
container_name=$(ssh ${sshOpts} ${tHost} "cat /bigmac/install/container_history" 2>/dev/null | grep ACTIVE | grep -v INACTIVE | cut -f1 -d' ')
container_ref=$(echo "$(echo ${container_name} | cut -f1 -d_)_$(echo ${container_name} | cut -f3 -d_)");
container_image=$(ssh ${sshOpts} ${tHost} "grep ^_CPQ /bigmac/install/constants_override" 2>/dev/null | grep _CPQ_IMAGE | cut -f2 -d= )
cpq_Id=$(ssh ${sshOpts} ${tHost} "cat /bigmac/install/container_history" 2>/dev/null | grep ACTIVE | grep -v INACTIVE | cut -f6 -d' ')
#
echo "company name  : $g_cpq_companyname"
echo "container name: $container_name"
echo "container_ref : $container_ref"
echo "container_image: $container_image"
echo "cpq_Id         : $cpq_Id"

#    Pull the container image
#
#echo "Running =>docker pull ${container_image}<"
echo ""
#echo " ssh ${sshOpts} -t -t ${thost} "sudo docker pull ${container_image}" 2>/dev/null"
ssh ${sshOpts} -t -t ${thost} "sudo docker pull ${container_image}" 2>/dev/null
#
#    Build the container
#
ssh ${sshOpts} -t -t ${tHost} "sudo /bigmac/container-setup/setupCpq.sh -k ${g_cpq_companyname} -n ${cpq_Id} -f ${container_ref} -i ${container_image} ${container_name}" 2>/dev/null 
#
#    Run something in the container
#
ssh ${sshOpts} -t -t ${tHost} "sudo  bash /bigmac/container-setup/runInContainer.sh -c ${container_name} -u bm 'bash  /bigmac/bin/run_tool.sh -generatei18njs'" 2>/dev/null 
#
#    Start the app in the container
#
echo ""
ssh ${sshOpts} -t -t ${tHost} "sudo bash /bigmac/container-setup/runInContainer.sh -c ${container_name} -u bm 'bash /bigmac/bin/cpqctl start ' "  2>/dev/null 
#
#    Set up routing to the container
#
echo ""
ssh ${sshOpts} -t -t ${tHost} "sudo bash /bigmac/container-setup/routeto.sh ${container_name} "  2>/dev/null 
#

ssh ${sshOpts} -t -t ${tHost} "
                              sudo sed -i '/ssl_url=/c\ssl_url=https://${g_cpq_companyname}-weeklyrestore.bigmachines.com' /bmfs/cpqShared/conf/server.properties;
                              sudo sed -i '/site_url=/c\site_url=https://${g_cpq_companyname}-weeklyrestore.bigmachines.com' /bmfs/cpqShared/conf/server.properties;
                              sudo sed -i '/override_outbound_email=/c\override_outbound_email=junk@bigmachines.com' /bmfs/cpqShared/conf/server.properties;
                              sudo /bigmac/bin/cpqctl restart server; 
                              " 


echo ""
echo""
echo "Update local host file (use external C:\Windows\System32\drivers\etc with: "
echo ""
echo "205.219.85.192 ${g_cpq_companyname}-weeklyrestore.bigmachines.com  ${g_cpq_companyname}-weeklyrestore"
echo ""
echo "and connect to : https://${g_cpq_companyname}-weeklyrestore.bigmachines.com"
