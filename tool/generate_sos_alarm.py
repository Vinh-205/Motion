"""Generate Motion's original offline Morse SOS alarm (no third-party recording).

Run from the repository root: python tool/generate_sos_alarm.py
"""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
samples = []


def segment(duration, audible=False):
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        envelope = min(1.0, t / 0.008, (duration - t) / 0.008) if audible else 0
        frequency = 740 if int(t / 0.11) % 2 == 0 else 1040
        value = 14000 * max(0, envelope) * (
            math.sin(2 * math.pi * frequency * t)
            + 0.22 * math.sin(4 * math.pi * frequency * t)
        ) / 1.22
        samples.append(int(value))


for group in [[0.16] * 3, [0.48] * 3, [0.16] * 3]:
    for duration in group:
        segment(duration, True)
        segment(0.12)
    segment(0.3)
segment(0.9)

target = Path(__file__).resolve().parents[1] / "android/app/src/main/res/raw/motion_sos.wav"
target.parent.mkdir(exist_ok=True)
with wave.open(str(target), "wb") as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(SAMPLE_RATE)
    output.writeframes(struct.pack("<" + "h" * len(samples), *samples))
print(f"Generated {target.name}: {len(samples) / SAMPLE_RATE:.2f} seconds")
