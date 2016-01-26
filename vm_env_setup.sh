#!/bin/bash

vm=vm2
PROJECT_ROOT="/src"
IMAGE_PATH="/var/lib/libvirt/images/$vm.qcow2"
DISK_PATH="/var/lib/libvirt/images/$vm.disk.qcow2"
# DISK_PATH=${PROJECT_ROOT%/}/$vm.disk1.qcow2
XML_PATH="${PROJECT_ROOT%/}/$vm.xml"
ISO_NAME="Fedora-Server-DVD-x86_64-22.iso"
ISO_LOC="https://dl.fedoraproject.org/pub/fedora/linux/releases/22/Server/x86_64/os/"

# define client name here, ex: virbr0-xxx-xx
CLIENTS=""

echo `ps -aef | grep qemu-system-x86`

cleanup(){
	echo "cleaning up; removing ${PROJECT_ROOT%/}/<related files>.."
	rm -rf ${PROJECT_ROOT%/}/{kvm_io/,$vm.disk1.qcow2,$vm_snapshot,$vm.xml}
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
	wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/$vm.xml -O $XML_PATH
	if [ -f $XML_PATH ]; then
		echo -e "\e[1;42m $PROJECT_ROOT was created; VM's XML definition saved to $XML_PATH.. \e[0m"
	else
		echo -e "\e[1;31m failed to create $XML_PATH \e[0m"
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
	dnf install -q -y pbench-fio
	sed -i 's/ver=2.2.5/ver=2.2.8/g' /opt/pbench-agent/bench-scripts/pbench_fio
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

bootstrap_it(){
	dist=fedora22
	# cd ${PROJECT_ROOT%/}/ && wget $ISO_LOC
	# get the kickstart file
	wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/$dist-vm.ks -O ${PROJECT_ROOT%/}/$dist-vm.ks

	# virsh destroy $vm
	# virsh undefine $vm
	# virsh -q define $XML_PATH

	qemu-img create -q -f qcow2 $IMAGE_PATH 10G
	virt-install --name=$vm \
		--virt-type=kvm \
		--disk format=qcow2,path=$IMAGE_PATH \
		--vcpus=2 \
		--ram=1024 \
		--network bridge=virbr0 \
		--os-type=linux \
		--os-variant=$dist \
		--graphics none \
		--extra-args="ks=file:/$dist-vm.ks console=ttyS0,115200" \
		--initrd-inject=/src/$dist-vm.ks \
		--serial pty \
		--location=$ISO_LOC \
		--noreboot
		# --cdrom=${PROJECT_ROOT%/}/$ISO_NAME\

	# dnf install libguestfs-tools-c
	# virt-builder fedora-23 -o /var/lib/libvirt/images/$vm.qcow2 --format qcow2 --update --selinux-relabel --size 5G
	         
	virsh -q start $vm	
	qemu-img create -q -f qcow2 $DISK_PATH 500M
	wget https://raw.githubusercontent.com/arcolife/latency_analyzer/master/disk-native.xml -O ${PROJECT_ROOT%/}/disk-native.xml

	# echo -e "\e[1;33m sleeping for 10 seconds before attaching disk..\e[0m"
	# sleep 10
    while :; do
		# get the IP and check if machine is up and then issue attach disk command
    	VM_IP=$(arp -e | grep $(virsh domiflist $vm | tail -n 2  | head -n 1 | awk -F' ' '{print $NF}') | tail -n 1 | awk -F' ' '{print $1}')
    	IS_ALIVE=$(fping $VM_IP | grep alive)
    	if [[ ! -z $IS_ALIVE ]]; then
			virsh attach-device $vm ${PROJECT_ROOT%/}/disk-native.xml --persistent
			if [[ $(virsh list | grep $vm) ]]; then
				PID=`pgrep qemu-system-x86 | tail -n 1`
				echo $PID
				# virsh -q save $vm ${PROJECT_ROOT%/}/$vm_snapshot
				# echo -e "\e[1;42m $vm was running with PID $PID ..snapshot saved to $PROJECT_ROOT \e[0m"
			else
				echo -e "\e[1;31m FAILED! $vm couldn't start up. \e[0m"
				exit 1
			fi

			echo -e "\e[1;33m sleeping for 2 seconds before shutting down..\e[0m"
			sleep 2
			virsh shutdown $vm
		else
		    echo "VM not ready yet (can't attach disk); sleeping for 2 secs"
		    sleep 2
		fi
    done		    		
}

run_workload(){
	# run kvm_io/bench_iter.sh
	virsh start $vm
	# virsh restore ${PROJECT_ROOT%/}/$vm_snapshot
	# qemu-img info master.qcow2
	cd ${PROJECT_ROOT%/}/kvm_io/
	chmod +x bench_iter.sh
	./bench_iter.sh
}

process_data(){
	# see if we can graph the results nicely
	echo
}

install_requirements
bootstrap_it
# run_workload
# process_data
