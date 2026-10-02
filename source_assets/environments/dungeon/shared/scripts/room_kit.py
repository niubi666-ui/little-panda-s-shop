"""Editable Blender environment authoring kit; no gameplay or engine code.
Run only in an isolated Blender --background --factory-startup process.
All dimensions below are artistic model construction parameters in metres.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

BASE = Path('E:/ShopGame/source_assets/environments/dungeon')

def enum(obj, key, value):
    prop = obj.bl_rna.properties.get(key)
    if prop and prop.type == 'ENUM':
        valid = [item.identifier for item in prop.enum_items]
        if value not in valid:
            raise ValueError(f'{key}: {value} not in {valid}')
    setattr(obj,key,value)

class Kit:
    def __init__(self, room, seed=260926):
        assert bpy.app.background, 'Authoring script must not alter the live user session'
        self.room=room; self.dir=BASE/room; self.rng=random.Random(seed)
        for part in ['blender','previews','reports','scripts','reference']:
            (self.dir/part).mkdir(parents=True,exist_ok=True)
        # This reset is scoped to the fresh background process.
        for o in list(bpy.data.objects): bpy.data.objects.remove(o,do_unlink=True)
        self.scene=bpy.context.scene; self.scene.name=room+'_art_v001'
        self.groups={};self.mats={};self.seed=seed
        for name in ['Architecture','Floor','Decor','Flora','Lighting','Cameras','Atmosphere','Replacement_Props','Authoring_Guides']:
            self.collection(name)
        self.materials()
        enum(self.scene.unit_settings,'system','METRIC');self.scene.unit_settings.scale_length=1

    def collection(self,name):
        if name not in self.groups:
            col=bpy.data.collections.new(name);self.scene.collection.children.link(col);self.groups[name]=col
        return self.groups[name]

    def material(self,mat): return self.mats[mat] if isinstance(mat,str) else mat

    def mesh(self,name,verts,faces,mat='stone',group='Architecture'):
        data=bpy.data.meshes.new(name+'_mesh');data.from_pydata(verts,[],faces);data.update()
        obj=bpy.data.objects.new(name,data);self.collection(group).objects.link(obj)
        if mat is not None: data.materials.append(self.material(mat))
        if isinstance(mat,str) and (mat in ['stone','stone_dark','forest_ground'] or mat.startswith('floor_')):
            uv=data.uv_layers.new(name='SurfaceUV_2m')
            offset=self.rng.uniform(0,2),self.rng.uniform(0,2)
            for poly in data.polygons:
                normal=poly.normal;axis=max(range(3),key=lambda k:abs(normal[k]))
                axes=(0,1) if axis==2 else (0,2) if axis==1 else (1,2)
                for loop in poly.loop_indices:
                    vertex=data.vertices[data.loops[loop].vertex_index].co
                    uv.data[loop].uv=(vertex[axes[0]]*.5+offset[0],vertex[axes[1]]*.5+offset[1])
        obj['art_asset']=True
        return obj

    def root(self,name,loc=(0,0,0),group='Architecture'):
        obj=bpy.data.objects.new(name,None);obj.location=loc;self.collection(group).objects.link(obj)
        obj.empty_display_size=.35;obj['module_id']=name.lower().replace(' ','_');return obj

    def bevel(self,obj,width=.03,segments=2):
        if width>0:
            mod=obj.modifiers.new('Worn soft edges','BEVEL');mod.width=width;mod.segments=segments
        return obj

    def box(self,name,loc,dim,mat='stone',bevel=.03,group='Architecture'):
        dx,dy,dz=[v/2 for v in dim]
        verts=[(-dx,-dy,-dz),(-dx,-dy,dz),(-dx,dy,-dz),(-dx,dy,dz),(dx,-dy,-dz),(dx,-dy,dz),(dx,dy,-dz),(dx,dy,dz)]
        faces=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
        obj=self.mesh(name,verts,[tuple(reversed(f)) for f in faces],mat,group);obj.location=loc
        self.bevel(obj,min(bevel,min(dim)*.23),2);return obj

    def cylinder(self,name,loc,radius,depth,mat='brass',vertices=16,group='Decor'):
        return self.lathe(name,loc,[(radius,-depth/2),(radius,depth/2)],mat,vertices,group)

    def lathe(self,name,loc,profile,mat='stone',segments=24,group='Decor'):
        verts=[];faces=[]
        for radius,z in profile:
            for j in range(segments):
                a=2*math.pi*j/segments;verts.append((radius*math.cos(a),radius*math.sin(a),z))
        for k in range(len(profile)-1):
            for j in range(segments):faces.append((k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j))
        faces.append(tuple(reversed(range(segments))))
        faces.append(tuple((len(profile)-1)*segments+j for j in range(segments)))
        obj=self.mesh(name,verts,faces,mat,group);obj.location=loc
        for poly in obj.data.polygons:poly.use_smooth=len(poly.vertices)==4
        return obj

    def curve(self,name,points,radius,mat='brass',group='Decor'):
        data=bpy.data.curves.new(name+'_curve','CURVE');enum(data,'dimensions','3D');data.resolution_u=1;data.bevel_depth=radius;data.bevel_resolution=2
        spline=data.splines.new('POLY');spline.points.add(len(points)-1)
        for v,p in zip(spline.points,points):v.co=(*p,1)
        obj=bpy.data.objects.new(name,data);self.collection(group).objects.link(obj);data.materials.append(self.material(mat));return obj

    def plain(self,name,color,roughness=.6,metallic=0):
        m=bpy.data.materials.new(name);m.use_nodes=True
        p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=roughness;p.inputs['Metallic'].default_value=metallic
        m.diffuse_color=(*color,1);return m

    def textured(self,name,c1,c2,scale=6,roughness=.7,bump=.18,distance=.045):
        m=self.plain(name,c1,roughness);n=m.node_tree.nodes;l=m.node_tree.links
        p=next(n for n in n if n.type=='BSDF_PRINCIPLED')
        tex=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=4;noise.inputs['Roughness'].default_value=.7
        l.new(tex.outputs['Object'],noise.inputs['Vector'])
        ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.17;ramp.color_ramp.elements[0].color=(*c1,1);ramp.color_ramp.elements[1].position=.82;ramp.color_ramp.elements[1].color=(*c2,1)
        l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
        fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=scale*18;fine.inputs['Detail'].default_value=2;l.new(tex.outputs['Object'],fine.inputs['Vector'])
        b1=n.new('ShaderNodeBump');b1.inputs['Strength'].default_value=bump;b1.inputs['Distance'].default_value=distance;l.new(noise.outputs['Fac'],b1.inputs['Height'])
        b2=n.new('ShaderNodeBump');b2.inputs['Strength'].default_value=.18;b2.inputs['Distance'].default_value=.007;l.new(fine.outputs['Fac'],b2.inputs['Height']);l.new(b1.outputs[0],b2.inputs['Normal']);l.new(b2.outputs[0],p.inputs['Normal'])
        return m

    def materials(self):
        self.mats['stone']=self.textured('Cream limestone masonry',(.25,.242,.19),(.48,.455,.35),3.6,.77,.2,.055)
        self.mats['stone_dark']=self.textured('Aged limestone undercut',(.105,.127,.102),(.225,.24,.19),4,.85,.25)
        self.mats['mortar']=self.textured('Warm deep mortar',(.055,.065,.045),(.12,.132,.098),10,.95,.2)
        self.mats['soil']=self.textured('Forest loam',(.035,.03,.016),(.09,.079,.04),5,.97,.4,.08)
        self.mats['joint_moss']=self.textured('Fine living moss in paving joints',(.035,.058,.009),(.12,.155,.025),24,.96,.3,.006)
        self.mats['bark']=self.textured('Weathered tree bark',(.033,.024,.013),(.17,.13,.064),4,.93,.38,.07)
        self.mats['brass']=self.textured('Antique bronze',(.21,.115,.025),(.48,.295,.067),7,.32,.08,.009)
        next(n for n in self.mats['brass'].node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Metallic'].default_value=.78
        self.mats['iron']=self.plain('Patinated dark iron',(.025,.032,.027),.42,.72)
        self.mats['gold']=self.plain('Warm ochre gold embroidery',(.51,.31,.072),.58,.24)
        self.mats['cloth']=self.textured('Woven forest green cloth',(.016,.052,.034),(.047,.14,.082),24,.91,.12,.008)
        for i in range(8):
            v=.82+i*.05
            self.mats['floor_'+str(i)]=self.textured('Floor sandstone variation '+str(i),(.22*v,.237*v,.211*v),(.39*v,.385*v,.326*v),2.8,.52+i*.018,.19,.029)
        for i,c in enumerate([(.045,.12,.012),(.093,.21,.022),(.16,.27,.037),(.055,.17,.023),(.22,.32,.047)]):
            m=self.textured('Living leaf variation '+str(i),tuple(x*.75 for x in c),c,18,.66,.1,.005)
            n=m.node_tree.nodes;l=m.node_tree.links;p=next(n for n in n if n.type=='BSDF_PRINCIPLED');out=next(n for n in n if n.type=='OUTPUT_MATERIAL')
            translucent=n.new('ShaderNodeBsdfTranslucent');translucent.inputs[0].default_value=(*c,1)
            mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=.18;l.new(p.outputs[0],mix.inputs[1]);l.new(translucent.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
            self.mats['leaf_'+str(i)]=m
        self.mats['flower_white']=self.plain('Ivory meadow petals',(.88,.81,.64),.64)
        self.mats['flower_purple']=self.plain('Lilac meadow petals',(.30,.115,.48),.58)
        self.mats['water']=self.plain('Clear turquoise springwater',(.09,.31,.285),.085)
        p=next(n for n in self.mats['water'].node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Transmission Weight'].default_value=.82;p.inputs['IOR'].default_value=1.333
        n=self.mats['water'].node_tree.nodes;l=self.mats['water'].node_tree.links;noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=4.8;noise.inputs['Detail'].default_value=3
        coord=n.new('ShaderNodeTexCoord');l.new(coord.outputs['Object'],noise.inputs['Vector']);b=n.new('ShaderNodeBump');b.inputs['Strength'].default_value=.18;b.inputs['Distance'].default_value=.032;l.new(noise.outputs['Fac'],b.inputs['Height']);l.new(b.outputs[0],p.inputs['Normal'])
        self.mats['lantern_glass']=self.plain('Lantern warm cream glass',(1,.61,.15),.3)
        p=next(n for n in self.mats['lantern_glass'].node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Emission Color'].default_value=(1,.48,.075,1);p.inputs['Emission Strength'].default_value=3.2
        self.mats['mosaic']=self.textured('Muted turquoise mosaic',(.085,.18,.17),(.20,.34,.295),7,.52,.11,.014)
        self.mats['forest_ground']=self.textured('Forest ground with living grass',(.08,.12,.03),(.20,.24,.065),3,.9,.15,.045)
        for key in ['stone','stone_dark']+['floor_'+str(i) for i in range(8)]:
            self.apply_pbr(self.mats[key],'worn_rock_natural_01',mix=.55 if key=='stone' else .53,saturation=.65,normal_strength=.65)
        self.apply_pbr(self.mats['forest_ground'],'leafy_grass',mix=.94,saturation=.7,normal_strength=.7)

    def apply_pbr(self,mat,asset,mix=.7,saturation=.55,normal_strength=.4):
        base=BASE/'shared/textures'/asset;n=mat.node_tree.nodes;l=mat.node_tree.links
        p=next(node for node in n if node.type=='BSDF_PRINCIPLED')
        coords=n.new('ShaderNodeTexCoord')
        def texture(suffix,non_color=False):
            path=base/f'{asset}_{suffix}_2k.jpg'
            assert path.is_file(),path
            im=bpy.data.images.load(str(path),check_existing=True)
            if non_color:
                try:im.colorspace_settings.name='Non-Color'
                except TypeError:pass
            node=n.new('ShaderNodeTexImage');node.image=im
            l.new(coords.outputs['UV'],node.inputs['Vector']);return node
        color=texture('diff');hsv=n.new('ShaderNodeHueSaturation');hsv.inputs['Saturation'].default_value=saturation
        l.new(color.outputs['Color'],hsv.inputs['Color'])
        original=p.inputs['Base Color'].links[0].from_socket if p.inputs['Base Color'].links else None
        blend=n.new('ShaderNodeMixRGB');enum(blend,'blend_type','MIX');blend.inputs[0].default_value=mix
        if original:l.new(original,blend.inputs[1])
        l.new(hsv.outputs['Color'],blend.inputs[2]);l.new(blend.outputs[0],p.inputs['Base Color'])
        rough=texture('rough',True);remap=n.new('ShaderNodeMapRange');remap.inputs['From Min'].default_value=0;remap.inputs['From Max'].default_value=1;remap.inputs['To Min'].default_value=.36;remap.inputs['To Max'].default_value=.79;l.new(rough.outputs['Color'],remap.inputs['Value']);l.new(remap.outputs['Result'],p.inputs['Roughness'])
        normal=texture('nor_gl',True);normalmap=n.new('ShaderNodeNormalMap');normalmap.inputs['Strength'].default_value=normal_strength;normalmap.uv_map='SurfaceUV_2m';l.new(normal.outputs['Color'],normalmap.inputs['Color'])
        # Preserve the stone's broad wear and fine grain on top of the scanned normal.
        bump_roots=[node for node in n if node.type=='BUMP' and not node.inputs['Normal'].is_linked]
        if bump_roots:l.new(normalmap.outputs['Normal'],bump_roots[0].inputs['Normal'])
        else:l.new(normalmap.outputs['Normal'],p.inputs['Normal'])
        mat['pbr_source']='Poly Haven / '+asset;mat['license']='CC0-1.0'

    def post(self,name,loc,height=2.3,width=.75):
        root=self.root(name,loc)
        profiles=[(.0,.15,1.4),(.15,.23,1.24),(.23,.32,1.08),(height-.28,height-.16,1.18),(height-.16,height,1.42)]
        for i,(a,b,s) in enumerate(profiles):self.box(name+'_mould_'+str(i),(0,0,(a+b)/2),(width*s,width*s,b-a),'stone',.025).parent=root
        lo=.32;hi=height-.28;levels=max(1,round((hi-lo)/.52))
        for i in range(levels):
            h=(hi-lo)/levels
            self.box(name+'_shaft_'+str(i),(0,0,lo+h*(i+.5)),(width,width,h-.014),'stone' if i%3 else 'stone_dark',.025).parent=root
        return root

    def arch(self,name,center=(0,0,0),width=4.2,spring=3.6,thickness=.55,depth=.7,angle=0):
        root=self.root(name,center);root.rotation_euler.z=angle
        r=width/2
        for side in [-1,1]:
            col=self.post(name+'_pier_'+str(side),(side*(r+thickness*.52),0,0),spring,thickness*1.12);col.parent=root
            self.box(name+'_spring_cap',(side*(r+thickness*.5),0,spring-.06),(thickness*1.52,depth*1.2,.22),'stone',.02).parent=root
        segments=15
        for j in range(segments):
            a=j*math.pi/segments+.006;b=(j+1)*math.pi/segments-.006
            outer=r+thickness*(1.08 if j==segments//2 else 1)
            verts=[(rr*math.cos(t),y,spring+rr*math.sin(t)) for y in [-depth/2,depth/2] for rr,t in [(r,a),(outer,a),(outer,b),(r,b)]]
            faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
            o=self.mesh(name+'_voussoir_'+str(j),verts,[tuple(reversed(f)) for f in faces],'stone');self.bevel(o,.018,2);o.parent=root
        # Carved outer archivolt follows the structural arch.
        for y in [-depth/2-.045,depth/2+.045]:
            pts=[((r+thickness*.86)*math.cos(t),y,spring+(r+thickness*.86)*math.sin(t)) for t in [math.pi*k/48 for k in range(49)]]
            self.curve(name+'_archivolt',pts,.037,'stone','Architecture').parent=root
        return root

    def balustrade(self,name,a,b,height=1.15):
        center=((a[0]+b[0])/2,(a[1]+b[1])/2,0);length=math.dist(a,b)
        root=self.root(name,center);root.rotation_euler.z=math.atan2(b[1]-a[1],b[0]-a[0])
        self.box(name+'_bottom',(0,0,.20),(length,.46,.4),'stone',.03).parent=root
        self.box(name+'_bottom_coping',(0,0,.43),(length+.08,.52,.09),'stone',.02).parent=root
        self.box(name+'_top_rail',(0,0,height-.08),(length+.1,.57,.16),'stone',.025).parent=root
        count=max(2,int(length/.52));h=height-.61
        for i in range(count):
            x=-length/2+(i+.5)*length/count
            profile=[(.12,0),(.12,.07),(.071,.13),(.087,h*.4),(.13,h*.57),(.09,h*.78),(.075,h-.06),(.125,h)]
            self.lathe(name+'_baluster_'+str(i),(x,0,.48),profile,'stone',12,'Architecture').parent=root
        return root

    def tile_floor(self,bounds=(-10,10,-8,8),step=(1.1,.85),z=0):
        x0,x1,y0,y1=bounds
        root=self.root('Flagstone_floor',group='Floor')
        self.box('Mortar subfloor',((x0+x1)/2,(y0+y1)/2,z-.12),(x1-x0,y1-y0,.18),'mortar',0,'Floor').parent=root
        ny=math.ceil((y1-y0)/step[1]);sy=(y1-y0)/ny
        moss_verts=[];moss_faces=[]
        for j in range(ny):
            nx=math.ceil((x1-x0)/step[0]);sx=(x1-x0)/nx;xx=x0
            while xx<x1-.01:
                span=sx*self.rng.choice([.74,1,1,1.24,1.47])
                if x1-(xx+span)<sx*.35:span=x1-xx
                l=max(xx,x0);r=min(xx+span,x1)
                if r-l>.06:
                    w=(r-l-.017)/2;h=(sy-.017)/2
                    c=[self.rng.uniform(.012,.052) for _ in range(4)]
                    outline=[(-w+c[0],-h),(w-c[1],-h),(w,-h+c[1]),(w,h-c[2]),(w-c[2],h),(-w+c[3],h),(-w,h-c[3]),(-w,-h+c[0])]
                    verts=[(x,y,-.17) for x,y in outline]+[(x,y,self.rng.uniform(-.002,.002)) for x,y in outline]+[(0,0,self.rng.uniform(-.003,.003))]
                    faces=[tuple(reversed(range(8)))]+[(k,(k+1)%8,8+(k+1)%8,8+k) for k in range(8)]+[(8+k,8+(k+1)%8,16) for k in range(8)]
                    o=self.mesh('Stone_slab_'+str(j)+'_'+str(round(xx,2)),verts,faces,self.rng.choice(['floor_'+str(i) for i in range(8)]),'Floor')
                    o.location=((l+r)/2,y0+(j+.5)*sy,z+.03+self.rng.uniform(-.002,.002));self.bevel(o,.009,2);o.parent=root
                    if self.rng.random()<.30:
                        # Low irregular moss grows along seams, never a raised gameplay obstacle.
                        corner=(l,y0+j*sy)
                        for axis in [0,1]:
                            reach=self.rng.uniform(.10,.36)
                            for k in range(5):
                                px=corner[0]+(reach*k/4 if axis==0 else 0)
                                py=corner[1]+(reach*k/4 if axis==1 else 0)
                                radius=self.rng.uniform(.015,.035);start=len(moss_verts)
                                for q in range(7):
                                    angle=q*math.tau/7;rr=radius*self.rng.uniform(.7,1.3)
                                    moss_verts.append((px+rr*math.cos(angle),py+rr*math.sin(angle),z+.036))
                                moss_faces.append(tuple(range(start,start+7)))
                xx+=span
        if moss_faces:self.mesh('Fine moss gathered in flagstone seams',moss_verts,moss_faces,'joint_moss','Floor').parent=root
        return root

    def stairs(self,name,center,width,run,rise,steps,angle=0):
        root=self.root(name,(center[0],center[1],center[2] if len(center)>2 else 0));root.rotation_euler.z=angle
        for i in range(steps):
            depth=run/steps;height=rise*(i+1)/steps
            self.box(name+'_step_'+str(i),(0,-run/2+(i+.5)*depth,height/2),(width,depth+.015,height),'stone',.025).parent=root
        return root

    def banner(self,name,loc,width=.85,height=2.0,angle=0):
        root=self.root(name,loc,'Decor');root.rotation_euler.z=angle
        verts=[];faces=[];cols=12;rows=18
        def surface(x,z):return -.035-.065*math.sin(x/width*math.pi*4)*(0.2-z/height)
        for j in range(rows+1):
            for i in range(cols+1):
                x=(i/cols-.5)*width;z=-j/rows*height
                if j==rows:z-=.15*(1-abs(x)/(width/2))
                verts.append((x,surface(x,z),z))
        for j in range(rows):
            for i in range(cols):
                a=j*(cols+1)+i;faces.append((a+cols+1,a+cols+2,a+1,a))
        cloth=self.mesh(name+'_cloth',verts,faces,'cloth','Decor');cloth.parent=root
        for p in cloth.data.polygons:p.use_smooth=True
        rod=self.cylinder(name+'_bronze_rod',(0,0,.04),.032,width*1.35,'brass',16);rod.rotation_euler.y=math.pi/2;rod.parent=root
        for x in [-width*.43,width*.43]:
            pts=[(x,surface(x,z)-.012,z) for z in [-height*k/25 for k in range(26)]];self.curve(name+'_embroidered_border',pts,.009,'gold').parent=root
        self.curve(name+'_botanical_stem',[(0,-.14,-height*.82),(-.035,-.14,-height*.5),(.02,-.14,-height*.20)],.011,'gold').parent=root
        for j in range(5):
            z=-height*(.76-j*.115)
            for side in [-1,1]:
                x=side*width*.17
                self.curve(name+'_gold_branch',[(0,-.146,z),(x,-.145,z+.12)],.008,'gold').parent=root
                v=[(x-side*.018,-.15,z+.07),(x+side*.09,-.15,z+.13),(x+side*.08,-.15,z+.27),(x-side*.045,-.15,z+.19)]
                self.mesh(name+'_gold_leaf',v,[(0,1,2,3)],'gold','Decor').parent=root
        return root

    def light(self,name,kind,loc,color,power,size=1,target=None):
        choices=[i.identifier for i in bpy.types.Light.bl_rna.properties['type'].enum_items]
        assert kind in choices
        data=bpy.data.lights.new(name,kind);data.color=color;data.energy=power
        if kind=='AREA':enum(data,'shape','DISK');data.size=size
        elif kind in ['POINT','SPOT']:data.shadow_soft_size=size
        obj=bpy.data.objects.new(name,data);self.collection('Lighting').objects.link(obj);obj.location=loc
        if target:obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
        return obj

    def lantern(self,name,loc,scale=1.0):
        root=self.root(name,loc,'Decor')
        for ob in [self.lathe(name+'_foot',(0,0,0),[(.21,0),(.22,.055),(.16,.095)],'brass',12),self.lathe(name+'_roof',(0,0,0),[(.25,.62),(.245,.68),(.07,.89),(.035,.92)],'brass',8),self.box(name+'_ivory_glass',(0,0,.36),(.25,.25,.49),'lantern_glass',.014,'Decor')]:ob.parent=root
        for x in [-.145,.145]:
            for y in [-.145,.145]:self.curve(name+'_cage',[(x,y,.095),(x*1.18,y*1.18,.39),(x,y,.65)],.017,'brass').parent=root
        for z in [.11,.62]:
            self.curve(name+'_rim',[(-.18,-.18,z),(.18,-.18,z),(.18,.18,z),(-.18,.18,z),(-.18,-.18,z)],.022,'brass').parent=root
        self.curve(name+'_handle',[(.07*math.cos(a),0,.965+.095*math.sin(a)) for a in [math.pi*2*i/24 for i in range(25)]],.012,'brass').parent=root
        lamp=self.light(name+'_warm_pool','POINT',(0,-.05,.38),(1,.57,.18),28,.16);lamp.parent=root
        root.scale=(scale,)*3;return root

    def medallion(self,center=(0,0),radius=2.5,z=.07,style='leaf'):
        root=self.root('Inlaid_'+style+'_medallion',(center[0],center[1],z),'Floor');segments=80
        for r0,r1,mat in [(radius*.91,radius,'mosaic' if style=='cloister' else 'stone'),(radius*.889,radius*.907,'brass'),(radius*.985,radius*.998,'brass')]:
            for j in range(segments):
                a=2*math.pi*j/segments+.003;b=2*math.pi*(j+1)/segments-.003
                v=[(r*math.cos(t),r*math.sin(t),.004) for r,t in [(r0,a),(r1,a),(r1,b),(r0,b)]]
                self.mesh('Mosaic ring tessera',v,[(0,1,2,3)],mat,'Floor').parent=root
        leaf_count=4 if style=='cloister' else 3
        if style=='cloister':
            for fraction in [.19,.43]:
                self.curve('Mosaic inner engraved gold ring',[(radius*fraction*math.cos(math.tau*k/96),radius*fraction*math.sin(math.tau*k/96),.012) for k in range(97)],.012,'brass','Floor').parent=root
            for i in range(4):
                a=math.pi/4+i*math.pi/2
                middle=Vector((radius*.82*math.cos(a),radius*.82*math.sin(a),.012))
                radial=Vector((math.cos(a),math.sin(a),0))*radius*.057
                across=Vector((-math.sin(a),math.cos(a),0))*radius*.028
                points=[middle+radial,middle+across,middle-radial,middle-across,middle+radial]
                self.curve('Mosaic four cardinal filigree lozenges',[tuple(p) for p in points],.018,'brass','Floor').parent=root
        for i in range(leaf_count):
            angle=math.pi*.5+2*math.pi*i/leaf_count
            p0=Vector((0,-.18*radius,0));tip=Vector((math.cos(angle)*radius*.66,math.sin(angle)*radius*.66,0))
            side=Vector((-(tip-p0).y,(tip-p0).x,0)).normalized()*radius*.17
            verts=[]
            for sign,steps in [(1,range(17)),(-1,range(16,-1,-1))]:
                for step in steps:
                    t=step/16;point=p0.lerp(tip,t)+side*(sign*math.sin(math.pi*t)**.8)
                    verts.append(tuple(point))
            if style=='cloister':self.mesh('Inset botanical mosaic',verts,[tuple(reversed(range(len(verts))))],'mosaic','Floor').parent=root
            self.curve('Mosaic brass leaf outline',[(*v[:2],.009) for v in verts+[verts[0]]],.016,'brass','Floor').parent=root
            self.curve('Mosaic midrib',[tuple(p0+Vector((0,0,.01))),tuple(tip+Vector((0,0,.01)))],.012,'brass','Floor').parent=root
        return root

    def water_surface(self,name,bounds,z=.04):
        x0,x1,y0,y1=bounds
        return self.mesh(name,[(x0,y0,z),(x1,y0,z),(x1,y1,z),(x0,y1,z)],[(0,1,2,3)],'water','Water')

    def finish(self,camera=(23,-32,29),target=(0,1.4,0),ortho=29,sun=(-10,-8,18),sun_energy=3,warmth=(1,.86,.65),volume=.004):
        s=self.scene
        sunobj=self.light('Sun through foliage','SUN',sun,warmth,sun_energy,target=(0,2,0));sunobj.data.angle=.055
        self.light('Open sky soft fill','AREA',(0,2,16),(.68,.79,1),900,18,(0,1,0))
        world=bpy.data.worlds.new('Cool blue open sky');world.use_nodes=True
        bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.25,.37,.52,1);bg.inputs['Strength'].default_value=.3;s.world=world
        if volume>0:
            m=bpy.data.materials.new('Very fine sunlit atmosphere');m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Density'].default_value=volume;v.inputs['Anisotropy'].default_value=.45;m.node_tree.links.new(v.outputs['Volume'],out.inputs['Volume'])
            self.box('Atmosphere bounds',(0,4,8),(65,65,22),m,0,'Atmosphere')
        data=bpy.data.cameras.new('Gameplay reference camera');cam=bpy.data.objects.new('Gameplay reference camera',data);self.collection('Cameras').objects.link(cam);cam.location=camera;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();enum(data,'type','ORTHO');data.ortho_scale=ortho;data.clip_end=250;s.camera=cam
        try:s.render.engine='CYCLES'
        except TypeError as error:raise RuntimeError('Cycles unavailable: '+str(error))
        s.cycles.samples=112;s.cycles.use_denoising=True;s.cycles.max_bounces=8;s.cycles.transparent_max_bounces=8
        pref=bpy.context.preferences.addons['cycles'].preferences
        try:
            # Device choices are runtime dynamic. Assign only when advertised.
            device_ids=[item[0] for item in pref.get_device_types(bpy.context)]
            if 'OPTIX' in device_ids:
                pref.compute_device_type='OPTIX';pref.refresh_devices()
                for dev in pref.devices:dev.use=dev.type=='OPTIX'
                enum(s.cycles,'device','GPU')
        except Exception as err:print('Device fallback to available renderer:',err,flush=True)
        s.render.resolution_x=1920;s.render.resolution_y=1080;s.render.resolution_percentage=100
        enum(s.render.image_settings,'file_format','PNG');enum(s.render.image_settings,'color_mode','RGBA');s.render.film_transparent=False;s.render.filepath=str(self.dir/'previews'/f'{self.room}_v001.png')
        s.view_settings.exposure=.45
        # AgX look names come from the bundled OCIO config; dynamic RNA lists
        # only NONE in background mode on Blender 5.2.
        ocio=Path(bpy.app.binary_path).parent/f'{bpy.app.version[0]}.{bpy.app.version[1]}'/'datafiles/colormanagement/config.ocio'
        look='AgX - Medium High Contrast'
        if ocio.is_file() and 'name: '+look in ocio.read_text(encoding='utf-8'):
            try:s.view_settings.look=look
            except TypeError as error:print('Color look retained:',error,flush=True)
        s['asset_status']='Editable Blender art scene. Not Godot imported or runtime optimized.'
        s['room_id']=self.room;s['reference']='../reference/'+self.room+'_target.png';s['art_seed']=self.seed;s['characters']=0
        s['replaceable_assets']='Objects in Replacement_Props are art proxies for later Tripo replacement.'
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type=='VIEW_3D':
                    enum(area.spaces.active.region_3d,'view_perspective','CAMERA');area.spaces.active.overlay.show_overlays=False
                    enum(area.spaces.active.shading,'type','MATERIAL')
        bpy.context.view_layer.update()
        # One movable anchor per replacement family, with all world transforms preserved.
        families={}
        for obj in list(self.collection('Replacement_Props').objects):
            if obj.get('replaceable'):
                key=obj.get('replacement_asset_id') or obj.get('replacement_family') or 'art_sculpture'
                families.setdefault(key,[]).append(obj)
        for family,objects in families.items():
            points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
            anchor=self.root('REPLACE_ANCHOR_'+family,((min(v.x for v in points)+max(v.x for v in points))/2,(min(v.y for v in points)+max(v.y for v in points))/2,min(v.z for v in points)),'Replacement_Props')
            anchor['replacement_family']=family;anchor['usage']='Replace children while preserving this anchor transform.'
            bpy.context.view_layer.update()
            original_world={o.name:o.matrix_world.copy() for o in objects}
            for o in objects:
                matrix=o.matrix_world.copy();o.parent=anchor;o.matrix_parent_inverse=anchor.matrix_world.inverted();o.matrix_world=matrix
            bpy.context.view_layer.update()
            # A replacement handle must never displace the sculptural parts.
            for o in objects:
                assert all(math.isfinite(x) for row in o.matrix_world for x in row)
                assert max(abs(o.matrix_world[i][j]-original_world[o.name][i][j]) for i in range(4) for j in range(4))<.0001, 'Anchor displaced '+o.name
        report={'scene':s.name,'room_id':self.room,'blender_version':bpy.app.version_string,'objects':len(s.objects),'mesh_objects':sum(o.type=='MESH' for o in s.objects),'base_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in s.objects if o.type=='MESH'),'materials':len(bpy.data.materials),'lights':sum(o.type=='LIGHT' for o in s.objects),'collections':[c.name for c in s.collection.children],'camera':list(camera),'target':list(target),'ortho_scale':ortho,'render_size':[1920,1080],'godot_validated':False,'source_images':[],'replaceable_objects':[o.name for o in s.objects if o.get('replaceable')],'all_generated_geometry':True}
        (self.dir/'reports'/f'{self.room}_build_v001.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        bpy.ops.file.pack_all()
        report['packed_texture_images']=[im.name for im in bpy.data.images if im.packed_file]
        report['pbr_sources']=['Poly Haven worn_rock_natural_01','Poly Haven leafy_grass']
        report['unpacked_texture_images']=[im.name for im in bpy.data.images if im.source=='FILE' and im.size[0] and not im.packed_file]
        (self.dir/'reports'/f'{self.room}_build_v001.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        filepath=self.dir/'blender'/f'{self.room}_art_v001.blend'
        bpy.ops.wm.save_as_mainfile(filepath=str(filepath))
        print('BUILD_COMPLETE '+str(filepath),flush=True)
        return filepath
