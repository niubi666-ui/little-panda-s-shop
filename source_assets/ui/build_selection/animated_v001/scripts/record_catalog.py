"""Pipe Godot-rendered frames directly into FFmpeg. No PNG/AVI scratch recordings."""
import argparse
from pathlib import Path
import socket
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[5]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", required=True)
parser.add_argument("--ffmpeg", required=True)
parser.add_argument("--fps", type=int, default=24)
parser.add_argument("--output", type=Path, default=ROOT / "source_assets/ui/build_selection/animated_v001/previews/card_catalog_v001.mp4")
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)


def read_exact(connection, count):
    chunks = bytearray()
    while len(chunks) < count:
        data = connection.recv(count - len(chunks))
        if not data:
            if not chunks:
                return None
            raise RuntimeError("Truncated captured frame")
        chunks.extend(data)
    return bytes(chunks)


frames = 0
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as receiver:
    receiver.bind(("127.0.0.1", 0))
    receiver.listen(1)
    receiver.settimeout(60)
    port = receiver.getsockname()[1]
    with (ROOT / "builds/card_catalog_capture.log").open("w", encoding="utf-8") as log:
        game = subprocess.Popen([args.godot, "--path", str(ROOT / "game"), "--resolution", "1280x800",
            "--fixed-fps", str(args.fps), "--script", "res://ui_lab/card_art_motion/capture_catalog.gd", "--",
            "--catalog-demo", f"--capture-port={port}"], stdout=log, stderr=subprocess.STDOUT)
        encoder = None
        try:
            connection, _ = receiver.accept()
            encoder = subprocess.Popen([args.ffmpeg, "-hide_banner", "-loglevel", "warning", "-f", "image2pipe",
                "-vcodec", "mjpeg", "-framerate", str(args.fps), "-i", "pipe:0", "-an", "-c:v", "libx264",
                "-crf", "17", "-preset", "medium", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-y", str(args.output)], stdin=subprocess.PIPE)
            with connection:
                connection.settimeout(60)
                while header := read_exact(connection, 4):
                    length, = struct.unpack("<I", header)
                    assert 0 < length < 16 * 1024 * 1024
                    frame = read_exact(connection, length)
                    if frame is None:
                        raise RuntimeError("Empty captured frame")
                    encoder.stdin.write(frame)
                    frames += 1
            encoder.stdin.close()
            if encoder.wait() != 0 or game.wait(timeout=30) != 0:
                raise RuntimeError("Capture or encoding failed; see builds/card_catalog_capture.log")
        finally:
            # These handles belong only to processes spawned by this script.
            if game.poll() is None:
                game.terminate()
                game.wait()
            if encoder is not None and encoder.poll() is None:
                encoder.terminate()
                encoder.wait()
print(f"Encoded {frames} frames ({frames/args.fps:.2f}s), {args.output.stat().st_size/1048576:.2f} MiB: {args.output}")
