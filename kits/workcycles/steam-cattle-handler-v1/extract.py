from pathlib import Path
import sys, json, hashlib
from PIL import Image, ImageDraw
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from sprite_grid import extract_cells
source = ROOT / 'kits/source/steam-cattle-handler-v1.png'
image = Image.open(source)
crops, grid = extract_cells(image, 2, 2, min_component_pixels=1)
states = ['idle', 'stalled', 'repaired', 'walking_passing']
scale = 48 / crops[0].height
atlas = Image.new('RGBA', (384, 96))
review = Image.new('RGB', (1152, 320), '#625e3c')
draw = ImageDraw.Draw(review)
records = []
for i, (crop, state) in enumerate(zip(crops, states)):
    size = (round(crop.width * scale), round(crop.height * scale))
    offset = ((96-size[0])//2, 93-size[1])
    cell = Image.new('RGBA', (96,96))
    cell.paste(crop.resize(size, Image.Resampling.NEAREST), offset)
    assert set(cell.getchannel('A').tobytes()) == {0,255}
    bounds = cell.getbbox()
    assert bounds and 0 < bounds[0] < bounds[2] < 96 and 0 < bounds[1] < bounds[3] < 96
    crop.save(HERE / (state + '-trim.png'))
    cell.save(HERE / (state + '.png'))
    atlas.paste(cell, (96*i,0))
    enlarged = cell.resize((288,288), Image.Resampling.NEAREST)
    review.paste(enlarged,(i*288,0),enlarged)
    draw.text((i*288+12,298), state + ' / SW', fill='white')
    records.append({'index':i,'state':state,'actual_direction':'southwest','atlas_rect':[96*i,0,96,96],
                    'anchor':[48,93], 'cell_offset':list(offset),'scaled_size':list(size),
                    'source_cell':grid['cells'][i], 'alpha_bounds_xyxy':list(bounds),
                    'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest()})
atlas.save(HERE/'atlas.png')
review.save(HERE/'contact-sheet.png')
metadata = {'schema_version':1,'status':'whole_pose_candidate_not_runtime_admitted',
 'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'prompt':'kits/source/steam-cattle-handler-v1-prompt.txt','source_size':list(image.size),
 'cell':[96,96],'anchor':[48,93],'body_height_idle':48,'scale':scale,
 'texture':'atlas.png','frames':records,
 'clips':{state:{'frames':[i],'fps':1,'loop':True,'presentation':'static whole state hold'} for i,state in enumerate(states)},
 'processing':{'whole_sprite_only':True,'key':'binary magenta cleanup','resampling':'nearest','grid':grid},
 'inspection':{'identity':'Consistent compact brass-banded iron boiler, four jointed legs, front wood bumper and bell.',
 'direction':'Requested NE, generated front bumper faces SW; retain actual SW labeling.',
 'states':'Idle planted; stalled has valve-attached ivory steam; repaired amber pilot; passing raises front-left visible foot.',
 'limitations':['Four whole state candidates, not a full walking cycle.','Repaired and passing top valve/pilot differ; no seamless animation claim.','No NE-facing admission.']}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
print('STEAM HANDLER PASS: four binary RGBA whole cells96x96, anchor48,93, idle48px; actual SW')
