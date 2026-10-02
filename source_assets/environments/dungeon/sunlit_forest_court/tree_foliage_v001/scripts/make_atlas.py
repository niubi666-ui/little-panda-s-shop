from PIL import Image, ImageDraw
import math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=2048
im=Image.new('RGBA',(S,S),(0,0,0,0))
d=ImageDraw.Draw(im)
random.seed(41)
def leaf(cx,cy,L,angle,col):
    ux,uy=math.cos(angle),math.sin(angle)
    vx,vy=-uy,ux
    def p(t,w): return (cx+ux*L*t+vx*L*w,cy+uy*L*t+vy*L*w)
    # Lobed oak silhouette, six broad rounded lobes along each edge.
    edges=[]
    for side in [1,-1]:
        ts=[i/48 for i in range(49)]
        if side<0: ts.reverse()
        for t in ts:
            w=math.sin(math.pi*t)**0.65*(0.24+0.065*math.cos(t*math.pi*12))
            edges.append(p(t,side*w))
    d.polygon(edges,fill=(*col,255))
    left=[p(0,0)]+edges[:49]+[p(1,0)]
    d.polygon(left,fill=(min(255,col[0]+10),min(255,col[1]+13),col[2]+3,255))
    d.line([p(.02,0),p(.97,0)],fill=(col[0]+25,col[1]+22,col[2]+12,255),width=2)
    for j in range(1,8):
        t=j/9
        for side in [-1,1]:
            d.line([p(t-.065,0),p(t,side*.13*math.sin(math.pi*t))],fill=(col[0]+15,col[1]+14,col[2]+6,255),width=1)
for k in range(4):
    ox=(k%2)*1024; oy=(k//2)*1024
    def twig(t): return (ox+510+math.sin(t*2.7+k)*48,oy+940-t*830)
    d.line([twig(i/40) for i in range(41)],fill=(99,80,39,255),width=9)
    for j in range(9):
        t=.1+j*.09
        x,y=twig(t)
        for sign in [-1,1]:
            length=random.uniform(225,285)*(1-.3*t)
            ang=-math.pi/2+sign*random.uniform(.82,1.15)
            bx=x+math.cos(ang)*length*.36; by=y+math.sin(ang)*length*.36
            d.line([(x,y),(bx,by)],fill=(108,90,44,255),width=4)
            shade=random.randrange(-13,14)
            leaf(bx,by,length,ang,(86+shade+k*4,111+shade+k*3,38+shade//2))
    leaf(*twig(.89),155,-math.pi/2,(114,133,47))
im.save(ROOT/'textures/oak_branch_atlas_rgba.png')
# Edge color dilation prevents dark mip seams without altering alpha.
from PIL import ImageFilter
rgb=im.convert('RGB')
for i in range(8): rgb=rgb.filter(ImageFilter.MaxFilter(3))
rgb.paste(im.convert('RGB'),mask=im.getchannel('A'))
rgb.putalpha(im.getchannel('A')); rgb.save(ROOT/'textures/oak_branch_atlas_rgba.png')
print('Atlas saved',ROOT/'textures/oak_branch_atlas_rgba.png')
