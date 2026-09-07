from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, math
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'kits/manifest.json').read_text())
families=manifest['families']
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',18)
small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',14)
out=Image.new('RGB',(1440,100+math.ceil(len(families)/3)*300),'#222820')
d=ImageDraw.Draw(out)
d.text((24,18),'CATTLE TRAIL / 496 EXTRACTED SPRITE CANDIDATES',font=font,fill='#efd7a3')
d.text((24,50),'13 families | Actual transparent atlas pixels | Motion and visual acceptance pending',font=small,fill='#c8c8a7')
for n,(name,spec) in enumerate(families.items()):
    x=(n%3)*480;y=100+(n//3)*300
    d.rectangle((x+8,y+4,x+472,y+292),fill='#697344')
    d.text((x+20,y+14),f"{name.upper()} / {spec['count']} frames",font=font,fill='#fff0ce')
    atlas=Image.open(root/spec['texture'].replace('res://','')).convert('RGBA')
    indices=[round(i*(spec['count']-1)/7) for i in range(8)]
    for k,i in enumerate(indices):
        xx,yy,w,h=spec['frames'][i]['atlas_rect']
        tile=atlas.crop((xx,yy,xx+w,yy+h)); tile=tile.crop(tile.getbbox())
        scale=2 if tile.width<=50 and tile.height<=50 else 1
        tile=tile.resize((tile.width*scale,tile.height*scale),Image.Resampling.NEAREST)
        px=x+20+(k%4)*112+(100-tile.width)//2
        py=y+50+(k//4)*116+108-tile.height
        out.paste(tile,(px,py),tile)
out.save(root/'kits/overview.png')
