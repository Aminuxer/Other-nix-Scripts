# Other-nix-Scripts

## proxmox_backup_sorter.sh
You have copy of many files with proxmox dumps:
```
# ls /mnt/proxmox/dump
vzdump-lxc-100-2019_08_03-03_17_02.log
vzdump-lxc-100-2019_08_03-03_17_02.tar.gz
vzdump-lxc-101-2019_08_03-03_35_23.log
vzdump-lxc-101-2019_08_03-03_35_23.tar.gz
vzdump-qemu-406-2019_08_03-03_38_31.log
vzdump-qemu-406-2019_08_03-03_38_31.tar.gz
```
Sort this:
`./proxmox_backup_sorter.sh /mnt/proxmox/dump`

All files will places to subdirectories like this:

```
# tree /mnt/proxmox/dump
/mnt/proxmox/dump
├── CT
│    ├── Jabber.Ru
│    │      ├── vzdump-lxc-100-2019_08_03-03_17_02.log
│    │      └── vzdump-lxc-100-2019_08_03-03_17_02.tar.gz
│    └── MyDevJira
│           ├── vzdump-lxc-101-2019_08_03-03_35_23.log
│           └── vzdump-lxc-101-2019_08_03-03_35_23.tar.gz
└── VM
     └── OpenBSD-test
            ├── vzdump-qemu-406-2019_08_03-03_38_31.log
            └── vzdump-qemu-406-2019_08_03-03_38_31.tar.gz
```
This can be useful for archive store.
https://aminux.wordpress.com/2017/08/30/proxmox-sort-vzdump-backups/
PS. Don't make this on work directories of proxmox - this backups will disappear from web-interface. This only for tape / detached backups.


## test-flash-size.sh
Script for very fast detect of fraud chinese usb-sticks. Some very cheap or souvenir USB-flash sticks often have fraud - real size sufficiently less that announced bu controller. This script make some test read/writes to sectors of target flash, jump over degrees of two. Big disks can be fast tested for fraud size in seconds.

`# ./test-flash-size.sh`

WARNING: This script make writes to media !! Sectors recovered after tests, but unstable / buggy flash can crashed; Make backups !
Example of test result:
```
*** True size checker for USB sticks v. 0.4 [2019-04-12] ***

This script check true device size for detect fraud chinese usb-sticks
!! Need ROOT rights Make BACKUPS !! Can be dangerous !!
!! using WRITE commands to raw-blocks of target disk !! NO WARRANTY !!

Enter target DISK name (ex, sdb):
sdb
BLKiD: /dev/sdb: PTUUID="0203fd1e" PTTYPE="dos"
/dev/sdb1: UUID="e223fef4-736c-4af0-80e2-92254ac09cdf" TYPE="ext4" PARTUUID="0203fd1e-01"

* Reported size: 64 Mb
* Block size: 512 bytes
* Blocks: 131832

Check size 64 Mb, block 131831 ... OK
Check size 32 Mb, block 65915 ... OK
Check size 16 Mb, block 32957 ... OK
Check size 8 Mb, block 16478 ... OK
Check size 4 Mb, block 8239 ... OK
Check size 2 Mb, block 4119 ... OK
Check size 1 Mb, block 2059 ... OK

-----------------------------------
First/top OK mark indicate true size;
If you see FAIL mark, this sector crashed;
Sector data stored in /tmp (testing read/write) and /var/tmp (original data)
```
https://aminux.wordpress.com/2019/04/13/very-fast-usb-flash-size-detect/
