#!/usr/local/bin/python

# Micro-TOTP Generator for Python 1.0.1 (1994!)
# Date: 2026-05-25; Aminuxer && Qwen-AI-3.6-27B && Google AI Assistant (ChatGPT)

# cat totp_p10 | docker run -i dahlia/python-1.5.2-docker


# --- Servers ---
srv = [
    (1, 'AAAAAAAAAAAAA', 'My Proxmox cluster (192.168.0.*)'),
    (2, 'BBBBBBBBBBBBB', 'My GitHub (username)'),
    (3, 'CCCCCCCCCCCCC', 'Hosting, SSH'),
]


import time
import string


# --- Manual replace ---
def replace(s, old, new):
    result = ''
    i = 0
    while i < len(s):
        if s[i:i+len(old)] == old:
            result = result + new
            i = i + len(old)
        else:
            result = result + s[i]
            i = i + 1
    return result

# --- Base32 Decode ---
def b32decode(value):
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    value = replace(string.upper(value), '=', '')

    pad_len = (8 - len(value) % 8) % 8
    value = value + '=' * pad_len

    bit_chars = ['0', '1']
    bits = ''
    for char in value:
        if char == '=': break
        idx = string.find(alphabet, char)
        if idx >= 0:
            bits = bits + bit_chars[(idx >> 4) & 1]
            bits = bits + bit_chars[(idx >> 3) & 1]
            bits = bits + bit_chars[(idx >> 2) & 1]
            bits = bits + bit_chars[(idx >> 1) & 1]
            bits = bits + bit_chars[(idx >> 0) & 1]

    res = ''
    i = 0
    while i + 8 <= len(bits):
        byte = bits[i:i+8]
        val = 0
        j = 0
        while j < 8:
            if byte[j] == '1':
                val = val * 2 + 1
            else:
                val = val * 2
            j = j + 1
        res = res + chr(val)
        i = i + 8
    return res

# --- Manual Binary Packing/Unpacking ---
def pack_u64_be(n):
    n = long(n)
    return (
        chr((n >> 56) & 0xFF) +
        chr((n >> 48) & 0xFF) +
        chr((n >> 40) & 0xFF) +
        chr((n >> 32) & 0xFF) +
        chr((n >> 24) & 0xFF) +
        chr((n >> 16) & 0xFF) +
        chr((n >> 8) & 0xFF) +
        chr(n & 0xFF)
    )

# ИСПРАВЛЕНО: Теперь строго берутся индексы элементов строки s[0], s[1]...
def unpack_u32_be(s):
    b0 = long(ord(s[0])) << 24
    b1 = long(ord(s[1])) << 16
    b2 = long(ord(s[2])) << 8
    b3 = long(ord(s[3]))
    return (b0 | b1 | b2 | b3) & 0xFFFFFFFFL

# --- SHA-1 Implementation ---
def _left_rotate(n, bits):
    n = long(n) & 0xFFFFFFFFL
    return ((n << bits) | (n >> (32 - bits))) & 0xFFFFFFFFL

