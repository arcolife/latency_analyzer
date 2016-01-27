#!/bin/bash

for vm in `virsh list | grep running | awk '{print $2}'`; do
    virsh destroy $vm
    virsh undefine $vm
    vms="[$vm]$vms"
done

echo waiting for VMs to shut down
while [ ! -z "$vms" ]; do
        sleep 1
        for vm in `echo $vms | sed -e 's/\]/ /g' -e 's/\[/ /g'`; do
                virsh list | grep -q "$vm " || vms=`echo $vms | sed -e 's/\['$vm'\]//'`
                #echo vms is now: $vms
        done
done

echo all VMs have shut down
