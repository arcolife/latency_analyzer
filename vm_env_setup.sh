#!/bin/bash

vm=vm1
dist=fedora22
ISO_NAME="Fedora-Server-DVD-x86_64-22.iso"
ISO_LOC="https://dl.fedoraproject.org/pub/fedora/linux/releases/22/Server/x86_64/os/"

PROJECT_ROOT="/src"
IMAGE_PATH="/var/lib/libvirt/images/$vm.qcow2"
DISK_PATH="/var/lib/libvirt/images/$vm.disk.qcow2"
XML_PATH="${PROJECT_ROOT%/}/$vm.xml"

# define client name here, ex: virbr0-xxx-xx
CLIENT="virbr0"

echo `ps -aef |  egrep 'qemu-kvm|qemu-system-x86_64'`

cleanup(){
	echo "cleaning up; removing related files.."
	rm -rf ${PROJECT_ROOT%/}/ 
	# rm -rf $IMAGE_PATH $DISK_PATH

	xx=`virsh --version`
	if [ $? -eq 0 ]; then
		if [[ ! -z $(virsh list | grep running) ]]; then
			virsh destroy $vm
		fi
		virsh undefine $vm
	fi
}

user_interrupt(){
    echo -e "\e[1;31m \n\nKeyboard Interrupt detected. \e[0m"
    echo -e "\e[1;31m Stopping KVM env bootstrap script... \e[0m"
    cleanup
    exit 1
}

trap user_interrupt SIGINT
trap user_interrupt SIGTSTP

