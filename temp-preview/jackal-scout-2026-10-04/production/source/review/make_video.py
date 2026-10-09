"""Encode the rendered rig frames as review media; requires ffmpeg and ffprobe."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--frames', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
sequence = json.loads((args.frames / 'sequence.json').read_text())
fps = sequence['fps']
labels = {'Run': 'Run - in place', 'Attack': 'Attack - right hand slash', 'Hit': 'Hit reaction'}
filters = ['drawbox=x=0:y=0:w=iw:h=48:color=black@0.5:t=fill']
for index, clip in enumerate(sequence['clips']):
    start = clip['first_output_frame']
    end = sequence['clips'][index + 1]['first_output_frame'] - 1 if index + 1 < len(sequence['clips']) else sequence['frames'] - 1
    filters.append("drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:"
                   f"text='{labels[clip['name']]}':fontsize=22:fontcolor=white:x=18:y=12:"
                   f"enable='between(n,{start},{end})'")
base_filter = ','.join(filters)
input_args = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', str(fps), '-i', str(args.frames / 'frame-%04d.png')]
outputs = []
for name, extra in [('animation-preview.mp4', ''), ('animation-preview-slow.mp4', ',setpts=2*PTS')]:
    target = args.out / name
    subprocess.run(input_args + ['-vf', base_filter + extra, '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(target)], check=True)
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(target)]))
    outputs.append({'file': name, 'bytes': target.stat().st_size,
                    'duration_seconds': float(probe['format']['duration']),
                    'codec': probe['streams'][0]['codec_name'],
                    'width': probe['streams'][0]['width'], 'height': probe['streams'][0]['height']})
gif = args.out / 'animation-preview.gif'
gif_filter = base_filter + ',setpts=2*PTS,fps=6,scale=448:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=bayer:bayer_scale=3'
subprocess.run(input_args + ['-filter_complex', gif_filter, '-loop', '0', str(gif)], check=True)
outputs.append({'file': gif.name, 'bytes': gif.stat().st_size, 'speed': '0.5x', 'fps': 6, 'width': 448})
(args.out / 'media-report.json').write_text(json.dumps({'source_sequence': sequence, 'outputs': outputs}, indent=2) + '\n')
print(json.dumps(outputs, indent=2))
