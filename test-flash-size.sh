#!/bin/bash


echo "     ***  True size checker for USB sticks     v. 0.8 [2021-11-05]  ***

   This script check true device size for detect fraud chinese usb-sticks
   !! Need ROOT rights      Make BACKUPS !!      Can be dangerous      !!
   !! using WRITE commands to raw-blocks of target disk !! NO WARRANTY !!
";


hashfunk=`which md5sum sha1sum sha224sum sha256sum sha384sum sha512sum crc32 2>/dev/null | sort -r | head -n 1`
hashfunkname=`basename $hashfunk`
if [ -z $hashfunk ]
   then echo "Can't find hashsum tools like sha256sum / sha1sum / md5sum / crc32; Install it and try again;"
   exit 2;
fi


if [[ $EUID -ne 0 ]]; then
    echo "!! You must be root;"
    exit 13
fi


echo "   Enter target DISK name (ex, sdb, nvme0n1, loop1):";
read target_disk;
target_dev="/dev/$target_disk";                   # ex /dev/sdb


is_device="$(ls /dev/$target_disk 2>/dev/null)";
if [ -z "$is_device" ] || [ -z "$target_disk" ]
then
   echo "Your disk '$target_disk' not found in /dev; Bad disk name ?
   Try command : ls /dev/sd* for find your target disk;"
   exit 19;
fi


target_disk_blkid=`blkid $target_dev* 2>/dev/null`;
if [ -n "$target_disk_blkid" ]
   then  echo "BLKiD: $target_disk_blkid";
   fi

target_disk_hdprm=`hdparm -i $target_dev 2>/dev/null | grep Model`;
if [ -n "$target_disk_hdprm" ]
   then  echo "HDPARM: $target_disk_hdprm";
   fi


raw_target_space_blocks=`cat /sys/block/$target_disk/size 2>/dev/null`;                        # Device size in blocks
raw_target_block_size=`cat /sys/block/$target_disk/queue/logical_block_size 2>/dev/null`;      # size of each block, bytes

if [ -z $raw_target_space_blocks ]
   then echo "Can't determine size of device or block; Not-block device ?"
   exit 15;
fi

raw_target_space=$[ $raw_target_block_size * $raw_target_space_blocks / 1048576 ];             # Target device size, Mb

echo "
 * Reported size: $raw_target_space Mb
   * Block size: $raw_target_block_size bytes
   * Blocks: $raw_target_space_blocks
";


mount_data=`mount | grep "/dev/$target_disk"`;
if [ -n "$mount_data" ]
   then echo "!! Can't operate over mounted partitions; Unmount and sync first, try again;";
   exit 16;
fi

raid_data=`cat /proc/mdstat | grep $target_disk`;
if [ -n "$raid_data" ]
   then echo "!! Can't operate over RAID-members; Unmount, stop array and sync first, try again;";
   exit 18;
 
elif [ `lsblk /dev/$target_disk -n -o MOUNTPOINT 2> /dev/null | grep -v '^$' | wc -l` -gt 0 ]
      then echo "$target_disk has active MOUNTPOINT.";
      exit 20;

elif [ `blkid -s TYPE | grep ' TYPE="zfs_member"' | cut -d ':' -f 1 | cut -d ':' -f 1 | grep "$target_disk" | wc -l` -gt 0 ]
      then echo "$target_disk has active ZFS.";
      exit 22;
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
      exit 5;
   fi


   # generate random data and store to RND1-file
   err=$(dd if=/dev/urandom of=$frnd1 bs=$raw_target_block_size count=1 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't write init random data for sector $block - Attention !
      $err";
      exit 202;
   fi


   # check RND2-accesibility
   err=$(dd if=/dev/zero of=$frnd2 count=1 bs=$raw_target_block_size 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't make test write to data2 from sector $block - Attention !
      $err";
      exit 203;
   fi
   sync


   # override test sector by RND1-file and SYNC!! We must read not from cache !!
   err=$(dd if=$frnd1 of=$target_dev count=1 bs=$raw_target_block_size seek=$block 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't write random data1 to sector $block - CRITICAL ERROR !!
      !! Inspect logs; Use $fbckp for manual restore sector (dd seek option), if need;
      $err";
      exit 204;
   fi
   sync

   # read test sector to RND2-file
   err=$(dd if=$target_dev of=$frnd2 count=1 bs=$raw_target_block_size skip=$block 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't read data2 from sector $block - Attention !
      $err";
      exit 205;
   fi
   sync

   # restore test sector from backup
   err=$(dd if=$fbckp of=$target_dev count=1 bs=$raw_target_block_size seek=$block 2>&1)
   if [ $? -ne 0 ]
   then
      echo " /_!_\ Can't restore sector $block from backup - CRITICAL ERROR !! BE CARE !!
      !! Inspect logs; Use $fbckp for manual restore sector (dd seek option), if need;
      $err";
      exit 206;
   fi
   sync

   # check hashes of dumps
   hash1=`$hashfunk $frnd1 | cut -d ' ' -f 1`;
   hash2=`$hashfunk $frnd2 | cut -d ' ' -f 1`;
   if [ $hash1 == $hash2 ]
   then
      rm -f $frnd1 $frnd2 $fbckp
      echo " OK";
   else
      echo " !! FAIL !!     $hashfunkname
       Writed-Hash: $hash1 ( $frnd1 )
       Readed-Hash: $hash2 ( $frnd2 )";
   fi
   block=$[ $block / 2 ]
done


echo "
-----------------------------------
 First/top OK mark can indicate true size;
 If you see FAIL mark, this sector crashed;
 Sector data stored in /tmp (testing read/write data, backups)
 https://github.com/Aminuxer/Other-nix-Scripts/blob/master/test-flash-size.sh";


exit 0;

