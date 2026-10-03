"""Encode actual Godot frames and annotate a time sequence for visual review."""
from pathlib import Path
import subprocess
import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / 'previews/final'
frames = ROOT / 'frostfall'
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([ffmpeg, '-y', '-loglevel', 'warning', '-framerate', '30', '-i', str(frames / 'frame_%04d.png'), '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(ROOT / 'frostfall_godot.mp4')], check=True)
times = [0.3, 0.5, 0.7, 1.0, 1.3, 1.7, 2.3, 4.0]
sheet = Image.new('RGB', (1280, 488), (10, 16, 29))
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)
draw.text((12, 9), 'FROST CROWN DESCENT | Godot timeline samples', font=font, fill=(220, 224, 235))
for i, t in enumerate(times):
    frame = round(t * 30)
    pic = Image.open(frames / f'frame_{frame:04d}.png').convert('RGB').resize((320, 180), Image.Resampling.LANCZOS)
    x, y = (i % 4) * 320, 40 + (i // 4) * 224
    sheet.paste(pic, (x, y))
    draw.text((x + 12, y + 187), f'{frame/30:.2f} s', font=font, fill=(197, 208, 234))
sheet.save(ROOT / 'frostfall_timeline.jpg', quality=93)
print(ROOT / 'frostfall_godot.mp4')
print(ROOT / 'frostfall_timeline.jpg')
