"""Extract authored northern turn poses and compare them with existing whole-sprite endpoints."""
from pathlib import Path
import json
import hashlib
from PIL import Image, ImageDraw, ImageFont
from sprite_grid import extract_cells

root = Path(__file__).resolve().parents[1]
source = root / 'kits/source/rider-northern-turn-v1.png'
out = root / 'kits/workcycles/rider-northern-turn-v1'
out.mkdir(parents=True, exist_ok=True)
tiles, grid = extract_cells(Image.open(source).convert('RGBA'), 4, 1)
scale = 62 / max(tile.height for tile in tiles)
atlas = Image.new('RGBA', (384,96))
frames = []
for index, (tile, crop) in enumerate(zip(tiles,grid['cells'])):
    resized = tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.NEAREST)
    cell = Image.new('RGBA',(96,96))
    offset = ((96-resized.width)//2,93-resized.height)
    cell.paste(resized,offset)
    cell.save(out/f'frame-{index:02}.png')
    atlas.paste(cell,(index*96,0))
    frames.append({'index':index,'file':f'frame-{index:02}.png','source':'kits/source/'+source.name,
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_rect':crop['source_rect'],
        'trim':crop['trim_rect_in_cell'],'scale':scale,'offset':list(offset),'anchor':[48,93],
        'atlas_rect':[index*96,0,96,96],
        'heading':['north-northwest','north-northeast','north-northwest','north-northeast'][index],
        'pose':'grounded' if index<2 else 'passing'})
atlas.save(out/'atlas.png')
metadata={'schema_version':1,'runtime_admitted':False,'cell':[96,96],'anchor':[48,93],
    'atlas':'atlas.png','frames':frames,'processing':'Whole-pose crop, binary magenta key, common scale, nearest sampling; no limb edits.',
    'transition_duration_seconds':0.09,'timing_status':'provisional',
    'comparison_order':['northwest','north-northwest','north','north-northeast','northeast']}
(out/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')

catalog=json.loads((root/'kits/manifest.json').read_text())['families']['rider']
room=json.loads((root/'assets/room-art.json').read_text())['sprites']['rider']
original=Image.open(root/catalog['texture'].replace('res://','')).convert('RGBA')
comparison=Image.new('RGB',(5*288,330),(101,111,60))
draw=ImageDraw.Draw(comparison)
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',18)
for column,(label,index,new) in enumerate([('NW',163,False),('NNW',0,True),('N',187,False),('NNE',1,True),('NE',155,False)]):
    if new:
        cell=Image.open(out/f'frame-{index:02}.png').convert('RGBA'); anchor=[48,93]
    else:
        x,y,w,h=catalog['frames'][index]['atlas_rect']
        cell=original.crop((x,y,x+w,y+h))
        direction={'NW':'northwest','N':'north','NE':'northeast'}[label]
        anchor=room['clip_anchors']['idle_'+direction]
    visible=cell.resize((288,288),Image.Resampling.NEAREST)
    comparison.paste(visible,(column*288+(48-anchor[0])*3,36+(93-anchor[1])*3),visible)
    draw.text((column*288+10,9),label+' / '+('new turn pose' if new else 'existing idle'),font=font,fill=(249,235,200))
comparison.save(out/'endpoint-sheet.png')
print('Produced four turn cells and five-heading endpoint sheet; no runtime selection changed.')
