#!/usr/bin/python3

srv = { #        Secret key              Server name
        1: {'k':'AAAAAAAAAAAAA', 'n':'My Proxmox cluster (192.168.0.*)'},
        2: {'k':'BBBBBBBBBBBBB', 'n':'My GitHub (username)'},
        3: {'k':'CCCCCCCCCCCCC', 'n':'Hosting, SSH'}
      }


# Micro-TOTP Generator by Amin v. 2020-08-05 (v3)
# https://aminux.wordpress.com/

import base64
import hmac
import struct
import time


# imported from https://github.com/susam/mintotp/blob/master/mintotp.py
# avoid pip imports / external dependencies
def hotp(key, counter, digits=6, digest='sha1'):
    key = base64.b32decode(key.upper() + '=' * ((8 - len(key)) % 8))
    counter = struct.pack('>Q', counter)
    mac = hmac.new(key, counter, digest).digest()
    offset = mac[-1] & 0x0f
    binary = struct.unpack('>L', mac[offset:offset+4])[0] & 0x7fffffff
    return str(binary)[-digits:].rjust(digits, '0')

def totp(key, time_step=30, digits=6, digest='sha1'):
    return hotp(key, int(time.time() / time_step), digits, digest)


print ('  ------ | -------------------------------------------------------------------');
for s in srv:
    print (' ', totp(srv[s]['k']), '|', srv[s]['n'])

