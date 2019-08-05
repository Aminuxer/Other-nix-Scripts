# Other-nix-Scripts

## proxmox_backup_sorter.sh
You have copy of proxmox dumps:
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
