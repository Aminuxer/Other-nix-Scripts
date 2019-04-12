#!/bin/bash


echo "
            ***  True size checker for USB sticks   v. 0.2  ***

   This script check true volume size for detect fraud chinese usb-sticks
   !! Need ROOT rights         !! Can be dangerous      !!
   !! using WRITE commands to raw-blocks of target disk !!
";

if [[ $EUID -ne 0 ]]; then
    echo "!! You must be root;"
    exit 1
fi


echo "   Enter target DISK name (ex, sdb):";
read target_disk;
target_disk=`echo "$target_disk" | cut -b 1-3`;                # ex sdb
target_dev="/dev/$target_disk";                                # ex /dev/sdb


is_device="$(ls /dev/$target_disk 2>/dev/null)";
if [ -z "$is_device" ] || [ -z "$target_disk" ]
then
   echo "Your disk '$target_disk' not found in /dev; Bad disk name ?
   Try command : ls /dev/sd* for find your target disk;"
   exit 3
fi


target_disk_blkid=`blkid $target_dev* 2>/dev/null`;
target_disk_hdprm=`hdparm -i $target_dev 2>/dev/null | grep Model`;
if [ -n "$target_disk_blkid" ]
   then  echo "BLKiD: $target_disk_blkid";
   fi
if [ -n "$target_disk_hdprm" ]
   then  echo "HDPARM: $target_disk_hdprm";
   fi


raw_target_space_blocks=`cat /sys/block/$target_disk/size`;                                    # Device size in blocks
raw_target_block_size=`cat /sys/block/$target_disk/queue/logical_block_size`;                  # size of each block, bytes
raw_target_space=$[ $raw_target_block_size * $raw_target_space_blocks / 1048576 ];             # Target device size, Mb

echo "
 * Reported size: $raw_target_space Mb
   * Block size: $raw_target_block_size bytes
   * Blocks: $raw_target_space_blocks
";


mount_data=`mount | grep $target_disk`;
if [ -n "$mount_data" ]
   then echo "!! Can't operate over mounted partitions; Unmount and sync first, try again;"; exit 5;
fi

size=$raw_target_space;

while [ $size -gt 1 ]
do
   block=$[ ( $size * 1048576 / $raw_target_block_size ) - 1 ];
   echo -n "Check size $size Mb, block $block ...";

   # backup original sector
   dd if=$target_dev of=/var/tmp/Dev_$target_disk-block-$block-ORIGINAL-BACKUP.dd count=1 bs=$raw_target_block_size skip=$block 2>/dev/null

   # generate random data and store to RND1-file
   dd if=/dev/urandom of=/tmp/Dev_$target_disk-block-$block-RND1.dd bs=$raw_target_block_size count=1 2>/dev/null

   # override test sector by RND1-file and SYNC!! We must read not from cache !!
   dd if=/tmp/Dev_$target_disk-block-$block-RND1.dd of=$target_dev count=1 bs=$raw_target_block_size seek=$block 2>/dev/null
   sync

   # read test sector to RND2-file
   dd if=$target_dev of=/tmp/Dev_$target_disk-block-$block-RND2.dd count=1 bs=$raw_target_block_size skip=$block 2>/dev/null
   sync

   # restore test sector from backup
   dd if=/var/tmp/Dev_$target_disk-block-$block-ORIGINAL-BACKUP.dd of=$target_dev count=1 bs=$raw_target_block_size seek=$block 2>/dev/null
   sync

   # check hashes of dumps
   hash1=`sha256sum /tmp/Dev_$target_disk-block-$block-RND1.dd | cut -d ' ' -f 1`;
   hash2=`sha256sum /tmp/Dev_$target_disk-block-$block-RND2.dd | cut -d ' ' -f 1`;
   if [ $hash1 == $hash2 ]
   then
      echo " OK";
   else
      echo " !! FAIL !!
       Writed-Hash: $hash1
       Readed-Hash: $hash2";
   fi
   size=$[ $size / 2 ]
done


echo "
-----------------------------------
 First/top OK mark indicate true size;
 If you see FAIL mark, this sector crashed;
 Sector data stored in /tmp (testing read/write) and /var/tmp (original data)";
