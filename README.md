# latency_analyzer

Example code to start analyzing latency of I/O events.
In this use case, block I/O events for Qemu-KVM.

##USAGE

To start all the processes at once, run `vm_env_setup.sh` without any parameters.

To setup the requirements and basic vm environment, run:

``` ./vm_env_setup.sh -o 1 ```

To run the benchmark with default options:

``` ./vm_env_setup.sh -o 2 ```

Refer to following command on further usage:

``` ./vm_env_setup.sh -h ```

Note: If you want you could supply your own kickstart file to the script,
and change sha512 based login password using following option:

``` python -c "import crypt, getpass, pwd; \
print crypt.crypt('#devconf16', '\$6\devconf16\$')" ```

##DEVCONF_2016_SPECIFIC_NOTE

Please note that `vm_env_setup.sh` runs perfectly on fedora 23.
If you have other distros/versions, kindly `at least` do the following,
to speed up the workshop:

1. install the pip2 module perf-script-postprocessor.
   You might get dependency erros on rpm based systems.
   So install the equivalent of following packages.

   ```
   gcc lapack lapack-devel blas blas-devel gcc-gfortran gcc-c++ liblas
   libffi-devel libxml-devel libxml2-devel libxslt-devel redhat-rpm-config
   ```
   
2. install @Virtualization packages for your distro, as well as qemu-kvm
   ..so we could use virsh / virt-install / qemu-kvm as accelerator..

3. run the following part from vm_env_setup.sh, as following..

   ```# ./handy_minimalistic.sh```

Cheers.

##PREREQUISITES

Please install the following for your kernel version
(check through `uname -a`), before continuing..

       - kernel-debuginfo-common | f23 | [4.3.3-303](ftp://195.220.108.108/linux/fedora/linux/updates/23/x86_64/debug/k/kernel-debuginfo-common-x86_64-4.3.3-303.fc23.x86_64.rpm)

       - kernel-debuginfo | f23 [4.3.3-303](ftp://195.220.108.108/linux/fedora/linux/updates/23/x86_64/debug/k/kernel-debuginfo-4.3.3-303.fc23.x86_64.rpm)

After starting up the vm (refer to USAGE section),
add your host's id_rsa.pub to guest's authorized keys.
Since guest won't have a .ssh folder, create it as follows:

1. login to guest with user:`root` pass:`#devconf16` through:

  - either ssh using IP gained from:

  ``` arp -e  | grep $(virsh domiflist vm1 | tail -n 2  | head -n 1 | awk -F' ' '{print $NF}') ```

  - or through `virsh console vm1`

2. `mkdir /root/.ssh`

3. `chmod 700 /root/.ssh`

4. `ssh-keygen -t dsa` Note: Just press [Enter] in all inputs required, including
   empty enter for passphrase, since this is for testing..

5. Add your hosts id_rsa.pub to `/root/.ssh/authorized_keys`

6. `chmod 600 /root/.ssh/id_dsa /root/.ssh/id_dsa.pub /root/.ssh/authorized_keys`
