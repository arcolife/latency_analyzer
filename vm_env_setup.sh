#!/bin/bash

PROJECT_ROOT='/home/arcolife/workspace/utils/RH/kvm_io/devconf/'
# PROJECT_ROOT='/src'
TEST_IMG_PATH='/var/lib/libvirt/images/vm1.qcow2'

echo `ps -aef | grep qemu-system-x86`

# define client name here, ex: virbr0-xxx-xx
CLIENTS=''

user_interrupt(){
    echo -e "\n\nKeyboard Interrupt detected."
    echo -e "Stopping KVM env bootstrap script..."
    exit
}

trap user_interrupt SIGINT
trap user_interrupt SIGTSTP

cleanup(){
	echo "cleaning up.."
	rm -f ${PROJECT_ROOT%/}/vm1_snapshot
}

install_requirements(){
	# create project location
	mkdir $PROJECT_ROOT
	echo "$PROJECT_ROOT was created.."
	
	# install virsh components
	dnf install -y @virtualization
	systemctl start libvirtd
	systemctl enable libvirtd
	virsh --version
	if [ $? -eq 0]; then
		echo "virtualization components have been installed.."
	else
		echo "FAILED! virtualization modules could not be installed.."
		exit 1
	fi

	# install pbench and fio
	dnf install -y dnf-plugins-core
	dnf copr enable -y ndokos/configtools
	dnf copr enable -y ndokos/pbench
	dnf install -y pbench-agent
	dnf install -y pbench-fio
	sed -i 's/ver=2.2.5/ver=2.2.8/g' /opt/pbench-agent/bench-scripts/pbench_fio
	source /etc/profile.d/pbench-agent.sh
	register-tool-set
	which pbench_fio
	if [ $? -eq 0]; then
		echo "Pbench has been installed.."
	else
		echo "FAILED! Pbench could not be installed.."
		exit 1
	fi

	# install perf-script-postprocessor
	dnf install -y python2-pip
	pip2 install -y perf-script-postprocessor
	if [ $? -eq 0]; then
		echo $(perf_script_postprocessor -h)
		echo "perf-script-postprocessor has been installed.."
	else
		echo "FAILED! perf-script-postprocessor could not be installed.."
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

}

bootstrap_it(){
	qemu-img create -f qcow2 $TEST_IMG_PATH 1G	
	virsh define $XML_PATH
	virsh start vm1
	if[[ -z $(virsh list | grep vm1) ]]; then
		virsh save vm1 ${PROJECT_ROOT%/}/vm1_snapshot
		# virsh restore ${PROJECT_ROOT%/}/vm1_snapshot
		echo "vm1 is now running."
	else
		echo "FAILED! vm1 couldn't start up."
		exit 1
	fi
	XML_PATH=${PROJECT_ROOT%/}'/vm1.xml'
	PID=`pgrep qemu-system-x86 | tail -n 1`
}

attach_disk(){
	# use kvm_io
}

run_workload(){
	# run kvm_io/bench_iter.sh

}

process_data(){
	# see if we can graph the results nicely
}

install_requirements
# bootstrap_it
# attach_disk
# run_workload
# process_data