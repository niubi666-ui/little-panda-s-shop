"""Author scalable UI ornaments/icons and a native Godot Theme. No reference-image slicing."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'game/presentation/foliage'
OUT.mkdir(parents=True, exist_ok=True)
ART = ROOT / 'game/assets/ui/foliage'
ART.mkdir(parents=True, exist_ok=True)

defs = '''<defs><linearGradient id="gold" x2="0.7" y2="1"><stop stop-color="#fff0b8"/><stop offset=".45" stop-color="#c6a15e"/><stop offset="1" stop-color="#71552e"/></linearGradient><linearGradient id="leaf" x2="1" y2="1"><stop stop-color="#b4bc73"/><stop offset="1" stop-color="#344b2e"/></linearGradient><linearGradient id="red" x2=".8" y2="1"><stop stop-color="#ea9775"/><stop offset=".5" stop-color="#ad3b3e"/><stop offset="1" stop-color="#541f27"/></linearGradient><linearGradient id="blue" x2="1" y2="1"><stop stop-color="#bdecea"/><stop offset=".5" stop-color="#438eb2"/><stop offset="1" stop-color="#283b78"/></linearGradient><linearGradient id="wood" x2="0" y2="1"><stop stop-color="#caa577"/><stop offset="1" stop-color="#5f3925"/></linearGradient></defs>'''
shapes = {
'leaf': '<path d="M29 103 Q34 58 100 21 Q103 93 40 98" fill="url(#leaf)"/><path d="M22 110 Q49 72 99 24 M47 78L49 49 M60 65L86 68 M74 50L76 33" fill="none"/>',
'potion': '<path d="M49 27V49C14 69 26 112 64 113S114 69 79 49V27" fill="#315057"/><path d="M37 70Q64 78 91 70C102 109 27 120 37 70" fill="url(#red)"/><rect x="45" y="16" width="38" height="20" rx="5" fill="url(#wood)"/><path d="M43 59Q30 74 39 91" stroke="#f8deb1" stroke-width="5" fill="none"/><path d="M60 47L85 62L76 80L53 65Z" fill="#d9c494"/>',
'crystal': '<path d="M34 35L71 13L102 46L82 108L43 114L21 79Z" fill="url(#blue)"/><path d="M34 35L59 57L71 13M59 57L102 46M59 57L43 114M59 57L82 108M21 79L59 57" fill="none" stroke="#b3dbdc"/>',
'sword': '<path d="M88 14L107 15L108 35L55 88L39 72Z" fill="url(#blue)"/><path d="M44 84L20 109L30 119L56 93" fill="url(#wood)"/><path d="M28 65L69 103L77 93L39 55Z" fill="url(#gold)"/><path d="M51 77L99 25" stroke="#fff2d1"/>',
'bag': '<path d="M43 27Q31 3 62 18Q92 3 85 27L75 44Q113 57 108 94Q104 116 63 113Q14 115 21 81Q24 61 51 44Z" fill="url(#wood)"/><path d="M43 35Q63 42 83 34M49 45Q64 51 77 43M54 49L47 80M71 50L78 82" fill="none"/><path d="M53 76L75 76L75 93L53 93Z" fill="url(#gold)"/>',
'scroll': '<path d="M29 21H94L85 97H37Z" fill="#dfca98"/><path d="M29 21Q9 18 12 35H82Q78 16 94 21Q105 23 103 35M37 97Q16 96 21 111H94Q79 104 85 97" fill="url(#gold)"/><path d="M40 51H79M39 63H74M37 75H69" fill="none" stroke="#66563b"/>',
'cabinet': '<rect x="22" y="16" width="85" height="98" rx="4" fill="url(#wood)"/><path d="M32 25H96V103H32ZM30 64H97M62 68V100" fill="none"/><path d="M39 33V58H51V33ZM63 30V58H77V30ZM82 38V58H89V38Z" fill="#516342"/><circle cx="55" cy="81" r="3"/><circle cx="69" cy="81" r="3"/>',
'chest': '<path d="M16 59Q16 28 41 28H91Q113 30 114 59V105H16Z" fill="url(#wood)"/><path d="M16 59H114M36 31V105M94 31V105" stroke="url(#gold)" stroke-width="7" fill="none"/><rect x="54" y="57" width="22" height="25" rx="3" fill="url(#gold)"/><circle cx="65" cy="66" r="3" fill="#3a3023"/>',
'lamp': '<path d="M53 24Q50 5 65 8Q80 8 77 24M40 33H90L103 49H27ZM35 51H95V105H35ZM30 109H100" fill="url(#gold)"/><path d="M42 56H88V99H42Z" fill="#c48643"/><path d="M65 61Q48 81 55 92Q76 108 77 85Z" fill="#fff0b3"/><path d="M65 52V104" fill="none"/>',
'rug': '<path d="M17 33L94 17L115 95L38 114Z" fill="url(#red)"/><path d="M28 41L88 28L103 88L45 102ZM52 54L76 49L89 78L65 88Z" fill="none" stroke="url(#gold)"/><path d="M15 38L8 40M17 48L10 50M20 58L13 60M23 69L16 71M26 79L19 81M29 89L22 91M32 99L25 101" stroke="#c6a15e"/>',
'coin': '<circle cx="64" cy="64" r="47" fill="url(#gold)"/><circle cx="64" cy="64" r="37" fill="#9e733b"/><path d="M47 84Q47 44 86 35Q88 77 51 80M40 93L85 37" fill="url(#gold)"/>',
'settings': '<path d="M52 16H77L80 32L94 39L108 34L119 55L105 68L105 81L114 94L96 112L81 101L66 104L57 118L33 109L35 91L26 79L10 76L11 51L28 46L37 34L37 20Z" fill="url(#gold)"/><circle cx="64" cy="67" r="24" fill="#173329"/><circle cx="64" cy="67" r="12" fill="url(#gold)"/>',
}
for name, shape in shapes.items():
    (ART / (name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{defs}<g stroke="#b69a62" stroke-width="2" stroke-linejoin="round">{shape}</g></svg>', encoding='utf-8')
leaves = ''.join(f'<g transform="translate({x} {y}) rotate({angle})"><path d="M0 0Q-24-28-8-44Q17-29 0 0" fill="url(#leaf)" stroke="#a8a56a" stroke-width="1"/><path d="M0 0L-8-38" fill="none" stroke="#d5c991" stroke-width=".8"/></g>' for x,y,angle in [(20,102,-35),(28,82,42),(37,65,-25),(52,46,50),(72,30,-5),(100,20,70)])
(ART/'corner.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="150" height="130" viewBox="0 0 150 130">{defs}<path d="M10 123Q24 31 125 13" stroke="#bfa366" fill="none" stroke-width="2"/>{leaves}</svg>',encoding='utf-8')

styles = {
'panel': ('0.035,0.085,0.064,0.97','0.58,0.46,0.26,1',1,18),
'normal': ('0.057,0.12,0.083,1','0.58,0.46,0.26,1',1,12),
'hover': ('0.12,0.23,0.13,1','0.98,0.8,0.41,1',2,12),
'pressed': ('0.12,0.10,0.057,1','0.87,0.68,0.32,1',2,12),
'disabled': ('0.08,0.105,0.087,1','0.29,0.32,0.26,1',1,12),
'focus': ('0,0,0,0','1,0.87,0.53,1',2,12),
'paper': ('0.79,0.71,0.52,1','0.50,0.39,0.22,1',2,20),
}
lines=['[gd_resource type="Theme" load_steps=14 format=3]','']
for name in styles:
    if name != 'focus':
        lines += [f'[ext_resource type="Texture2D" path="res://assets/ui/foliage/frame_{name}.svg" id="{name}"]']
# Font resources and sizes are authored separately in ui_typography.tres.

for name,(bg,border,width,pad) in styles.items():
    if name == 'focus':
        lines += [f'[sub_resource type="StyleBoxFlat" id="{name}"]','bg_color = Color(0,0,0,0)',f'border_color = Color({border})']
        for side in ['left','right','top','bottom']:
            lines += [f'border_width_{side} = 2',f'expand_margin_{side} = 2.0']
    else:
        rgb = lambda value: '#'+''.join(f'{int(float(c)*255):02x}' for c in value.split(',')[:3])
        fill, stroke = rgb(bg), rgb(border)
        edge = '#efd5a0' if name not in ('disabled','paper') else stroke
        ornaments=''.join(f'<g transform="translate({x},{y}) scale({sx},{sy})"><path d="M9 27Q11 11 27 9M12 22Q23 23 23 12M16 16L20 20M12 12L16 12L12 16Z" fill="none" stroke="{stroke}" stroke-width="1"/></g>' for x,y,sx,sy in [(0,0,1,1),(512,0,-1,1),(0,256,1,-1),(512,256,-1,-1)])
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="256"><defs><linearGradient id="shade" x2="0" y2="1"><stop stop-color="{fill}"/><stop offset="1" stop-color="{fill}" stop-opacity=".94"/></linearGradient></defs><path d="M14 3H498L509 14V242L498 253H14L3 242V14Z" fill="url(#shade)" stroke="{stroke}" stroke-width="3"/><path d="M16 7H496L505 16V240L496 249H16L7 240V16Z" fill="none" stroke="{edge}" stroke-width=".8"/>{ornaments}</svg>'
        (ART/f'frame_{name}.svg').write_text(svg,encoding='utf-8')
        lines += [f'[sub_resource type="StyleBoxTexture" id="{name}"]',f'texture = ExtResource("{name}")']
        for side in ['left','right','top','bottom']:
            lines += [f'texture_margin_{side} = 28.0',f'content_margin_{side} = {pad}.0']
    lines += ['']
lines += ['[resource]','Label/colors/font_color = Color(0.96,0.9,0.73,1)','Button/colors/font_color = Color(0.96,0.9,0.73,1)','Button/colors/font_hover_color = Color(1,0.96,0.79,1)','Button/colors/font_pressed_color = Color(1,0.89,0.57,1)','Button/colors/font_disabled_color = Color(0.49,0.53,0.43,1)','Button/constants/outline_size = 0','PanelContainer/styles/panel = SubResource("panel")','Paper/base_type = &"PanelContainer"','Paper/styles/panel = SubResource("paper")','PaperLabel/base_type = &"Label"','PaperLabel/colors/font_color = Color(0.14,0.16,0.10,1)','Title/base_type = &"Label"','Muted/base_type = &"Label"','Muted/colors/font_color = Color(0.64,0.67,0.51,1)','HBoxContainer/constants/separation = 12','VBoxContainer/constants/separation = 12','GridContainer/constants/h_separation = 10','GridContainer/constants/v_separation = 10']
for name in ['normal','hover','pressed','disabled','focus']:
    lines += [f'Button/styles/{name} = SubResource("{name}")']
for name,value in {'margin':20,'window_width':1000,'window_height':590,'slot':94,'icon':64,'catalog_icon':48,'detail_width':258,'columns':5,'preview_rows':3,'decoration_columns':2,'sidebar_width':385,'footer_height':106,'header_height':76,'corner_size':72,'dialog_icon':110}.items():
    lines += [f'Foliage/constants/{name} = {value}']
(OUT/'foliage_theme.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Foliage Theme and 13 scalable art assets authored.')
