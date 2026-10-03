"""Validate exported OBJ geometry without starting Godot or touching its import cache."""
from pathlib import Path
from collections import Counter
import json, math

src=Path(__file__).resolve().parent
runtime=src.parents[3]/'game/assets/vfx/elemental_eruptions_v001/models'
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b): return sum(x*y for x,y in zip(a,b))
results=[]
for p in sorted(runtime.glob('*.obj')):
    v=[]; faces=[]; normals=[]
    for line in p.read_text(encoding='utf-8').splitlines():
        tokens=line.split()
        if not tokens: continue
        if tokens[0]=='v': v.append(tuple(map(float,tokens[1:4])))
        elif tokens[0]=='vn': normals.append(tuple(map(float,tokens[1:4])))
        elif tokens[0]=='f': faces.append([int(t.split('/')[0])-1 for t in tokens[1:]])
    assert all(math.isfinite(x) for pos in v for x in pos),p
    assert abs(min(pos[1] for pos in v))<1e-6,p
    assert abs(max(pos[1] for pos in v)-1.0)<1e-6,p
    edges=Counter(); volume=0; minimum_area=100
    for fi,ids in enumerate(faces):
        assert len(ids)==3,p
        a,b,c=(v[i] for i in ids)
        n=cross(sub(b,a),sub(c,a)); area=math.sqrt(dot(n,n))*.5
        minimum_area=min(minimum_area,area)
        assert area>1e-12,(p,fi,'degenerate')
        assert dot(n,normals[fi])>0,(p,fi,'normal mismatch')
        volume+=dot(a,cross(b,c))/6
        for i in range(3): edges[tuple(sorted((ids[i],ids[(i+1)%3])))]+=1
    assert all(count==2 for count in edges.values()),(p,'nonmanifold edge')
    assert volume>0,(p,'inverted winding')
    results.append({'file':p.name,'triangles':len(faces),'closed_manifold_components':True,'outward_winding':True,'normals_match_winding':True,'unit_y_height':True,'minimum_triangle_area':minimum_area,'signed_volume':volume})
assert len(results)==8
(src/'geometry_validation.json').write_text(json.dumps({'passed':True,'assets':results},indent=2),encoding='utf-8')
print(json.dumps({'passed':True,'assets':results},indent=2))
