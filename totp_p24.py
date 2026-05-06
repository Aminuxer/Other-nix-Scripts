#!/usr/bin/env python

srv = { #        Secret key              Server name
        1: {'k':'AAAAAAAAAAAAA', 'n':'My Proxmox cluster (192.168.0.*)'},
        2: {'k':'BBBBBBBBBBBBB', 'n':'My GitHub (username)'},
        3: {'k':'CCCCCCCCCCCCC', 'n':'Hosting, SSH'}
      }

# Micro-TOTP Generator adapted for Python 2.4
# Date: 2026-05-06; Aminuxer && Qwen-AI-3.6-27B

import sha
import struct
import time

# --- Helper functions for Python 2.4 compatibility ---

def b32decode(value):
    # Manual implementation of Base32 decoding. base64.b32decode was introduced in Python 2.5.
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    # Remove whitespace and padding, convert to uppercase
    value = value.upper().replace("=", "").replace(" ", "")

    bits = ""
    for char in value:
        if char in alphabet:
            idx = alphabet.index(char)
            # Manual conversion of number to 5-bit binary string (bin() function was introduced in Python 2.6)
            for i in range(4, -1, -1):
                bits += str((idx >> i) & 1)

    res = ""
    # Collect bytes by 8 bits; len(bits) - 7 ensures we have at least 8 bits for a full byte
    for i in range(0, len(bits) - 7, 8):
        byte = bits[i:i+8]
        res += chr(int(byte, 2))
    return res

def hmac_sha1(key, msg):
    # Manual implementation of HMAC-SHA1. Uses 'sha' module as 'hashlib' and 'hmac' might be missing or unstable in Python 2.4.
    block_size = 64
    # If key is longer than block size, hash it
    if len(key) > block_size:
        key = sha.new(key).digest()
    # Pad key with zeros to block size
    key = key + "\0" * (block_size - len(key))

    # Calculate o_key_pad and i_key_pad
    o_key_pad = "".join([chr(ord(k) ^ 0x5c) for k in key])
    i_key_pad = "".join([chr(ord(k) ^ 0x36) for k in key])

    # HMAC(K, m) = H((K' ^ opad) || H((K' ^ ipad) || m))
    return sha.new(o_key_pad + sha.new(i_key_pad + msg).digest()).digest()

def hotp(key_b32, counter):
    # HOTP code generation.
    key = b32decode(key_b32)

    # Pack counter into 8 bytes (big-endian). Using two 32-bit integers ('LL') as 64-bit format ('Q')
    # might be missing on some older platforms.
    high = (counter >> 32) & 0xFFFFFFFF
    low = counter & 0xFFFFFFFF
    msg = struct.pack(">LL", high, low)

    mac = hmac_sha1(key, msg)

    # Dynamic Truncation
    offset = ord(mac[-1]) & 0x0f
    binary = struct.unpack(">L", mac[offset:offset+4])[0] & 0x7fffffff

    # Return last 6 digits
    return str(binary)[-6:].zfill(6)

def totp(key_b32):
    # TOTP code generation. time.time() returns float, // 30 performs integer division
    counter = int(time.time()) // 30
    return hotp(key_b32, counter)


# --- Main execution ---
# Calculate remaining seconds
remain_seconds = 30 - (int(time.time()) % 30)

# Output (Python 2 syntax)
print "  ----- %02d ------------------------------------------------------------------" % (remain_seconds)
for s in srv:
    print "  %s | %s" % (totp(srv[s]['k']), srv[s]['n'])

