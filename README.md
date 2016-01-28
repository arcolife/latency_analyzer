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

##PREREQUISITES

Please install the following for your kernel version
(check through `uname -a`), before continuing..

       - kernel-debuginfo-common
       - kernel-debuginfo

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
