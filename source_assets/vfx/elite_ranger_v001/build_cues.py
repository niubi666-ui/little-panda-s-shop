"""Reproducible temporary charge/lock cues; runtime mixing belongs to ranger_style.tres."""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "game/assets/vfx/elite_ranger_v001"
RATE = 22050


def build(name, duration, frequency, rise):
    samples = bytearray()
    for index in range(round(duration * RATE)):
        t = index / RATE
        progress = t / duration
        envelope = min(1.0, t / 0.025) * (1.0 - progress) ** 0.5
        phase = math.tau * (frequency * t + rise * t * t / 2.0)
        tone = (math.sin(phase) + 0.22 * math.sin(phase * 2.0)) / 1.22
        samples += struct.pack("<h", round(tone * envelope * 18000))
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(samples)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    build("charge.wav", 2.0, 180.0, 160.0)
    build("lock.wav", 0.22, 880.0, -400.0)
