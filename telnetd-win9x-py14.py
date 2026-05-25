#!/usr/bin/python

# Python 1.4+ Telnet server for retro-windows 9x
# Aminuxer && AI-ChatGPT ;   v. 2026-05-26

# --- CONFIGURATION ---
PASSWORD = "admin"
PORT = 23
ALLOWED_DRIVES = ["c:"]
# Internal DOS commands that don't have separate .exe files
DOS_INTERNAL = ["dir", "cd", "copy", "del", "md", "rd", "type", "ren", "cls", "ver", "vol", "date", "time"]
# ---------------------

import socket
import os
import string
import time


server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind(('', PORT))
server.listen(1)

print "Telnet server started on port", PORT

while 1:
    conn, addr = server.accept()

    # FORCE SILENT INPUT: Disable local echo on client side (IAC WILL ECHO)
    conn.send("\xff\xfb\x01")
    conn.send("Password: ")

    input_pass = ""
    skip_bytes = 0

    # Read password character by character
    while 1:
        char = conn.recv(1)
        if not char:
            break

        # Parse and skip 3-byte Telnet negotiations (\xff + 2 bytes)
        if ord(char) == 255:
            skip_bytes = 2
            continue
        if skip_bytes > 0:
            skip_bytes = skip_bytes - 1
            continue

        if char == "\r" or char == "\n":
            break

        # Handle Backspace during password entry
        if ord(char) == 8 or ord(char) == 127:
            if len(input_pass) > 0:
                input_pass = input_pass[:-1]
            continue

        input_pass = input_pass + char

    input_pass = string.strip(input_pass)
    conn.send("\xff\xfb\x01")

    if input_pass == PASSWORD:
        current_time = time.ctime(time.time())
        print "[" + current_time + "] User successfully logged in from IP:", addr

        conn.send("\r\n=== Welcome to Windows Shell ===\r\n")
        conn.send("Server time: " + current_time + "\r\n\r\n")

        while 1:
            try:
                current_dir = os.getcwd()
            except:
                current_dir = "C:\\"

            conn.send(current_dir + "> ")

            cmd = ""
            skip_bytes = 0
            client_disconnected = 0

            # Read command character by character
            while 1:
                char = conn.recv(1)
                if not char:
                    client_disconnected = 1
                    break

                # Skip Telnet background negotiations
                if ord(char) == 255:
                    skip_bytes = 2
                    continue
                if skip_bytes > 0:
                    skip_bytes = skip_bytes - 1
                    continue

                # Handle Ctrl-D
                if char == "\x04":
                    cmd = "exit"
                    break

                if char == "\r" or char == "\n":
                    break

                # Handle Backspace (Erase character locally and on client's screen)
                if ord(char) == 8 or ord(char) == 127:
                    if len(cmd) > 0:
                        cmd = cmd[:-1]
                        conn.send("\b \b") 
                    continue

                # Echo character back to the client
                conn.send(char)
                cmd = cmd + char

            if client_disconnected:
                break

            # Filter string from any control characters (allow codes 32-126)
            clean_cmd = ""
            for c in cmd:
                if ord(c) >= 32 and ord(c) <= 126:
                    clean_cmd = clean_cmd + c

            cmd = string.strip(clean_cmd)
            conn.send("\r\n") 

            if cmd == "exit":
                conn.send("Goodbye!\r\n")
                break

            if cmd == "":
                continue

            # DRIVE WHITE-LIST VALIDATION
            cmd_lower = string.lower(cmd)
            is_forbidden = 0
            alphabet = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
            for letter in alphabet:
                drive_trigger = letter + ":"
                if string.find(cmd_lower, drive_trigger) != -1:
                    if not (drive_trigger in ALLOWED_DRIVES):
                        is_forbidden = 1
                        forbidden_drive = drive_trigger
                        break
            if is_forbidden:
                conn.send("Error: Access to drive " + string.upper(forbidden_drive) + " is forbidden by config!\r\n")
                continue

            # HANDLE 'CD' COMMAND
            cmd_parts = string.split(cmd)

            if len(cmd_parts) > 0 and string.lower(cmd_parts[0]) == "cd" and len(cmd_parts) > 1:
                target_dir = string.join(cmd_parts[1:], " ")
                try:
                    os.chdir(target_dir)
                except:
                    conn.send("The system cannot find the path specified.\r\n")
                continue

            # PRE-EXECUTION VALIDATION (DOS search logic: Current Dir -> %PATH%)
            # SAFE FIX: Convert only the first list item (the command string itself) to lowercase
            base_command = string.lower(cmd_parts[0])
            is_valid = 0

            # 1. Check if it is an internal DOS command
            if base_command in DOS_INTERNAL:
                is_valid = 1
            else:
                # 2. Extract search directories: Current Directory first, then %PATH%
                search_dirs = [current_dir]
                if os.environ.has_key('PATH'):
                    path_env = os.environ['PATH']
                    path_dirs = string.split(path_env, ';')
                    for d in path_dirs:
                        d_clean = string.strip(d)
                        if d_clean != "":
                            search_dirs.append(d_clean)

                # 3. Search for executable files
                extensions = ["", ".com", ".exe", ".bat"]
                for directory in search_dirs:
                    if is_valid:
                        break
                    for ext in extensions:
                        full_path = directory + "\\" + base_command + ext
                        if os.path.exists(full_path):
                            is_valid = 1
                            break

                # Fallback for explicit relative/absolute paths containing slashes
                if not is_valid:
                    if string.find(base_command, "\\") != -1 or string.find(base_command, "/") != -1:
                        for ext in ["", ".com", ".exe", ".bat"]:
                            if os.path.exists(base_command + ext) or os.path.exists(current_dir + "\\" + base_command + ext):
                                is_valid = 1
                                break

            if not is_valid:
                conn.send("Bad command or file name\r\n")
                continue

            # IN-MEMORY ARGUMENT COUNT VALIDATION FOR INTERNAL COMMANDS
            if base_command in ["copy", "ren"] and len(cmd_parts) < 3:
                conn.send("Required parameter missing\r\n")
                continue
            if base_command in ["del", "md", "rd", "type"] and len(cmd_parts) < 2:
                conn.send("Required parameter missing\r\n")
                continue

            # IN-MEMORY EXECUTION VIA PURE OS.POPEN WITH BAT CALL WRAPPER
            try:
                # Resolve Windows 95/98 path execution bug for batch files
                if string.find(base_command, ".bat") != -1 or (string.find(cmd_lower, "\\") != -1 and not os.path.exists(base_command + ".exe")):
                    full_cmd = "command.com /c call " + cmd
                else:
                    full_cmd = "command.com /c " + cmd

                pipe = os.popen(full_cmd, "r")
                output = pipe.read()
                pipe.close()

                # IN-MEMORY ERROR DETECTION
                # If popen returns nothing (e.g., on some hidden OS streams errors), notify client
                if output == "":
                    conn.send("Command returned no output or file not found.\r\n")
                else:
                    # Replace single LF with CR+LF for correct terminal rendering
                    lines = string.split(output, "\n")
                    formatted_output = string.join(lines, "\r\n")
                    conn.send(formatted_output + "\r\n")
            except:
                conn.send("Command execution error\r\n")

        print "Client", addr, "disconnected. Waiting for next connection..."
    else:
        conn.send("\r\nAccess Denied.\r\n")
        print "Failed login attempt from IP:", addr

    conn.close()
