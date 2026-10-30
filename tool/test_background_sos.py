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
import re
import time
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument("--flutter", default=shutil.which("flutter"))
parser.add_argument("--adb", default=shutil.which("adb") or str(
    Path(os.environ.get("LOCALAPPDATA", "")) / "Android/sdk/platform-tools/adb.exe"))
parser.add_argument("--device", default="emulator-5554")
parser.add_argument("--lock", action="store_true", help="Lock the test emulator during native countdown; no real SMS/calls")
args = parser.parse_args()
if not args.device.startswith("emulator-"):
    parser.error("Use an isolated Android emulator; this runner installs a test app and manipulates the lock screen.")
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

def shell(*command):
    return subprocess.run([args.adb, "-s", args.device, "shell", *command],
                          check=True, capture_output=True, timeout=25, **kwargs).stdout.decode("utf-8", "replace")

def wake():
    shell("input", "keyevent", "224")
    shell("wm", "dismiss-keyguard")

def dump_ui():
    shell("uiautomator", "dump", "/data/local/tmp/motion-card-test.xml")
    return shell("cat", "/data/local/tmp/motion-card-test.xml")

notification_was_granted = "android.permission.POST_NOTIFICATIONS: granted=true" in shell("dumpsys", "package", "com.example.cam_bien_te_nga")

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
                if not notification_was_granted:
                    shell("pm", "grant", "com.example.cam_bien_te_nga", "android.permission.POST_NOTIFICATIONS")
                reopen()
                print("Host reopened test Activity after verifying background pause.", flush=True)
            if args.lock and "MOTION_NATIVE_DRY_RUN_COUNTDOWN_STARTED" in line:
                shell("input", "keyevent", "223")
                print("Host locked the emulator during native countdown.", flush=True)
            if "MOTION_CARD_LOCKED_READ_READY" in line:
                shell("input", "keyevent", "224")
                shell("cmd", "statusbar", "expand-notifications")
                nodes = ET.fromstring(dump_ui()).iter("node")
                target = next((n for n in nodes if "SOS" in n.get("text", "") and "MOTION" in n.get("text", "")), None)
                assert target is not None, "SOS notification not found on lock screen"
                x1, y1, x2, y2 = map(int, re.findall(r"\d+", target.get("bounds")))
                shell("input", "tap", str((x1+x2)//2), str((y1+y2)//2))
                time.sleep(1)
                card = dump_ui()
                assert "Motion Test Wearer" in card, "Native emergency card was not readable"
                assert "Quản trị Motion" not in card, "Account dashboard must not be exposed"
                ciphertext = shell("run-as", "com.example.cam_bien_te_nga", "cat", "shared_prefs/motion_emergency_card.xml")
                assert 'name="data"' in ciphertext and "Motion Test Wearer" not in ciphertext, "Card fixture must be encrypted at rest"
                print("Host verified isolated emergency card; no account dashboard.", flush=True)
                wake()
                shell("input", "keyevent", "4")
                reopen()
            if "MOTION_" in line or "All tests passed" in line or "[E]" in line:
                print(line.strip(), flush=True)
        code = process.wait()
    finally:
        wake()
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=20)
        # Flutter integration_test can uninstall its temporary app on completion.
        if "package:" in shell("pm", "list", "packages", "com.example.cam_bien_te_nga"):
            reopen()
            if not notification_was_granted:
                shell("pm", "revoke", "com.example.cam_bien_te_nga", "android.permission.POST_NOTIFICATIONS")
print("Full log:", log)
sys.exit(code)
