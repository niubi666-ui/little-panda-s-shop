"""把 .blend 里指向旧文件夹的贴图路径改到新位置（文件夹整体搬家后用）。

    blender --background <文件.blend> --python relink_moved.py -- <旧文件夹> <新文件夹>

只改没打包的图片：绝对路径直接替换前缀；相对路径（//开头）先按旧位置换算成绝对路径，
落在旧文件夹里的换到新文件夹，再换回相对路径。最后列出仍然找不到的图片并保存。
"""
import os
import sys

import bpy

old_dir, new_dir = [os.path.normcase(os.path.normpath(p)) for p in sys.argv[sys.argv.index("--") + 1:][:2]]
blend_dir = os.path.dirname(bpy.data.filepath)
# 文件已经搬到新位置：相对路径要按“搬家前文件所在的位置”去解读
old_blend_dir = os.path.normpath(blend_dir.replace(new_dir, old_dir, 1)) if os.path.normcase(blend_dir).startswith(new_dir) else blend_dir


def moved(path):
    full = os.path.normpath(path)
    if os.path.normcase(full).startswith(old_dir):
        return os.path.join(new_dir, full[len(old_dir):].lstrip("\\/"))
    return full


changed = 0
missing = []
for image in bpy.data.images:
    if image.packed_file is not None or image.source not in {"FILE", "SEQUENCE", "TILED"} or not image.filepath:
        continue
    raw = image.filepath
    relative = raw.startswith("//")
    absolute = os.path.normpath(os.path.join(old_blend_dir, raw[2:])) if relative else raw
    target = moved(absolute)
    if os.path.exists(target):
        new = bpy.path.relpath(target) if relative else target
        if new != raw:
            image.filepath = new
            changed += 1
    elif not os.path.exists(bpy.path.abspath(raw)):
        missing.append(raw)
print("RELINK changed=%d missing=%d %s" % (changed, len(missing), missing[:8]))
bpy.ops.wm.save_mainfile()
print("RELINK saved", bpy.data.filepath)