install_requirements(){
	cleanup
	echo -e "\e[1;33m Initiating requirements installation..\e[0m"
	# create project location and download $vm.xml 
	mkdir $PROJECT_ROOT
	dnf install -q -y wget
	wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/$dist-vm.ks -O ${PROJECT_ROOT%/}/$dist-vm.ks

	if [ -f ${PROJECT_ROOT%/}/$dist-vm.ks ]; then
		# get the kickstart file
		echo -e "\e[1;42m $PROJECT_ROOT was created; \nAlso downloaded kickstart file to ${PROJECT_ROOT%/}/$dist-vm.ks.. \e[0m"
	else
		echo -e "\e[1;31m failed to download kickstart file \e[0m"
		exit 1
	fi

	# install virsh components
	dnf install -q -y @virtualization
	systemctl start libvirtd
	systemctl enable libvirtd
	virsh --version
	if [ $? -eq 0 ]; then
		echo -e "\e[1;42m virtualization components installed.. \e[0m"
	else
		echo -e "\e[1;31m FAILED! virtualization modules could not be installed.. \e[0m"
		exit 1
	fi

	# install pbench and fio
	dnf install -q -y dnf-plugins-core
	dnf copr enable -y ndokos/configtools
	dnf copr enable -y ndokos/pbench
	# for testing in containers, use --nogpgcheck with dnf install -q of COPR repos
	dnf install -q -y pbench-agent
	dnf install -q -y pbench-fio fio
	FIO_VERSION=$(/usr/bin/fio --version | sed s/fio-//g)
	sed -i s/ver=2.2.5/ver=$FIO_VERSION/g /opt/pbench-agent/bench-scripts/pbench_fio
	source /etc/profile.d/pbench-agent.sh
	register-tool-set
	which pbench_fio
	if [ $? -eq 0 ]; then
		echo -e "\e[1;42m pbench/fio installed.. \e[0m"
	else
		echo -e "\e[1;31m FAILED! Pbench could not be installed.. \e[0m"
		exit 1
	fi

	# install perf-script-postprocessor
	pip2 install -q perf-script-postprocessor
	perf_script_processor -h
	if [ $? -eq 0 ]; then
		echo -e "\e[1;42m perf-script-postprocessor installed.. \e[0m"
	else
		echo -e "\e[1;31m FAILED! perf-script-postprocessor could not be installed.. \e[0m"
		exit 1
	fi

	# setup git and clone https://github.com/psuriset/kvm_io.git
	dnf install -q -y git 
	git clone -q https://github.com/psuriset/kvm_io.git ${PROJECT_ROOT%/}/kvm_io

	if [ -f ${PROJECT_ROOT%/}/kvm_io/bench_iter.sh ]; then
		echo -e "\e[1;42m ${PROJECT_ROOT%/}/kvm_io was created.. \e[0m"
	else
		echo -e "\e[1;31m failed to create ${PROJECT_ROOT%/}/kvm_io \e[0m"
		exit 1
	fi

	# install blockIO trace/debug tools
	# strace, perf trace, perf record, perf trace record
	# pbench installs perf; but just to be sure..
	dnf install -q -y strace perf
	xx=`perf --help && strace -h`
	if [ $? -eq 0 ]; then
		echo -e "\e[1;42m Debuggers: perf & strace installed.. \e[0m"
	else
		echo -e "\e[1;31m FAILED! perf/strace could not be installed.. \e[0m"
		exit 1
	fi

	dnf install -q -y fping 
	xx=`fping -h`
	if [ $? -eq 0 ]; then
		echo -e "\e[1;42m fping installed.. \e[0m"
	else
		echo -e "\e[1;31m FAILED! fping could not be installed.. \e[0m"
		exit 1
	fi

	echo -e "\e[1;32m ALL requirements satisfied.. \e[0m"
}

attach_disk(){
	wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/disk-native.xml -O ${PROJECT_ROOT%/}/disk-native.xml
    while :; do
		# get the IP and check if machine is up and then issue attach disk command
		echo -e "\e[1;33m Attempting to get IP of $vm.. \e[0m"
    	VM_IP=$(arp -e | grep $(virsh domiflist $vm | tail -n 2  | head -n 1 | awk -F' ' '{print $NF}') | tail -n 1 | awk -F' ' '{print $1}')
    	if [[ ! -z $VM_IP ]]; then
	    	while :; do
				echo -e "\e[1;33m Attempting to get IP of $vm.. \e[0m"
				VM_IP=$(arp -e | grep $(virsh domiflist $vm | tail -n 2  | head -n 1 | awk -F' ' '{print $NF}') | tail -n 1 | awk -F' ' '{print $1}')
				echo -e "\e[1;33m Attempting to contact $vm at $VM_IP.. \e[0m"
		    	IS_ALIVE=$(fping $VM_IP | grep alive)
		    	if [[ ! -z $IS_ALIVE ]]; then
		    		sed -i "s/vm1/$vm/g" ${PROJECT_ROOT%/}/disk-native.xml
					virsh attach-device $vm ${PROJECT_ROOT%/}/disk-native.xml --persistent
					break
				else
				    echo "VM not ready yet (can't attach disk); sleeping for 2 secs"
				    sleep 2
				fi
			done
			break
		else
		    echo "No IP found for $vm yet.. sleeping for 2 secs."
		    sleep 5
		fi
    done	
}

bootstrap_it(){
	# cd ${PROJECT_ROOT%/}/ && wget $ISO_LOC
	echo -e "\e[1;33m Starting bootstrap process..\e[0m"

	if [[ ! -f $IMAGE_PATH ]]; then
		XML_FLAG=0
		qemu-img create -q -f qcow2 $IMAGE_PATH 10G
		chown -R qemu:qemu $IMAGE_PATH
		echo -e "\e[1;32m created qcow2 image of 10G. Next: kicking off virt-install..\e[0m"
		virt-install --name=$vm \
			--virt-type=kvm \
			--disk format=qcow2,path=$IMAGE_PATH \
			--vcpus=2 \
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
			# --cdrom=${PROJECT_ROOT%/}/$ISO_NAME\
	else
		XML_FLAG=1
		wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/$vm.xml -O $XML_PATH
		if [ -f $XML_PATH ]; then
			echo -e "\e[1;42m $PROJECT_ROOT was created; VM's XML definition saved to $XML_PATH.. \e[0m"
		else
			echo -e "\e[1;31m failed to create $XML_PATH \e[0m"
		fi
		sed -i "s/vm1/$vm/g" $XML_PATH
		virsh -q define $XML_PATH
	fi

	# dnf install libguestfs-tools-c
	# virt-builder fedora-23 -o /var/lib/libvirt/images/$vm.qcow2 --format qcow2 --update --selinux-relabel --size 5G
	         
	if [[ ! -f $DISK_PATH ]]; then
		qemu-img create -q -f qcow2 $DISK_PATH 1G
		chown -R qemu:qemu $DISK_PATH
		echo -e "\e[1;32m created /dev/vdb (additional disk)..\e[0m"
	fi
	
	virsh -q start $vm	
	echo -e "\e[1;32m started $vm..\e[0m"

	if [ $XML_FLAG -eq 0 ]; then
		attach_disk
	fi

	if [[ $(virsh list | grep $vm) ]]; then
		PID=`pgrep 'qemu-kvm|qemu-system-x86' | tail -n 1`
		echo "qemu PID: $PID"
		# virsh -q save $vm ${PROJECT_ROOT%/}/$vm_snapshot
		# echo -e "\e[1;42m $vm was running with PID $PID ..snapshot saved to $PROJECT_ROOT \e[0m"
	else
		echo -e "\e[1;31m FAILED! $vm couldn't start up. \e[0m"
		exit 1
	fi

	echo -e "\e[1;33m sleeping for 2 seconds before shutting down..\e[0m"
	sleep 2

	# TODO: figure out why it takes time to exec shutdown signal; 
	#		destroy for now. Use XML to define next time.
	# virsh shutdown $vm
	# OR use this:
	# /src/kvm_io/shutdown-all-vms
	virsh destroy $vm
	# virsh undefine $vm
}

run_workload(){
	# run kvm_io/bench_iter.sh
	echo -e "\e[1;33m Running workload..\e[0m"
	virsh start $vm
	VM_IP=$(arp -e | grep $(virsh domiflist $vm | tail -n 2  | head -n 1 | awk -F' ' '{print $NF}') | tail -n 1 | awk -F' ' '{print $1}')
	# virsh restore ${PROJECT_ROOT%/}/$vm_snapshot
	# qemu-img info master.qcow2
	cd ${PROJECT_ROOT%/}/kvm_io/
	chmod +x bench_iter.sh

	# TODO: add ssh keys 
	./bench_iter.sh $VM_IP

	virsh destroy $vm
}

process_data(){
	# see if we can graph the results nicely
	echo -e "\e[1;33m Processing data (analyzing latency)..\e[0m"
	# TODO: modify /etc/delta_processor.conf
	# set the below paths / commands to run in loop over a debug data:
	# DATA_PATH = 
	# perf_script_processor -t 0 -p $DATA_PATH
}

# TODO: provide option to select whether to 
# 		run benchmark directly or bootstrap first
install_requirements
bootstrap_it
# run_workload
# process_data
