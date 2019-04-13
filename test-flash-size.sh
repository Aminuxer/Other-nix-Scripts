#!/bin/bash


echo "
            ***  True size checker for USB sticks     v. 0.4 [2019-04-12]  ***

   This script check true device size for detect fraud chinese usb-sticks
   !! Need ROOT rights      Make BACKUPS !!      Can be dangerous      !!
   !! using WRITE commands to raw-blocks of target disk !! NO WARRANTY !!
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


block=$[ $raw_target_space_blocks - 1 ];   # blocks numerated from 0
size=$raw_target_space;


while [ $size -gt 1 ]
do
   size=$[ $block * $raw_target_block_size / 1048576 ];   # recalc to Mb for nice view
   echo -n "Check size $size Mb, block $block ...";

   fbckp="/tmp/Dev_$target_disk-block-$block-ORIGINAL-BACKUP.dd";
   frnd1="/tmp/Dev_$target_disk-block-$block-RND1.dd";
   frnd2="/tmp/Dev_$target_disk-block-$block-RND2.dd";

   touch $fbckp $frnd1 $frnd2;
   chmod 600 $fbckp $frnd1 $frnd2;

   # backup original sector
   err=$(dd if=$target_dev of=$fbckp count=1 bs=$raw_target_block_size skip=$block 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't make backup of sector $block - Emergency exit !
      $err";
      exit 61;
   fi


   # generate random data and store to RND1-file
   err=$(dd if=/dev/urandom of=$frnd1 bs=$raw_target_block_size count=1 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't write init random data for sector $block - Attention !
      $err";
      exit 62;
   fi


   # check RND2-accesibility
   err=$(dd if=/dev/zero of=$frnd2 count=1 bs=$raw_target_block_size 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't make test write to data2 from sector $block - Attention !
      $err";
      exit 63;
   fi
   sync


   # override test sector by RND1-file and SYNC!! We must read not from cache !!
   err=$(dd if=$frnd1 of=$target_dev count=1 bs=$raw_target_block_size seek=$block 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't write random data1 to sector $block - CRITICAL ERROR !!
      !! Inspect logs; Use $fbckp for manual restore sector (dd seek option), if need;
      $err";
      exit 64;
   fi
   sync

   # read test sector to RND2-file
   err=$(dd if=$target_dev of=$frnd2 count=1 bs=$raw_target_block_size skip=$block 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't read data2 from sector $block - Attention !
      $err";
      exit 65;
   fi
   sync

   # restore test sector from backup
   err=$(dd if=$fbckp of=$target_dev count=1 bs=$raw_target_block_size seek=$block 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't restore sector $block from backup - CRITICAL ERROR !! BE CARE !!
      !! Inspect logs; Use $fbckp for manual restore sector (dd seek option), if need;
      $err";
      exit 66;
   fi
   sync

   # check hashes of dumps
   hash1=`sha256sum $frnd1 | cut -d ' ' -f 1`;
   hash2=`sha256sum $frnd2 | cut -d ' ' -f 1`;
   if [ $hash1 == $hash2 ]
   then
      echo " OK";
   else
      echo " !! FAIL !!
       Writed-Hash: $hash1 ( $frnd1 )
       Readed-Hash: $hash2 ( $frnd2 )";
   fi
   block=$[ $block / 2 ]
done


echo "
-----------------------------------
 First/top OK mark indicate true size;
 If you see FAIL mark, this sector crashed;
 Sector data stored in /tmp (testing read/write data, backups)
 https://github.com/Aminuxer/Other-nix-Scripts/blob/master/test-flash-size.sh";
