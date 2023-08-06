# create-vm

Quickly create guest VMs using cloud image files and cloud-init.

## About

After the latest updates to the code these scripts now create VMs from full
Linux distros _in a few seconds._

I was looking for a way to automate the creation of VMs for testing various
distributed system / cluster software packages. I've used Vagrant in the past
but I wanted something that would:

* Allow me to use raw image files as the basis for guest VMs.
* Guest VMs should be set up with bridged IPs that are routable from the host.
* Guest VMs should be able to reach the Internet.
* Other hosts on the local network should be able to reach guest VMs. (Setting
  up additional routes is OK).
* VM creation should work with any distro that supports Kickstart files.
* Scripts should be able to create and delete VMs in a scripted, fully-automatic manner.
* Guest VMs should be set up to allow passwordless ssh access from the "ansible" user, so
  that once a VM is running Ansible can be used for additional configuration and
  customization of the VM.

I've previously used virsh's `virt-install` tool to create VMs and I like how
easy it is to set up things like extra network interfaces and attach existing
disk images. The scripts in this repo fully automate the virsh VM creation process.

## cloud-init

The current version of this script uses cloud images, [cloud-init](https://cloud-init.io/),
and virsh tooling to quickly create VMs from the command line. Using a single Linux
_host system_ you can create multiple _guest VMs_ running on that host. Each _guest VM_ has
its own file system, memory, virtualized CPUs, IP address, etc.

## Using Kickstart instead of cloud-init

The original version of these tools used ISO images and Kickstart files to create
new VMs from the command line. If you're looking for an example of how to use Kickstart
files grab [create-vm version 1.0](https://github.com/earlruby/create-vm/tree/1.0).

## Cloud Images

`create-vm` creates a QCOW2 file for your VM's file system. The QCOW2 image uses the cloud image
_as a base filesystem_, so instead of copying all of the files that come with a Linux distribution
and installing them, QCOW will just use files directly from the base image _as long as those
files remain unchanged._ QCOW stands for "QEMU Copy On Write", so once you make a change to a file
the changes are written to your VM's QCOW2 file.

Cloud images have the extension `.img` or `.qcow` and are compiled for different system architectures.

Cloud images are available for the following distros:

* [Ubuntu](http://cloud-images.ubuntu.com/)
* [Centos](https://cloud.centos.org/centos/7/images/)
* [openSUSE](https://download.opensuse.org/repositories/Cloud:/Images:/)
* [Rocky](https://rockylinux.org/cloud-images/)
* [Arch](https://geo.mirror.pkgbuild.com/images/latest/)
* [Gentoo](https://mirror.init7.net/gentoo//experimental/amd64/openstack/)
* [AlmaLinux](https://github.com/AlmaLinux/cloud-images)

Pick the base image for the distro and release that you want to install and download it onto your
host system. Make sure that the base image uses the same hardware architecture as your host system,
e.g. "x86_64" or "amd64" for Intel and AMD -based host systems, "arm64" for 64 bit ARM-based host
systems.

## cloud-init configuration

cloud-init reads in two configuration files, `user-data` and `meta-data`, to initialize a
VM's settings. One of the places it looks for these files is any attached disk volume
labeled `cidata`.

The `create-vm` script creates an ISO disk called `cidata` with these two files and passes that
in as a volume to virsh when it creates the VM. This is referred to as the "no cloud" method,
so if you see a cloud image for "nocloud" that's the one you want to use.

If you're interested in other ways of doing this check out the
[Datasources](https://cloudinit.readthedocs.io/en/latest/reference/datasources.html)
documentation on for cloud-init.

## Files

`create-vm` stores files as follows:

* `${VM_IMAGE_DIR}` - Directory used for for VM storage. Defaults to `${HOME}/vms/virsh`.
* `${VM_IMAGE_DIR}/base/` - Place to store your base Linux cloud images.
* `${VM_IMAGE_DIR}/images/` - `your-vm-name.img` and `your-vm-name-cidata.img` files.
* `${VM_IMAGE_DIR}/init/` - `user-data` and `meta-data`.
* `${VM_IMAGE_DIR}/xml/` - Backup copies of your VMs' XML definition files.

QCOW2 filesystems allocate space as needed, so if you create a VM with 100GB of storage, the initial
size of the `your-vm-name.img` and `your-vm-name-cidata.img` files is only about **700K total**. The
`your-vm-name.img` file will grow as you install packages and update files, but will never grow
beyond the disk size that you set when you create the VM.

## Scripts

This repo contains these scripts:

* `create-vm` - Use .img and cloud-init files to auto-generate a VM.
* `delete-vm` - Delete a virtual machine created with `create-vm`.
* `get-vm-ip` - Get the IP address of a VM managed by virsh.

## Host setup

I'm running the scripts from a host with Ubuntu Linux 22.04 installed. I added
the following to the host's [Ansible playbook](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html)
to install the necessary virtualization packages:

```
  - name: Install virtualization packages
    apt:
      name: "{{item}}"
      state: latest
    with_items:
    - libvirt-bin
    - libvirt-clients
    - libvirt-daemon
    - libvirt-daemon-system
    - libvirt-daemon-driver-storage-zfs
    - python-libvirt
    - python3-libvirt
    - virt-manager
    - virtinst
```

If you're not using Ansible just `apt-get install` the above packages.

## Permissions

The `libvirtd` daemon runs under the `libvirt-qemu` user service account. The `libvirt-qemu` user
must be able to read the files in `${VM_IMAGE_DIR}`. If your ${HOME} directory has permissions set to
`0x750` then `libvirt-qemu` won't be able to read the `${VM_IMAGE_DIR}` directory.

You could open up your home directory, e.g.:

```
chmod 755 ${HOME}
```

... but that allows anyone logged into your Linux host to read everything in your home directory. A
better approach is just to add `libvirt-qemu` to your home directory's group. For instance, on my host
my home directory is `/home/earl` owned by user `earl` and group `earl`, permissions `0x750`:

```
$ chmod 750 /home/earl
$ ls -al /home
total 24
drwxr-xr-x   6 root      root      4096 Aug 28 21:26 .
drwxr-xr-x  21 root      root      4096 Aug 28 21:01 ..
drwxr-x--- 142 earl      earl      4096 Feb 16 09:27 earl
```

To make sure that _only_ the `libvirt-qemu` user can read my files I can add the user to the `earl` group:

```
$ sudo usermod --append --groups earl libvirt-qemu
$ sudo systemctl restart libvirtd
$ grep libvirt-qemu /etc/group
earl:x:1000:libvirt-qemu
libvirt-qemu:x:64055:libvirt-qemu
```

That shows that the group `earl`, group ID 1000, has a member `libvirt-qemu`. Since the group `earl` has read and execute permissions on my home directory, `libvirt-qemu` has read and execute permissions on my home directory.

Note: The `libvirtd` daemon will chown some of the files in the directory, including the files in the `~/vms/virsh/images` directory, to be owned by `libvirt-qemu` group `kvm`. In order to delete these files without sudo, add yourself to the `kvm` group, e.g.:

```
$ sudo usermod --append --groups kvm earl
```

You'll need to log out and log in again before the additional group is active.

## create-vm options

`create-vm` supports the following options:

```
OPTIONS:
   -h      Show this message
   -n      Host name (required)
   -i      Full path and name of the base .img file to use (required)
   -k      Full path and name of the ansible user's public key file (required)
   -r      RAM in MB (defaults to 2048)
   -c      Number of VCPUs (defaults to 2)
   -s      Amount of storage to allocate in GB (defaults to 80)
   -b      Bridge interface to use (defaults to virbr0)
   -m      MAC address to use (default is to use a randomly-generated MAC)
   -v      Verbose
```

## Examples

### Create an Ubuntu 22.04 server VM

This creates an Ubuntu 22.04 "Jammy Jellyfish" VM with a 40G hard drive.

First download a copy of the Ubuntu 22.04 "Jammy Jellyfish" cloud image:

```
mkdir -p ~/vms/virsh/base
cd ~/vms/virsh/base
wget http://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

Then create the VM:
```
create-vm -n node1 \
    -i ~/vms/virsh/base/jammy-server-cloudimg-amd64.img \
    -k ~/.ssh/id_rsa_ansible.pub \
    -s 40
```

Once created I can get the IP address and ssh to the VM as the user "ansible":
```
$ get-vm-ip node1
192.168.122.219
$ ssh -i ~/.ssh/id_rsa_ansible ansible@192.168.122.219
The authenticity of host '192.168.122.219 (192.168.122.219)' can't be established.
ED25519 key fingerprint is SHA256:L88LPO9iDCGbowuPucV5Lt7Yf+9kKelMzhfWaNlRDxk.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.122.219' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.1 LTS (GNU/Linux 5.15.0-60-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Wed Feb 15 20:05:45 UTC 2023

  System load:  0.47216796875     Processes:             105
  Usage of /:   3.7% of 38.58GB   Users logged in:       0
  Memory usage: 9%                IPv4 address for ens3: 192.168.122.219
  Swap usage:   0%

Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ansible@node1:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           198M 1008K  197M   1% /run
/dev/sda1        39G  1.5G   38G   4% /
tmpfs           988M     0  988M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/sda15      105M  6.1M   99M   6% /boot/efi
tmpfs           198M  4.0K  198M   1% /run/user/1000
ansible@node1:~$
```

Note that this VM was created with a 40GB hard disk, and the total disk space shown is 40GB,
but the actual hard drive space _initially used_ by this VM was about 700K. The VM can consume
up to 40GB, but will only use the space it actually needs.

### Create 8 Ubuntu 22.04 servers

This starts the VM creation process and exits. Creation of the VMs continues in the background.

```
for n in `seq 1 8`; do
    create-vm -n node$n -i ~/vms/virsh/base/jammy-server-cloudimg-amd64.img -k ~/.ssh/id_rsa_ansible.pub
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
ssh ansible@$(get-vm-ip node1)
```

### Generate an Ansible hosts file

```
(
    echo '[hosts]'
    for n in `seq 1 8`; do
        ip=$(get-vm-ip node$n)
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
