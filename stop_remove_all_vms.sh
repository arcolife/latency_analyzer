#!/bin/bash

usage(){
  echo "Usage: # $0 [OPTIONS]"
  echo "Following are optional args, defaults of which are present in script itself.."
  echo -e "\n[-o specify functionalities as following]"
  echo -e "\t0 -> stop all vms\n\t1 -> stop and remove all vms"
  echo -e "\nexample: ./stop_remove_all_vms.sh -o 0";
}


[ $# = 0 ] && {
  usage
  exit -1;
}

while getopts "h?o:" opt; do
    case "$opt" in
        h|\?)
            usage
            exit 0
            ;;
        o)  OPTION=$OPTARG
            ;;
    esac
done

stop_vms(){
  for vm in `virsh list | grep running | awk '{print $2}'`; do
    virsh destroy $vm
    vms="[$vm]$vms"
  done
}

remove_vms(){
  for vm in `virsh list | grep running | awk '{print $2}'`; do
    virsh destroy $vm
    virsh undefine $vm
    vms="[$vm]$vms"
  done
}

if [[ $OPTION -eq 0 ]]; then
  stop_vms
elif [[ $OPTION -eq 1 ]]; then
  remove_vms
else
  echo -e "\e[1;33m option selected is out of choice. Quitting..\e[0m"
  exit -1
fi

while [ ! -z "$vms" ]; do
  echo waiting for VMs to shut down
  sleep 1
  for vm in `echo $vms | sed -e 's/\]/ /g' -e 's/\[/ /g'`; do
    virsh list | grep -q "$vm " || vms=`echo $vms | sed -e 's/\['$vm'\]//'`
  done
done

echo all VMs have shut down
