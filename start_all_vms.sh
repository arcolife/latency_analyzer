#!/bin/bash

for vm in `virsh list --all  | awk  '{print $2} ' | sed '/^$/d' | sed '/Name/d'`; do
	virsh start $vm
done

virsh list --all

