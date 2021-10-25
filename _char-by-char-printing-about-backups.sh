#!/bin/bash

str="I will make backups!
I will check backups!
I will make test-restoring!
I will store backups in separated places!

Respect Day of Backups!!
";

while true;
do
   for (( i=0; $i<${#str}; i=$(($i+1)) ))
   do
      echo -n "${str:$i:1}";
      sleep 0.1;
   done
   sleep 0.4;
   echo "";
done
