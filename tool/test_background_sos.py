"""Run the no-SMS integration test and reopen its task after a real trip Home.

The app does not bypass Android activity-launch restrictions. This host runner
uses adb to perform the return that a tester would normally perform manually.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--flutter", default=shutil.which("flutter"))
parser.add_argument("--adb", default=shutil.which("adb") or str(
    Path(os.environ.get("LOCALAPPDATA", "")) / "Android/sdk/platform-tools/adb.exe"))
parser.add_argument("--device", default="emulator-5554")
args = parser.parse_args()
if not args.flutter:
    parser.error("Flutter is not on PATH. Pass --flutter with the SDK flutter executable.")
root = Path(__file__).resolve().parents[1]
log = root / "build/background-sos-integration.log"
log.parent.mkdir(exist_ok=True)
kwargs = {}
if os.name == "nt":
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    kwargs = {"startupinfo": startup, "creationflags": subprocess.CREATE_NO_WINDOW}

def reopen():
    subprocess.run([args.adb, "-s", args.device, "shell", "am", "start", "-n",
                    "com.example.cam_bien_te_nga/.MainActivity"],
                   check=True, capture_output=True, timeout=20, **kwargs)

with log.open("w", encoding="utf-8") as output:
    process = subprocess.Popen(
        [args.flutter, "test", "integration_test/device_safety_test.dart", "-d", args.device],
        cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", **kwargs)
    try:
        for line in process.stdout:
            output.write(line)
            output.flush()
            if "MOTION_DRY_RUN_READY_TO_RETURN" in line:
                reopen()
                print("Host reopened test Activity after verifying background pause.", flush=True)
            if "MOTION_" in line or "All tests passed" in line or "[E]" in line:
                print(line.strip(), flush=True)
        code = process.wait()
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=20)
        reopen()
print("Full log:", log)
sys.exit(code)
