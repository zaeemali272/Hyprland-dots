#!/usr/bin/env python3
import os
import sys
import glob
import struct
import select
import subprocess

# Linux input event format: time (tv_sec, tv_usec), type (u16), code (u16), value (s32)
# On 64-bit Linux struct format is 'q q H H i' (long long, long long, unsigned short, unsigned short, int) = 24 bytes
EVENT_FORMAT = 'q q H H i'
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

EV_KEY = 1
KEY_LEFTMETA = 125
KEY_RIGHTMETA = 126
META_KEYS = {KEY_LEFTMETA, KEY_RIGHTMETA}

def get_keyboard_fds():
    fds = []
    for path in glob.glob('/dev/input/event*'):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            fds.append(fd)
        except Exception:
            pass
    return fds

def main():
    fds = get_keyboard_fds()
    if not fds:
        sys.exit(1)

    super_pressed = False
    other_key_pressed = False

    while True:
        r, _, _ = select.select(fds, [], [], 1.0)
        for fd in r:
            try:
                while True:
                    data = os.read(fd, EVENT_SIZE)
                    if len(data) < EVENT_SIZE:
                        break
                    _, _, ev_type, code, value = struct.unpack(EVENT_FORMAT, data)
                    
                    if ev_type == EV_KEY:
                        if code in META_KEYS:
                            if value == 1: # Key press
                                super_pressed = True
                                other_key_pressed = False
                            elif value == 0: # Key release
                                if super_pressed and not other_key_pressed:
                                    # Standalone Super tap detected! Launch launcher
                                    launcher_cmd = os.path.expanduser('~/.config/quickshell/launch.sh')
                                    if os.path.exists(launcher_cmd):
                                        subprocess.Popen([launcher_cmd, 'launcher'])
                                    else:
                                        subprocess.Popen(['zenith', 'launcher'])
                                super_pressed = False
                                other_key_pressed = False
                        else:
                            if value == 1 and super_pressed: # Another key pressed while Super is held
                                other_key_pressed = True
            except (OSError, BlockingIOError):
                pass

if __name__ == '__main__':
    main()
