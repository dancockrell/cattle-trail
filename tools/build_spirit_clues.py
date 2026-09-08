"""Select three complete static clue sprites, without admitting unfinished loops."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'kits/big-sheets/spirit-effects-v1'
m=json.loads((FOLDER/'metadata.json').read_text(encoding='utf-8'))
source=Image.open(FOLDER/'atlas.png').convert('RGBA')
atlas=Image.new('RGBA',(768,256));clues={}
for ordinal,(name,index) in enumerate([('bell_tracks',2),('cold_ashes',8),('wrong_shadow',16)]):
    f=m['frames'][index];x,y,w,h=f['atlas_rect']
    cell=source.crop((x,y,x+w,y+h))
    assert cell.size==(256,256) and cell.getbbox()
    assert set(cell.getchannel('A').get_flattened_data())<={0,255}
    atlas.paste(cell,(ordinal*256,0))
    clues[name]={'region':[ordinal*256,0,256,256],'source_frame':index,
        'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest()}
target=ROOT/'assets/spirit-clues.png';atlas.save(target)
doc={'schema_version':1,'status':'static_clue_room_review','texture':'res://assets/spirit-clues.png',
     'cell':[256,256],'anchor':[128,128],'pixels_per_world_unit':8,'clues':clues,
     'source_atlas':'kits/big-sheets/spirit-effects-v1/atlas.png',
     'source_sha256':hashlib.sha256((FOLDER/'atlas.png').read_bytes()).hexdigest(),
     'texture_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
     'review':'Three complete recognizable static silhouettes inspected. Exact extracted source pixels; no scaling, painting or animation-loop admission.'}
(ROOT/'assets/spirit-clues.json').write_text(json.dumps(doc,indent=2)+'\n',encoding='utf-8')
print('SPIRIT CLUES: exact bell, cold embers and crow shadow selected; binary alpha and source rectangles verified')
