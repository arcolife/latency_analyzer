#!/bin/bash

PROJECT_ROOT='/src'
QCOW_FILE_PATH='/var/lib/libvirt/images/vm1.qcow2'
QCOW_BLOCK_PATH=${PROJECT_ROOT%/}/vm1.disk1.qcow2
XML_PATH="${PROJECT_ROOT%/}/vm1.xml"

echo `ps -aef | grep qemu-system-x86`

# define client name here, ex: virbr0-xxx-xx
CLIENTS=''

user_interrupt(){
    echo -e "\e[1;31m \n\nKeyboard Interrupt detected. \e[0m"
    echo -e "\e[1;31m Stopping KVM env bootstrap script... \e[0m"
    exit
}

trap user_interrupt SIGINT
trap user_interrupt SIGTSTP

cleanup(){
	echo "cleaning up.."
	rm -f ${PROJECT_ROOT%/}/vm1_snapshot
}

install_requirements(){
	echo -e "\e[1;33m Initiating requirements installation..\e[0m\n"
	# create project location and download vm1.xml 
	mkdir $PROJECT_ROOT
	dnf install -y wget
	wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/vm1.xml -O $XML_PATH
	if [ -f $XML_PATH ]; then
		echo -e "\e[1;42m $PROJECT_ROOT was created; VM's XML definition saved to $XML_PATH.. \e[0m"
	else
		echo -e "\e[1;31m failed to create $XML_PATH \e[0m"
		exit 1
	fi

	# install virsh components
	dnf install -y @virtualization
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
	dnf install -y dnf-plugins-core
	dnf copr enable -y ndokos/configtools
	dnf copr enable -y ndokos/pbench
	# for testing in containers, use --nogpgcheck with dnf install of COPR repos
	dnf install -y pbench-agent
	dnf install -y pbench-fio
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
	if [ $? -eq 0 ]; then
		echo $(perf_script_processor -h)
		echo -e "\e[1;42m perf-script-postprocessor installed.. \e[0m"
	else
		echo -e "\e[1;31m FAILED! perf-script-postprocessor could not be installed.. \e[0m"
		exit 1
	fi

	# setup git and clone https://github.com/psuriset/kvm_io.git
	dnf install -y git 
	git clone https://github.com/psuriset/kvm_io.git ${PROJECT_ROOT%/}/kvm_io

	# install blockIO trace/debug tools
	# perf trace
	# strace
	# perf record
	# perf trace record

	echo -e "\e[1;32m ALL requirements satisfied.. \e[0m"

}

bootstrap_it(){
	qemu-img create -f qcow2 $QCOW_BLOCK_PATH 2G	
	qemu-img create -f qcow2 $QCOW_FILE_PATH 2G	
	virsh define $XML_PATH
	virsh start vm1
	if [[ -z $(virsh list | grep vm1) ]]; then
		virsh save vm1 ${PROJECT_ROOT%/}/vm1_snapshot
		# virsh restore ${PROJECT_ROOT%/}/vm1_snapshot
		echo -e "\e[1;42m vm1 is now running. \e[0m"
	else
		echo -e "\e[1;31m FAILED! vm1 couldn't start up. \e[0m"
		exit 1
	fi
	PID=`pgrep qemu-system-x86 | tail -n 1`
}

attach_disk(){
	# use kvm_io
	echo
}

run_workload(){
	# run kvm_io/bench_iter.sh
	echo
}

process_data(){
	# see if we can graph the results nicely
	echo
}

install_requirements
# bootstrap_it
# attach_disk
# run_workload
# process_data