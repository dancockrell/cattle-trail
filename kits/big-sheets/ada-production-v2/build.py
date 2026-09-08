"""Whole-cell keying and registration; never paints or reconstructs a figure."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parent
NAMES=[['walk_se','walk_e','walk_ne','walk_n'],['turn_clockwise','scan_turn','wrench_pivot','look_back_turn'],['kneel_repair','tighten_wrench','hammer','inspect_watch'],['greeting','laugh','drink','offer_cup','sit_down','stand_up','talk','listen']]
NOTES=[
 'Repeated leading leg persists; rear facings present but opposing gait contacts not approved. These are retained production frames, not a completed walk.',
 'Distinct full-body compass poses present. Rows 2 and 4 intended counterclockwise order requires authored reordering; source order is retained. Foot registration and turn continuity need review.',
 'Distinct repair, hammer and watch stages present. Tool shape and neutral return vary; full action continuity pending review.',
 'Eight four-phase actions. Drink first pose has no cup and offer final pose loses cup; do not claim prop continuity. Sitting and standing stages are distinct. No duplicate padding was added.'
]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
bundle=[]
for sheet in range(1,5):
    prefix=f'sheet{sheet:02}'
    src=ROOT/f'{prefix}-source.png'; im=Image.open(src).convert('RGB')
    native=ROOT/f'{prefix}-native'; native.mkdir(exist_ok=True)
    atlas=Image.new('RGBA',(2048,1024))
    frames=[]
    for idx in range(32):
        row,col=divmod(idx,8)
        rect=[round(col*im.width/8),round(row*im.height/4),round((col+1)*im.width/8),round((row+1)*im.height/4)]
        rgb=np.array(im.crop(rect)); signed=rgb.astype(np.int16)
        # Only neutral light background connected to cell edges is keyed. This
        # preserves enclosed ivory fabric and steel tools rather than global key.
        candidate=(signed.max(2)-signed.min(2)<28)&(signed.min(2)>155)
        labels,count=ndimage.label(candidate)
        edge=np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]))
        edge=edge[edge!=0]
        background=np.isin(labels,edge)
        rgba=np.dstack([rgb,np.where(background,0,255).astype(np.uint8)])
        cut=Image.fromarray(rgba); path=native/f'{idx:02}.png';cut.save(path)
        # Shared cell-space registration, no bbox recentering, no resizing.
        offset=(17,22); cell=Image.new('RGBA',(256,256));cell.alpha_composite(cut,offset)
        atlas.alpha_composite(cell,(col*256,row*256))
        frames.append({'index':idx,'row':row,'column':col,'source_rect_xywh':[rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1]],'atlas_rect_xywh':[col*256,row*256,256,256],'native_file':str(path.relative_to(ROOT)).replace('\\','/'),'native_sha256':sha(path),'alpha_bbox':list(cell.getbbox()) if cell.getbbox() else None,'anchor':[128,244]})
    target=ROOT/f'{prefix}-atlas.png';atlas.save(target)
    clips=[]
    for action,name in enumerate(NAMES[sheet-1]):
        length=4 if sheet==4 else 8
        ids=list(range(action*length,(action+1)*length))
        clips.append({'name':name,'source_frame_indices':ids,'intended_phase_count':length,'duration_ms_per_frame':125,'runtime_admitted':False,'status':'review_candidate','loop':False,'return_playback':'metadata may reverse suitable gestures; never duplicate artwork to fill a row'})
    meta={'version':1,'character':'ada_mercer','age':22,'sheet':sheet,'source_file':src.name,'source_sha256':sha(src),'source_mode':'RGB','source_size':list(im.size),'prompt_file':f'{prefix}-prompt.txt','texture':target.name,'atlas_size':[2048,1024],'cell_size':[256,256],'columns':8,'rows':4,'frame_count':32,'pixels_per_world_unit':6,'anchor':[128,244],'native_scale':1,'runtime_admitted':False,'status':'production_review','alpha_observation':'Built-in request explicitly asked for real transparency; output is RGB with painted checkerboard. Border-connected light neutral pixels keyed to binary alpha; enclosed checker remnants may remain. Surviving RGB preserved exactly.','review_notes':NOTES[sheet-1],'frames':frames,'clips':clips}
    (ROOT/f'{prefix}-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
    bundle.append({'metadata':f'{prefix}-metadata.json','source':src.name,'atlas':target.name,'frame_count':32})
(ROOT/'bundle.json').write_text(json.dumps({'character':'ada_mercer','age':22,'sheets':bundle,'source_cells':128,'runtime_admitted':False,'generation':'four built-in imagegen calls; no regeneration','wardrobe':'ivory tucked sleeveless blouse, one pair full-length brown trousers, boots, simple belt','review_boundary':'128 source cells are not 128 approved poses or finished loops. Variable action lengths; no duplicate padding added.'},indent=2)+'\n')
print('Built four transparent native atlases; 128 whole-cell extractions retained.')
