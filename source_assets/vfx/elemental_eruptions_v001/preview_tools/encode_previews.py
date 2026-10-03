"""Encode genuine Godot viewport captures. Requires bundled imageio_ffmpeg."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

import imageio_ffmpeg


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1] / 'previews')
    parser.add_argument('--fps', type=int, default=30)
    args = parser.parse_args()
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    videos = []
    for skill in ('ice', 'rock'):
        frames = args.root / skill
        if not (frames / 'frame_0000.png').is_file():
            continue
        output = args.root / f'{skill}_eruption_godot.mp4'
        subprocess.run([
            ffmpeg, '-y', '-loglevel', 'warning', '-framerate', str(args.fps),
            '-i', str(frames / 'frame_%04d.png'), '-c:v', 'libx264',
            '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p',
            '-movflags', '+faststart', str(output),
        ], check=True)
        videos.append(output)
        print(output)
    if len(videos) == 2:
        output = args.root / 'elemental_eruptions_godot.mp4'
        subprocess.run([
            ffmpeg, '-y', '-loglevel', 'warning', '-i', str(videos[0]),
            '-i', str(videos[1]), '-filter_complex',
            '[0:v:0][1:v:0]concat=n=2:v=1:a=0[v]', '-map', '[v]',
            '-c:v', 'libx264', '-preset', 'slow', '-crf', '17',
            '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(output),
        ], check=True)
        print(output)


if __name__ == '__main__':
    main()
