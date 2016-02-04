#!/bin/bash

# After you run this script, run `virsh start vm1`
# use `virsh console vm1` to go inside vm1 and login
# using `root` -- `#devconf16`
# ..then verify /dev/vdb exists, by executing:
# `# fdisk -l`  inside vm1

PROJECT_ROOT=/src/
mkdir $PROJECT_ROOT
vm=vm1
CLIENT="virbr0"
dist=fedora22

ISO_LOC="https://dl.fedoraproject.org/pub/fedora/linux/releases/22/Server/x86_64/os/"
IMAGE_PATH="/var/lib/libvirt/images/$vm.qcow2"
DISK_PATH="/var/lib/libvirt/images/$vm.disk.qcow2"

qemu-img create -q -f qcow2 $IMAGE_PATH 10G
chown -R qemu:qemu $IMAGE_PATH

wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/$dist-vm.ks -O ${PROJECT_ROOT%/}/$dist-vm.ks

attach_disk(){
    wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/disk-native.xml -O ${PROJECT_ROOT%/}/disk-native.xml
    while :; do
        # get the IP and check if machine is up and then issue attach disk command
        echo -e "\e[1;33m Attempting to get IP of $vm.. \e[0m"
        VM_IPS=$(arp -e | grep $(virsh domiflist $vm | tail -n 2  | head -n 1 | awk -F' ' '{print $NF}') | tail -n 1 | awk -F' ' '{print $1}')
        if [[ ! -z $VM_IPS ]]; then
            array=($VM_IPS)
            for CURR_IP in "${array[@]}"; do
                echo -e "\e[1;33m Attempting to contact $vm at $CURR_IP.. \e[0m"
                # IS_ALIVE=$(fping $CURR_IP | grep alive)
                IS_ALIVE=$(ping $CURR_IP -c 1 -W 2 | grep "1 received")
                if [[ ! -z $IS_ALIVE ]]; then
                    sed -i "s/vm1/$vm/g" ${PROJECT_ROOT%/}/disk-native.xml
                    virsh attach-device $vm ${PROJECT_ROOT%/}/disk-native.xml --persistent
                    break
                else
                    echo "VM not ready yet (can't attach disk); sleeping for 2 secs"
                    sleep 2
                fi
            # done
            done
        else
            echo "No IP found for $vm yet.. sleeping for 2 secs."
            sleep 5
            continue
        fi
        break
    done   
}



virt-install --name=$vm \
    --virt-type=kvm \
    --disk format=qcow2,path= /var/lib/libvirt/images/$vm.qcow2 \
    --vcpus=1 \
    --ram=1024 \
    --network bridge=$CLIENT \
    --os-type=linux \
    --os-variant=$dist \
    --graphics none \
    --extra-args="ks=file:/$dist-vm.ks console=ttyS0,115200" \
    --initrd-inject=/src/$dist-vm.ks \
    --serial pty \
    --location=$ISO_LOC \
    --noreboot

qemu-img create -q -f qcow2 $DISK_PATH 100M
chown -R qemu:qemu $DISK_PATH
echo -e "\e[1;32m created /dev/vdb (additional disk)..\e[0m"

attach_disk
