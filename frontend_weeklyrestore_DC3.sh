#! /bin/bash
#

sshOpts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
bckHost="dc3-bkp-zfs-1.mgt.dc3.bmi";
#repo="/BMI-Repo"
repo="/BMI-Repo2"
fHost=''
tHost='weeklyrestore.web.dem.ch3.bmi'
rDate=''

function usage()
{
  echo "Command Syntax: "
  echo 
  echo "    $0 -f <host> -t <to-host> -d <date> "
  echo 
  echo "      where: "
  echo "             -f host      Fully qualified name of backed up from host "
  echo "             -t to-host   Fully qualified name of host to restore backup to"
  echo "             -d date      Date stamp of when the to restore to"
  echo 
  echo "      example: "
  echo '             restoreVm.sh -f custsupport-005.web.dem.bmi -t lpl-custsupport-005.web.dem.bmi -d "12:15 12/19/2018"'
  echo 
  exit
}

while getopts "f:d:" o; do
  case "${o}" in
    f)
      fHost=${OPTARG};
      if [[ $(ssh ${sshOpts} ${bckHost} "ls -d ${repo}/${fHost} 2>/dev/null | grep -c ^ " 2>/dev/null) -eq 0 ]]; then
        echo " Backups of host ${fHost} were not found " && usage;
      fi
      ;;
#    t)
#      tHost=${OPTARG};
#      hTest=$(ssh ${sshOpts} ${tHost} "hostname" 2>/dev/null);
#      if [[ "${tHost}" != "${hTest}" ]]; then
#        echo " Target host ${tHost} failed hostname test with a return of: ${hTest} " && usage;
#      fi
#      ;;
    d)
      rDate=${OPTARG};
      ;;
    *)
      usage;
      ;;
  esac
done

hTest=$(ssh ${sshOpts} ${tHost} "hostname" 2>/dev/null);
      if [[ "${tHost}" != "${hTest}" ]]; then
        echo " Target host ${tHost} failed hostname test with a return of: ${hTest} " && usage;
      fi


if [[ "$fHost" == "" ]]; then
  echo "Backed up host not specified" && usage
fi
if [[ "$tHost" == "" ]]; then
  echo "Target host not specified" && usage
fi
bDate=$(date -d "${rDate}" +%s)

f=0
c=0
#ssh ${sshOpts} ${bckHost} "stat --format='%Y:%n' ${repo}/${fHost}/*.tar | sort -r" 2>/dev/null


for fName in `ssh ${sshOpts} ${bckHost} "stat --format='%Y:%n' ${repo}/${fHost}/*.tar | sort -r" 2>/dev/null `; do
  dStamp=$(echo ${fName} | cut -f 1 -d ':')
  bFile=$(echo ${fName} | cut -f 2 -d ':')
  if [ $f -eq 0 ]; then
    if [ ${dStamp} -lt ${bDate} ]; then
      fStack=("${bFile}" "${fStack[@]}");
      let c=$c+1
      if [[ $bFile == *"FULL"* ]]; then
        f=1;
      fi
    fi
  fi
done

if [ $c -eq 0 ]; then
  echo ""
  echo "No backups found; exitting!!"
  exit 1;
fi

echo "Restoring from $c tar files"

ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${bckHost} "exit";
retIp=$(ssh ${sshOpts} ${bckHost} "ssh ${sshOpts} ${tHost} exit ");
#connIp=$(ssh ${sshOpts} ${bckHost} "/BMI-Backup/bin/BMI-ClientStatus.pl ${fHost} --show"  | grep ipAddress | cut -f4 -d"'" | cut -f1 -d"/")
cmd="echo \\\$SSH_CLIENT"

#retIp=$(ssh ${sshOpts} ${bckHost} "ssh ${sshOpts} ${connIp} ${cmd}" | cut -f1 -d' ');
retIp=$(ssh ${sshOpts} ${bckHost} "ssh ${sshOpts} ${tHost} ${cmd}" | cut -f1 -d' ');
sleep 1
echo "connIp:${connIp}; retIp:${retIp};"

for i in `echo ${fStack[@]}`; do
  echo "Restoring from backup: $i"
  ssh -t -t ${sshOpts} ${tHost} "cd /; ssh ${sshOpts} ${retIp} 'cat $i' | sudo tar xf - bigmac bmfs bmfsweb home/bm"
done
###  ssh -t -t ${sshOpts} ${tHost} "cd /; ssh ${sshOpts} ${bckHost} 'cat $i' | sudo tar xf - bigmac bmfs bmfsweb home/bm"
###  ssh -t -t ${sshOpts} ${bckHost} "cd /;  sudo cat $i" | ssh -t -t ${sshOpts} ${tHost} "cd /; sudo tar xf - bigmac bmfs bmfsweb home/bm"
###echo "File to restore $i"
#done
