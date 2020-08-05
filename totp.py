#!/usr/bin/python3

srv = { #        Secret key              Server name
        1: {'k':'AAAAAAAAAAAAA', 'n':'My Proxmox cluster (192.168.0.*)'},
        2: {'k':'BBBBBBBBBBBBB', 'n':'My GitHub (username)'},
        3: {'k':'CCCCCCCCCCCCC', 'n':'Hosting, SSH'}
      }


# Micro-TOTP Generator by Amin v. 2020-07-15
# https://aminux.wordpress.com/

try:
   import mintotp
except:
   print ('Run `pip3 install mintotp` before')
   exit(-2)


print ('  ------ | -------------------------------------------------------------------');
for s in srv:
    k = mintotp.totp(srv[s]['k'])
    n = srv[s]['n']
    print (' ',k, '|', n)

