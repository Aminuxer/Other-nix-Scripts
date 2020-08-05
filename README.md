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


## 1cfresh-backup.py

Edit parameters username, password and oneassfresh_accound_id - use data from 1C-Fresh cloud service.
User must have "administrator" role and "run and manage" permission for each backuped database.
This script connect to cloud 1C, found and download latest database backup to current directory.

Better run this from non-root account like this:

```
su - 1cfresh -c "find /home/1cfresh/ -type f -mtime +7 -name '*.zip' -delete"
su - 1cfresh -c "/home/1cfresh/1cfresh-backup.py 2>&1" > 1cfresh-backup.log
tar --gzip -cf home_1cfresh.tgz /home/1cfresh
```
Paper (russian): https://aminux.wordpress.com/2020/02/28/1cfresh-cloud-backups/

In case of username/password error your catch exception 'HTTP Error 401: Unauthorized';

Also your can see message "<urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: Hostname mismatch, certificate is not valid for 'my_domain_name.local.corp'. (_ssl.c:1076)>"

You can try fix this with urllib ssl-hacks, but better way - make normal certificates by Let's Encrypt or self-hosted inner-corporate local CA.


## totp.py

Generate Timebased one-time passwords in very tiny python script; Can be used as cold backup of data parallel with Google Authenticator or similar TOTP generator.
Configured version must be stored securely;
Edit script, and fill values in array [srv] by your secrets and descriptions;
Run it at last moment before input 2nd factor, you must view totp codes in output:

...
$ ./totp.py
  ------ | -------------------------------------------------------------------
  349462 | My Proxmox cluster (192.168.0.*)
  560741 | My GitHub (username)
  846956 | Hosting, SSH
...

TOTP codes valid only 30 seconds; If you code expired, try generate and input this again.
Simple and reliable backup of data from TOTP generator;
Use cryptocontainers:
    https://github.com/Aminuxer/DM-Crypt-Helper-Scripts
for store configured script !!

First version (v1) rely on mintotp and need pip3 install mintotp; last version (v2) don't have external dependencies;