def _sha1_process_block(block, h0, h1, h2, h3, h4):
    a = long(h0)
    b = long(h1)
    c = long(h2)
    d = long(h3)
    e = long(h4)

    w = []
    i = 0
    while i < 64:
        val = (ord(block[i]) << 24) | (ord(block[i+1]) << 16) | (ord(block[i+2]) << 8) | ord(block[i+3])
        w.append(long(val & 0xFFFFFFFFL))
        i = i + 4

    for i in range(16, 80):
        val = _left_rotate(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1)
        w.append(val)

    K = [long(0x5A827999), long(0x6ED9EBA1), long(0x8F1BBCDC), long(0xCA62C1D6)]

    for i in range(80):
        if i < 20:
            not_b = long(b) ^ 0xFFFFFFFFL
            f = (long(b) & long(c)) | (not_b & long(d))
            k = K[0] # ИСПРАВЛЕНО: Вернули индекс константы
        elif i < 40:
            f = long(b) ^ long(c) ^ long(d)
            k = K[1] # ИСПРАВЛЕНО: Вернули индекс константы
        elif i < 60:
            f = (long(b) & long(c)) | (long(b) & long(d)) | (long(c) & long(d))
            k = K[2] # ИСПРАВЛЕНО: Вернули индекс константы
        else:
            f = long(b) ^ long(c) ^ long(d)
            k = K[3] # ИСПРАВЛЕНО: Вернули индекс константы

        temp = (_left_rotate(a, 5) + f + e + k + w[i]) & 0xFFFFFFFFL

        e = d
        d = c
        c = _left_rotate(b, 30)
        b = a
        a = temp

    return (
        (long(h0) + a) & 0xFFFFFFFFL,
        (long(h1) + b) & 0xFFFFFFFFL,
        (long(h2) + c) & 0xFFFFFFFFL,
        (long(h3) + d) & 0xFFFFFFFFL,
        (long(h4) + e) & 0xFFFFFFFFL,
    )

def sha1(data):
    msg_len = len(data)
    bit_len = long(msg_len * 8)

    data = data + chr(0x80)
    while (len(data) % 64) != 56:
        data = data + chr(0)

    data = data + pack_u64_be(bit_len)

    h0, h1, h2, h3, h4 = long(0x67452301), long(0xEFCDAB89), long(0x98BADCFE), long(0x10325476), long(0xC3D2E1F0)

    for i in range(0, len(data), 64):
        h0, h1, h2, h3, h4 = _sha1_process_block(
            data[i:i+64], h0, h1, h2, h3, h4
        )

    return (
        chr((h0 >> 24) & 0xFF) + chr((h0 >> 16) & 0xFF) + chr((h0 >> 8) & 0xFF) + chr(h0 & 0xFF) +
        chr((h1 >> 24) & 0xFF) + chr((h1 >> 16) & 0xFF) + chr((h1 >> 8) & 0xFF) + chr(h1 & 0xFF) +
        chr((h2 >> 24) & 0xFF) + chr((h2 >> 16) & 0xFF) + chr((h2 >> 8) & 0xFF) + chr(h2 & 0xFF) +
        chr((h3 >> 24) & 0xFF) + chr((h3 >> 16) & 0xFF) + chr((h3 >> 8) & 0xFF) + chr(h3 & 0xFF) +
        chr((h4 >> 24) & 0xFF) + chr((h4 >> 16) & 0xFF) + chr((h4 >> 8) & 0xFF) + chr(h4 & 0xFF)
    )

# --- HMAC-SHA1 ---
def hmac_sha1(key, msg):
    block_size = 64
    if len(key) > block_size:
        key = sha1(key)
    key = key + chr(0) * (block_size - len(key))

    ipad = ''
    opad = ''
    for i in range(block_size):
        k = ord(key[i])
        ipad = ipad + chr(k ^ 0x36)
        opad = opad + chr(k ^ 0x5c)

    return sha1(opad + sha1(ipad + msg))

# --- HOTP ---
def hotp(key_b32, counter):
    key = b32decode(key_b32)
    msg = pack_u64_be(counter)

    mac = hmac_sha1(key, msg)
    offset = ord(mac[-1]) & 0x0F

    # Извлекаем 4 байта начиная с offset
    chunk = mac[offset:offset+4]
    binary_val = unpack_u32_be(chunk)
    
    binary = long(binary_val) % 2147483648L

    code = str(int(binary))
    digits = 6
    while len(code) < digits:
        code = '0' + code
    return code[-digits:]

# --- TOTP ---
def totp(key_b32):
    now = int(time.time())
    counter = long(int(now / 30))
    return hotp(key_b32, counter)

# --- Main ---
def main():
    now = int(time.time())
    remain_seconds = 30 - (now % 30)

    print '  ----- %02d ------------------------------------------------------------------' % remain_seconds

    for sid, secret, name in srv:
        print '  %s | %s' % (totp(secret), name)

main()
