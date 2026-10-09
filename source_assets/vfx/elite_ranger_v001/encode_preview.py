"""Encode unedited, actual Godot frames. No concept imagery is used in the movie."""
from pathlib import Path
import json
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent
PREVIEW = SOURCE / "previews"
FRAMES = ROOT / "builds/ranger_vfx_capture_v001"
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
report = {"source":"Godot Forward+ actual training scene frames", "fps":30, "skills":[]}
for skill in ["fast", "volley", "rain"]:
    images = sorted((FRAMES / skill).glob("frame_*.png"))
    assert images and len(images) == int(images[-1].stem.split("_")[-1])+1
    output = PREVIEW / (skill + ".mp4")
    subprocess.run([ffmpeg,"-y","-loglevel","error","-framerate","30","-i",
                    str(FRAMES / skill / "frame_%04d.png"),"-c:v","libx264",
                    "-preset","medium","-crf","17","-pix_fmt","yuv420p",
                    "-movflags","+faststart",str(output)],check=True)
    report["skills"].append({"id":skill,"frames":len(images),
                              "duration_sec":len(images)/30,"video":output.name})
concat = PREVIEW / "video_concat.txt"
concat.write_text("\n".join("file '"+str(PREVIEW / (skill+".mp4")).replace("\\","/")+"'"
                            for skill in ["fast","volley","rain"]),encoding="utf-8")
output = PREVIEW / "elite_ranger_skills_godot.mp4"
subprocess.run([ffmpeg,"-y","-loglevel","error","-f","concat","-safe","0","-i",
                str(concat),"-c","copy","-movflags","+faststart",str(output)],check=True)
report["combined"] = output.name
report["total_frames"] = sum(item["frames"] for item in report["skills"])
report["duration_sec"] = report["total_frames"]/30
(PREVIEW / "video_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report))
