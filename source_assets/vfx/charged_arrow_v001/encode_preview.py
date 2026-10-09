"""Encode unedited Godot frames and mix this study's own generated sound cues."""
from pathlib import Path
import json
import re
import subprocess
import wave
import numpy as np
import imageio_ffmpeg

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PREVIEW = HERE / "previews"
FRAMES = ROOT / "builds/charged_arrow_v001_frames"
report = json.loads((PREVIEW / "capture_report.json").read_text(encoding="utf-8"))
fps = report["fps"]
sr = 48000
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
gain = 10 ** (float(re.search(r"audio_volume_db = ([-\d.]+)",
            (HERE / "godot_demo/fx/profile.tres").read_text(encoding="utf-8")).group(1))/20)
sounds = {}
for key in ["charge", "fire", "pulse"]:
    with wave.open(str(HERE / "godot_demo/assets" / (key + ".wav")), "rb") as w:
        sounds[key] = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32)/32768.0

def resample(raw, scale):
    old = np.arange(len(raw))
    new = np.arange(round(len(raw)/scale))*scale
    return np.interp(new, old, raw).astype(np.float32)

def mix(buffer, cue, when):
    offset = round(when*sr)
    src = max(0, -offset)
    dst = max(0, offset)
    count = min(len(cue)-src,len(buffer)-dst)
    if count > 0: buffer[dst:dst+count] += cue[src:src+count]*gain

movies = []
for segment in report["segments"]:
    id_ = segment["id"]
    count = segment["frames"]
    files = sorted((FRAMES / id_).glob("frame_*.png"))
    assert len(files) == count and files[-1].stem == "frame_%04d" % (count-1)
    buffer = np.zeros(round(count/fps*sr),dtype=np.float32)
    scale = segment["time_scale"]
    start = segment["start_simulation_time"]
    charge = sounds["charge"][round(start*sr):]
    mix(buffer,resample(charge,scale),0)
    for event in segment["events"]:
        if event["time"] < start: continue
        when = (event["time"]-start)/scale
        if event["kind"] == "release": mix(buffer,resample(sounds["fire"],scale),when)
        elif event["kind"] == "scar": mix(buffer,resample(sounds["pulse"],scale),when)
    audio = PREVIEW / (id_ + "_sound.wav")
    with wave.open(str(audio),"wb") as w:
        w.setparams((1,2,sr,0,"NONE","not compressed"))
        w.writeframes((np.clip(buffer,-1,1)*32760).astype("<i2").tobytes())
    movie = PREVIEW / (id_ + ".mp4")
    subprocess.run([ffmpeg,"-y","-loglevel","error","-framerate",str(fps),"-i",
                    str(FRAMES / id_ / "frame_%04d.png"),"-i",str(audio),"-c:v","libx264",
                    "-preset","medium","-crf","18","-pix_fmt","yuv420p","-c:a","aac",
                    "-b:a","160k","-shortest","-movflags","+faststart",str(movie)],check=True)
    movies.append(movie)
concat = PREVIEW / "movie_concat.txt"
concat.write_text("\n".join("file '"+str(path).replace("\\","/")+"'" for path in movies),encoding="utf-8")
final = PREVIEW / "charged_arrow_godot.mp4"
subprocess.run([ffmpeg,"-y","-loglevel","error","-f","concat","-safe","0","-i",
                str(concat),"-c","copy","-movflags","+faststart",str(final)],check=True)
reader = imageio_ffmpeg.read_frames(str(final),pix_fmt="rgb24")
metadata = next(reader)
decoded = sum(1 for frame in reader)
result = {"video":str(final),"frames":decoded,"fps":metadata["fps"],"size":metadata["size"],
          "duration_sec":metadata["duration"],"source":"Actual Godot frames; original synthesized cues; normal and explicitly marked 0.2-time-scale segments"}
(PREVIEW / "video_report.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(result,ensure_ascii=False))
