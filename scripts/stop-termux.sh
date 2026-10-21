#!/data/data/com.termux/files/usr/bin/bash
# Stop the XTM-Miner child recorded in this Termux installation's private lock.
# Refuses an absent or unexpected lock process and uses a Linux pidfd to bind
# identity, TERM delivery, and exit waiting to the same process once opened.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/xtm-miner"
LOCK_DIR="${PREFIX:-}/var/lib/xtm-miner/miner.lock"
PID_FILE="$LOCK_DIR/pid"

fail() {
  echo "Error: $*" >&2
  exit 2
}

[[ "${PREFIX:-}" == /data/data/com.termux/files/usr ]] || fail "run this stop helper inside the supported Termux installation"
[[ -x "$BIN" ]] || fail "current project binary missing: $BIN"
command -v python3 >/dev/null 2>&1 || fail "Python 3 is required for safe pidfd-based stopping"
[[ -d "$LOCK_DIR" ]] || {
  echo "No active XTM-Miner lock found; nothing was stopped."
  exit 0
}
[[ -r "$PID_FILE" ]] || fail "incomplete lock at $LOCK_DIR; inspect it manually and do not remove it while a miner may be running"

PID="$(cat "$PID_FILE")"
[[ "$PID" =~ ^[1-9][0-9]*$ ]] || fail "invalid PID in lock; inspect $LOCK_DIR manually"

# The pinned ARM64 target uses Linux's asm-generic syscall numbers: pidfd_send_signal
# is 424 and pidfd_open is 434. Some Termux Python builds omit high-level pidfd APIs,
# so call libc's syscall entry through standard ctypes. Fail closed if the kernel or
# app sandbox rejects pidfds; never substitute an unsafe numeric-PID kill.
python3 - "$PID" "$BIN" <<'PY'
import ctypes
import os
import platform
import select
import signal
import sys

pid = int(sys.argv[1])
binary = sys.argv[2]
machine = platform.machine()
if machine not in {"aarch64", "x86_64"}:
    raise SystemExit(f"Error: pidfd syscall numbers are not declared for architecture {machine}; refusing unsafe numeric-PID stop")

SYS_PIDFD_SEND_SIGNAL = 424
SYS_PIDFD_OPEN = 434
libc = ctypes.CDLL(None, use_errno=True)

def syscall_or_error(number, *args):
    result = libc.syscall(ctypes.c_long(number), *args)
    if result == -1:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))
    return result

try:
    pidfd = syscall_or_error(SYS_PIDFD_OPEN, ctypes.c_int(pid), ctypes.c_uint(0))
except OSError as exc:
    raise SystemExit(f"Error: cannot open pidfd for lock PID {pid}: {exc}; refusing to signal it")
try:
    try:
        direct_match = os.path.samefile(f"/proc/{pid}/exe", binary)
    except FileNotFoundError:
        raise SystemExit(f"Error: lock PID {pid} exited before identity validation; refusing to signal it")

    if not direct_match:
        # Google Play Termux uses system_linker_exec, so /proc/PID/exe can be
        # Android's linker even when this binary is the loaded executable. In
        # that specific case require an exact executable mapping: same absolute
        # path, same device/inode, and execute permission. A pidfd is already
        # open, so a numeric PID reuse cannot redirect the subsequent signal.
        linker = os.path.realpath(f"/proc/{pid}/exe")
        binary_real = os.path.realpath(binary)
        binary_stat = os.stat(binary_real)
        wanted_device = (os.major(binary_stat.st_dev), os.minor(binary_stat.st_dev))
        mapped_binary = False
        try:
            with open(f"/proc/{pid}/maps", encoding="utf-8") as maps:
                for raw in maps:
                    fields = raw.rstrip("\n").split(None, 5)
                    if len(fields) != 6:
                        continue
                    _address, permissions, _offset, device, inode, pathname = fields
                    try:
                        map_major, map_minor = (int(part, 16) for part in device.split(":", 1))
                        map_inode = int(inode)
                    except (ValueError, TypeError):
                        continue
                    if (
                        "x" in permissions
                        and (map_major, map_minor) == wanted_device
                        and map_inode == binary_stat.st_ino
                        and pathname == binary_real
                    ):
                        mapped_binary = True
                        break
        except FileNotFoundError:
            raise SystemExit(f"Error: lock PID {pid} exited before mapping validation; refusing to signal it")

        # Android/Google Play Termux may present either linker64 or the binary
        # pathname through /proc/PID/exe while samefile() still cannot compare
        # it to the app-data executable. Accept either known representation only
        # with the exact executable-map validation above.
        known_representation = linker.endswith("/linker64") or linker == binary_real
        if not (known_representation and mapped_binary):
            raise SystemExit(
                f"Error: lock PID {pid} is not this project's XTM-Miner binary "
                f"(proc exe={linker}); refusing to signal it"
            )

    # Recheck the pidfd target after all procfs reads. If the original process
    # exited and its numeric PID was reused during identity inspection, signal
    # 0 on this pidfd fails rather than accepting the replacement's procfs data.
    try:
        syscall_or_error(
            SYS_PIDFD_SEND_SIGNAL,
            ctypes.c_int(pidfd),
            ctypes.c_int(0),
            ctypes.c_void_p(),
            ctypes.c_uint(0),
        )
    except OSError as exc:
        raise SystemExit(f"Error: validated pidfd target exited before TERM: {exc}; refusing to signal it")

    print(f"Requesting TERM stop for XTM-Miner PID {pid} through pidfd.")
    try:
        syscall_or_error(
            SYS_PIDFD_SEND_SIGNAL,
            ctypes.c_int(pidfd),
            ctypes.c_int(signal.SIGTERM),
            ctypes.c_void_p(),
            ctypes.c_uint(0),
        )
    except OSError as exc:
        raise SystemExit(f"Error: pidfd TERM request failed for PID {pid}: {exc}")

    poller = select.poll()
    poller.register(pidfd, select.POLLIN)
    if not poller.poll(10_000):
        raise SystemExit(f"Error: XTM-Miner PID {pid} did not exit within 10 seconds; do not start another instance")
    print(f"Native child PID {pid} exited after TERM.")
finally:
    os.close(pidfd)
PY

for _ in {1..30}; do
  [[ ! -d "$LOCK_DIR" ]] && {
    echo "PASS: native child stopped and launcher released the lock."
    exit 0
  }
  sleep 0.1
done

fail "native child stopped, but lock remains at $LOCK_DIR; inspect it before another start"
