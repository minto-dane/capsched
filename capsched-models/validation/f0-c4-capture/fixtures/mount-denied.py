#!/usr/bin/python3
import ctypes
import errno


libc = ctypes.CDLL(None, use_errno=True)
result = libc.mount(
    ctypes.c_char_p(b"tmpfs"),
    ctypes.c_char_p(b"/tmp"),
    ctypes.c_char_p(b"tmpfs"),
    ctypes.c_ulong(0),
    ctypes.c_char_p(b"size=1M"),
)
error = ctypes.get_errno()
if result != -1 or error != errno.EPERM:
    raise SystemExit(f"mount was not seccomp-denied: rc={result} errno={error}")
print("FIXTURE_MOUNT_DENIED")
