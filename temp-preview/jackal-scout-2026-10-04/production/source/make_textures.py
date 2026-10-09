from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
P=Path(__file__).parent/'textures'; P.mkdir(exist_ok=True)
rng=np.random.default_rng(52); N=1024

def noise(grid):
    a=rng.random((grid,grid)).astype('float32')
    im=Image.fromarray((a*255).astype('uint8')).resize((N,N), Image.Resampling.BICUBIC)
    return np.asarray(im).astype(float)/255-.5

def save_rgb(name, rgb):
    Image.fromarray(np.uint8(np.clip(rgb,0,1)*255),'RGB').save(P/(name+'.png'))

def normal(name,h,strength):
    gx=np.roll(h,-1,1)-np.roll(h,1,1); gy=np.roll(h,-1,0)-np.roll(h,1,0)
    vec=np.stack([-gx*strength,-gy*strength,np.ones_like(h)],axis=2)
    vec/=np.linalg.norm(vec,axis=2)[...,None]
    save_rgb(name,vec*.5+.5)

n0=noise(12);n1=noise(56);n2=noise(256); fine=rng.random((N,N))-.5
u,v=np.meshgrid(np.arange(N),np.arange(N))
# Directional fur grain, with no particle system or shader-only dependencies.
fiber=np.asarray(Image.fromarray(np.uint8((rng.random((N//8,N)))*255)).resize((N,N),Image.Resampling.BILINEAR)).astype(float)/255-.5
fur=n0*.09+n1*.065+fiber*.10+fine*.025
for name,color in [('fur_ochre',(.46,.285,.14)),('fur_cream',(.72,.61,.44)),('fur_charcoal',(.12,.105,.09))]:
    base=np.array(color)[None,None,:]*(1+fur[...,None]*1.05)
    base+=np.stack([n1*.026,n1*.016,n1*.006],2)
    save_rgb(name+'_color',base)
normal('fur_normal',fiber*.30+n2*.025,2.3)
save_rgb('fur_roughness',np.repeat((.80+fur*.20)[...,None],3,2))
# Worn leather: broad tonal variation and fine branching creases.
creases=(np.sin(u*.067+noise(80)*5)*np.sin(v*.047+noise(63)*5))
creases=np.clip((creases-.55)*3,0,1)
leather=n0*.20+n1*.12+n2*.055+fine*.035-creases*.09
for name,col in [('leather_brown',(.25,.125,.065)),('wrap_dark',(.17,.11,.074))]:
    save_rgb(name+'_color',np.array(col)[None,None,:]*(1+leather[...,None]))
normal('leather_normal',leather,1.4)
save_rgb('leather_roughness',np.repeat((.69+leather*.1)[...,None],3,2))
# Woven cloth: low-contrast albedo plus a directional weave normal.
weave=np.sin(u*np.pi/2)*.16+np.sin(v*np.pi/2)*.16+fine*.07
cloth=n0*.08+n1*.04+weave*.065
for name,col in [('linen',(.56,.48,.35)),('scarf_olive',(.22,.245,.125))]:
    save_rgb(name+'_color',np.array(col)[None,None,:]*(1+cloth[...,None]))
normal('cloth_normal',weave,1.35)
save_rgb('cloth_roughness',np.repeat((.85+cloth*.08)[...,None],3,2))
# Scratched steel keeps a clearly distinct sharpened edge.
steel=n0*.06+n1*.07+n2*.028+fine*.02
scratches=np.asarray(Image.fromarray(np.uint8(rng.random((N//24,N))*255)).resize((N,N),Image.Resampling.BILINEAR)).astype(float)/255-.5
steel+=scratches*.022
save_rgb('steel_color',np.array([.34,.37,.38])[None,None,:]*(1+steel[...,None]))
normal('steel_normal',steel,1.8)
save_rgb('steel_roughness',np.repeat((.42+steel*.7)[...,None],3,2))
# Face atlas with smooth cream muzzle and a charcoal nape. UV corresponds to head loft rings.
a=2*np.pi*u/N
secs=np.array([[.127,.040,1.862,2.043],[.11,.085,1.825,2.083],[.072,.122,1.805,2.125],[.021,.141,1.803,2.141],[-.032,.146,1.808,2.136],[-.082,.132,1.803,2.095],[-.126,.112,1.805,2.053],[-.17,.082,1.815,2.004],[-.2432,.063,1.825,1.960],[-.316,.047,1.839,1.942],[-.3706,.034,1.853,1.920],[-.3953,.022,1.865,1.910]])
t=v/N*(len(secs)-1);lo=np.minimum(t.astype(int),len(secs)-2);fr=t-lo
coords=secs[lo]*(1-fr[...,None])+secs[lo+1]*fr[...,None]
y=coords[...,0];z=(coords[...,2]+coords[...,3])/2+np.sin(a)*(coords[...,3]-coords[...,2])/2
cream_line=np.where(y<-.18,1.902+np.clip((-y-.18)/.21,0,1)*.014,1.889+np.exp(-((y+.095)/.088)**2)*.079)
cm=np.clip((cream_line-z)/.023+.50,0,1);cm=cm*cm*(3-2*cm)
black=np.clip((y-.034)/.060,0,1)*np.clip((z-1.986)/.095,0,1)
black=np.maximum(black,np.clip((z-2.112)/.035,0,1)*np.clip((y+.018)/.07,0,1)*np.clip((.36-np.abs(np.cos(a)))/.2,0,1))
x=coords[...,1]*np.cos(a)
black=np.maximum(black,.78*np.clip((z-2.045)/.083,0,1)*np.clip((.027-np.abs(x))/.018,0,1)*np.clip((y+.15)/.08,0,1))
col=np.array([.46,.285,.14])[None,None,:]*(1-cm[...,None])+np.array([.72,.61,.44])[None,None,:]*cm[...,None]
col=col*(1-black[...,None])+np.array([.12,.105,.09])[None,None,:]*black[...,None]
col*=1+fur[...,None]
save_rgb('jackal_face_color',np.flipud(col))
print('Created' ,len(list(P.glob('*.png'))),'PBR texture images')
