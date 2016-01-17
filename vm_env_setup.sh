#!/bin/bash

PROJECT_ROOT='/src'
QCOW_FILE_PATH='/var/lib/libvirt/images/vm1.qcow2'
QCOW_BLOCK_PATH=${PROJECT_ROOT%/}/vm1.disk1.qcow2
XML_PATH="${PROJECT_ROOT%/}/vm1.xml"

# define client name here, ex: virbr0-xxx-xx
CLIENTS=''

echo `ps -aef | grep qemu-system-x86`

cleanup(){
	echo "cleaning up; removing ${PROJECT_ROOT%/}/<related files>.."
	rm -rf ${PROJECT_ROOT%/}/{kvm_io/,vm1.disk1.qcow2,vm1_snapshot,vm1.xml}
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
	# create project location and download vm1.xml 
	mkdir $PROJECT_ROOT
	dnf install -q -y wget
	wget -q https://raw.githubusercontent.com/arcolife/latency_analyzer/master/vm1.xml -O $XML_PATH
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

	echo -e "\e[1;32m ALL requirements satisfied.. \e[0m"

}

bootstrap_it(){
	qemu-img create -q -f qcow2 $QCOW_BLOCK_PATH 2G	
	qemu-img create -q -f qcow2 $QCOW_FILE_PATH 2G	
	virsh -q define $XML_PATH
	virsh -q start vm1
	if [[ $(virsh list | grep vm1) ]]; then
		PID=`pgrep qemu-system-x86 | tail -n 1`
		echo $PID
		virsh -q save vm1 ${PROJECT_ROOT%/}/vm1_snapshot
		echo -e "\e[1;42m vm1 was running with PID $PID ..snapshot saved to $PROJECT_ROOT \e[0m"
	else
		echo -e "\e[1;31m FAILED! vm1 couldn't start up. \e[0m"
		exit 1
	fi
}

attach_disk(){
	virsh restore ${PROJECT_ROOT%/}/vm1_snapshot
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
bootstrap_it
# attach_disk
# run_workload
# process_data