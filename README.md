# create-vm

Use .iso and Kickstart files to auto-generate a guest VM.

## About

I was looking for a way to automate the creation of VMs for testing various
distributed system / cluster software packages. I've used Vagrant in the past
but I wanted something that would:

* Allow me to use raw ISO files as the basis for guest VMs.
* Guest VMs should be set up with bridged IPs that are routable from the host.
* Guest VMs should be able to reach the Internet.
* Other hosts on the local network should be able to reach guest VMs. (Setting
  up additional routes is OK).
* VM creation should work with any distro that supports Kickstart files.
* Scripts should be able to create and delete VMs in a scripted, fully-automatic manner.
* Guest VMs should be set up to allow passwordless ssh access from the "ansible" user.

I've previously used virsh's `virt-install` tool to create VMs and I like how
easy it is to set up things like extra network interfaces and attach existing
disk images. The scripts in this repo fully automate the virsh VM creation process.

## Scripts

This repo contains these scripts:

`create-vm` - Use .iso and kickstart files to auto-generate a VM.

`delete-vm` - Delete a virtual machine created with `create-vm`.

`get-vm-ip` - Get the IP address of a VM managed by virsh.

`encrypt-pw` - Returns a SHA512 encrypted password suitable for pasting into Kickstart files.

I've also included a sample `ubuntu.ks` Kickstart file for creating an
Ubuntu host.

## Host setup

I'm running the scripts from a host with Ubuntu Linux 18.10 installed. I added
the following to the host's [Ansible playbook](https://docs.ansible.com/ansible/2.5/user_guide/playbooks_intro.html)
to install the necessary virtualization packages:

```
  - name: Install virtualization packages
    apt:
      name: "{{item}}"
      state: latest
    with_items:
    - qemu-kvm
    - libvirt-bin
    - libvirt-clients
    - libvirt-daemon
    - libvirt-daemon-driver-storage-zfs
    - python-libvirt
    - python3-libvirt
    - system-config-kickstart
    - vagrant-libvirt
    - vagrant-sshfs
    - virt-manager
    - virtinst
```

If you're not using Ansible just `apt-get install` the above packages.

## create-vm options

`create-vm` supports the following options:

```
   -h      Show this message
   -n      Host name (required)
   -i      Full path and name of the .iso file to use (required)
   -k      Full path and name of the Kickstart file to use (required)
   -r      RAM in MB (defaults to 1024)
   -c      Number of VCPUs (defaults to 2)
   -s      Amount of storage to allocate in GB (defaults to 20)
   -b      Bridge interface to use (defaults to virbr0)
   -m      MAC address to use (default is to use a randomly-generated MAC)
   -v      Verbose
   -d      Debug mode
```

## Sample Kickstart file

There are [plenty of documents on the Internet](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-kickstart-syntax) on how to set up Kickstart files.

A couple of things that are special about the included Kickstart file...

The Ansible user: Although I'd prefer to create the "ansible" user as a locked account,
with no password just an ssh public key, Kickstart on Ubuntu does not allow this, so
I do set up an encrypted password.

To set up your own password, use the `encrypt-pw` script to create a SHA512-hashed
password that you can copy and paste into the Kickstart file. After a VM is created
you can use this password if you need to log into the VM via the console.

To use your own ssh key, replace the ssh key in the `%post` section with your own
public key.

The `%post` section at the bottom of the Kickstart file does a couple of things:

* It updates all packages with the latest versions.
* To configure a VM with Ansible, you just need ssh access to a VM and Python installed.
  on the VM. So I use `%post` to install an ssh-server and Python.
* I start the serial console, so that `virsh console $vmname` works.
* I add a public key for Ansible, so I can configure the servers with Ansible
  without entering a password.

Despite the name, the commands in the `%post` section are not the last commands executed
by Kickstart on an Ubuntu 18.10 server. The "ansible" user is added *after* the `%post`
commands are executed. This means that the Ansible ssh public key gets added before the
ansible user is created. To make key-based logins work I set the UID:GID of
`authorized_keys` to 1000:1000. The user is later created with UID=1000, GID=1000,
which means that the `authorized_keys` file ends up being owned by the ansible user
by the time the VM creation is complete.

## Examples

### Create an Ubuntu 18.10 server

This creates a VM using Ubuntu's text-based installer. Since the `-d` parameter is used,
progress of the install is shown on screen.

```
create-vm -n node1 -i ~/isos/ubuntu-18.10-server-amd64.iso -k ~/conf/ubuntu.ks -d
```

### Create 8 Ubuntu 18.10 servers

This starts the VM creation process and exits. Creation of the VMs continues in the background.

```
for n in `seq 1 8`; do
    create-vm -n node$n -i ~/isos/ubuntu-18.10-server-amd64.iso -k ~/conf/ubuntu.ks
done
```

### Delete 8 virtual machines

```
for n in `seq 1 8`; do
    delete-vm node$n
done
```

### Connect to a VM via the console

```
virsh console node1
```

### Connect to a VM via ssh

```
ssh ansible@`get-vm-ip node1`
```

### Generate an Ansible hosts file

```
(
    echo '[hosts]'
    for n in `seq 1 8`; do
        ip=`get-vm-ip node$n`
        echo "node$n ansible_host=$ip ip=$ip ansible_user=ansible"
    done
) > hosts.ini
```

### Handy virsh commands

`virsh list` - List all running VMs.

`virsh domifaddr node1` - Get a node's IP address. Does not work with all network setups,
which is why I wrote the `get-vm-ip` script. 

`virsh net-list` - Show what networks were created by virsh. 

`virsh net-dhcp-leases $network` - Shows current DHCP leases when virsh is acting as the
DHCP server. Leases may be shown for machines that no longer exist.

## Known Issues

* VMs created without the `-d` (debug mode) parameter may be created in "stopped" mode. To
  start them up, run the command `virsh start $vmname`.
* Depending on how your host is set up, you may need to run these scripts as `root`.
* Ubuntu text mode install messes up terminal screens. Run `reset` from the command line
  to restore a terminal's functionality.
* I use Ansible to set a guest's hostname, not Kickstart, so all Ubuntu guests created have the
  host name "ubuntu".
