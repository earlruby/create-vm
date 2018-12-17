# System language
lang en_US
# Language modules to install
langsupport en_US
# System keyboard
keyboard us
# System mouse
mouse
# System timezone
timezone --utc Etc/UTC
# Root password
rootpw --disabled
# Initial user
user ansible --fullname "ansible" --iscrypted --password $6$CfjrLvwGbzSPGq49$t./6zxk9D16P6J/nq2eBVWQ74aGgzKDrQ9LdbTfVA0IrHTQ7rQ8iq61JTE66cUjdIPWY3fN7lGyR4LzrGwnNP.
# Reboot after installation
reboot
# Use text mode install
text
# Install OS instead of upgrade
install
# Use CDROM installation media
cdrom
# System bootloader configuration
bootloader --location=mbr 
# Clear the Master Boot Record
zerombr yes
# Partition clearing information
clearpart --all 
# Disk partitioning information
part / --fstype ext4 --size 3700 --grow
part swap --size 200 
# System authorization infomation
auth  --useshadow  --enablemd5 
# Firewall configuration
firewall --enabled --ssh 
# Do not configure the X Window System
skipx
%post --interpreter=/bin/bash
echo ### Redirect output to console
exec < /dev/tty6 > /dev/tty6
chvt 6
echo ### Update all packages
apt-get update
apt-get -y upgrade
# Install packages
apt-get install -y openssh-server vim python
echo ### Enable serial console so virsh can connect to the console
systemctl enable serial-getty@ttyS0.service
systemctl start serial-getty@ttyS0.service
echo ### Add public ssh key for Ansible
mkdir -m0700 -p /home/ansible/.ssh
cat <<EOF >/home/ansible/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC14kgOfzuOA4+hD16JFTAtXWc0UkzvXw3TrPxivh+/t86FH1N1qlXLLZn60voysLHnyiwTXrC8Zy0H8rckRopepozMBRegeklnkLHaiFDBdbAkHm8DMOd5QuGedBZ+s80+05btzOVxZcN5M6m4A03vLGGoOqnJvewv1u/yP6et0hP2Bs6D9ycczOpXeOgKnUXt1rciVYTk9xwOXFWcZ5phnXSCGA1w0BACK2CZaCKmsAT5YR7PA4N+7xVMvhOgo3gt8dNxNtmEtkZSlYYqkJehuldt1IPpfQ5/QYngYKX1ZCKS2LHc9Ys3F8QX3djhOhqFL+kcDMrdTaT5GlAFcgqebIao5mTYpiqc72YbvbCMWRVomhE0TWgliIftR/65NzOf8N4b2fE/hakLkIsGyR7TQiNmAHgagqBX/qdBJ7QJdNN7GH2aGP/Ni7b9xX2jsWXRj8QcSee+IDgfm2k/uKGvI6+RotRVx/EjwOGVUeGp8txP8l4T0AmYsgiL1Phe5swAPaMj4R+m38dwzr2WF/PViI1upF/Weczoiu0dDODLsijdHBAIju9BEDBzcFbDPoLLKHOSMusy86CVGNSEaDZUYwZ2GHY6anfEaRzTJtqRKNvsGiSRJAeKIQrZ16e9QPihcQQQNM+Z9QW7Ppaum8f2QlFMit03UYMplw0EpNPAWQ== ansible@host
EOF
echo ### Set permissions for Ansible directory and key. Since the "Initial user"
echo ### is added *after* %post commands are executed, I use the UID:GID
echo ### as a hack since I know that the first user added will be 1000:1000.
chown -R 1000:1000 /home/ansible
chmod 0600 /home/ansible/.ssh/authorized_keys
# Allow Ansible to sudo w/o a password
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
echo ### Change back to terminal 1
chvt 1
