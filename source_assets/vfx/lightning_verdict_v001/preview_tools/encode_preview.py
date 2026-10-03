"""Encode the actual Godot render and produce a labelled time sequence for review."""
from pathlib import Path
import subprocess
import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]/'previews/final'
frames=ROOT/'lightning'
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([ffmpeg,'-y','-loglevel','warning','-framerate','30','-i',str(frames/'frame_%04d.png'),'-c:v','libx264','-preset','slow','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(ROOT/'lightning_verdict_godot.mp4')],check=True)
times=[0.0,0.3,0.5,0.73,0.97,1.3,2.2,3.5]
sheet=Image.new('RGB',(1280,488),(10,16,29))
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
draw.text((12,9),'TEMPEST VERDICT | Godot timeline samples',font=font,fill=(220,224,235))
for i,t in enumerate(times):
    frame=round(t*30)
    image=Image.open(frames/f'frame_{frame:04d}.png').convert('RGB').resize((320,180),Image.Resampling.LANCZOS)
    x=(i%4)*320
    y=40+(i//4)*224
    sheet.paste(image,(x,y))
    draw.text((x+12,y+187),f'{frame/30:.2f} s',font=font,fill=(197,208,234))
sheet.save(ROOT/'lightning_timeline.jpg',quality=93)
print(ROOT/'lightning_verdict_godot.mp4')
print(ROOT/'lightning_timeline.jpg')
