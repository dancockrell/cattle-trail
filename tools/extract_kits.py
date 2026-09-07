"""Extract genuine sprites from individually generated 4x4 rich-kit sheets.
All source pixels preserved; key removal and nearest sampling only.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage
from sprite_grid import extract_cells
import json, hashlib, math

ROOT=Path(__file__).resolve().parents[1]
KIT=ROOT/'kits'
OUT=KIT/'atlases'; OUT.mkdir(exist_ok=True)
REV=KIT/'reviews'; REV.mkdir(exist_ok=True)
JOBS=json.loads((KIT/'generation-jobs.json').read_text())
JOBS += [{'id':f,'family':f,'ref':2} for f in ['grass','trees']]
replaced={j['replace_id'] for j in JOBS if j.get('replace_id') and (KIT/'source'/f"{j['id']}.png").exists()}
JOBS=[j for j in JOBS if j['id'] not in replaced]
COLORS=(112,119,62)
CELL={'rider':(96,96),'longhorn':(72,64),'cream':(72,64),'spotted':(72,64),'eleanor':(64,64),'rustler':(64,64),'wagon':(112,96),'grass':(64,48),'trees':(128,128),'rocks':(80,64),'scrub':(80,80),'fence':(96,80),'camp':(80,80)}
TARGET={'rider':62,'longhorn':38,'cream':38,'spotted':38,'eleanor':40,'rustler':40,'wagon':58,'grass':30,'trees':100,'rocks':42,'scrub':50,'fence':50,'camp':48}
ACTIONS={'rider':['walk','trot','lasso','shoot'],'longhorn':['walk','run','graze','rest'],'cream':['walk','run','graze','rest'],'spotted':['walk','run','graze','rest'],'eleanor':['walk','talk','medical','camp'],'rustler':['walk','run','shoot','react']}
catalog={'schema_version':1,'status':'extracted_candidates_pending_visual_acceptance','source_method':'built-in image_gen, original Cattle Trail references','processing':'binary magenta key; trim; uniform per-sheet nearest reduction; bottom center anchor','families':{},'rejections':[{'source':'rider-v1.png','reason':'Dense pilot: baked checkerboard, wrong grid count, fused lasso subjects. Not counted.'}]}

def separators(projection):
    """Locate the actual empty gutters, not the generator's promised grid coordinates."""
    length=len(projection); cuts=[0]
    smooth=np.convolve(projection,np.ones(5),mode='same')
    for i in range(1,4):
        ideal=length*i/4; lo=round(ideal-length*.10); hi=round(ideal+length*.10)
        minimum=smooth[lo:hi].min()
        valid=np.flatnonzero(smooth[lo:hi]<=minimum+1)+lo
        runs=np.split(valid,np.where(np.diff(valid)>1)[0]+1)
        # Favor a broad genuinely empty corridor close to the expected partition.
        run=min(runs,key=lambda r: abs(float(np.mean(r))-ideal)-min(len(r),60)*.7)
        cuts.append(round(float(np.mean(run))))
    return cuts+[length]
groups={}
for rejected in sorted(replaced):
    replacement=next(j for j in JOBS if j.get('replace_id')==rejected)
    catalog['rejections'].append({'source':rejected+'.png','reason':replacement.get('replacement_reason','Wrong facing; replaced by v2. Preserved, excluded from count.')})
for job in JOBS:
    source=KIT/'source'/job.get('source_file',f"{job['id']}.png")
    if not source.exists(): continue
    im=Image.open(source).convert('RGBA')
    cells, grid = extract_cells(im,job.get('columns',4),job.get('rows',4))
    items=[]
    for trim,record in zip(cells,grid['cells']):
        row=record['row']; col=record['column']
        if 'selected_rows' in job and row not in job['selected_rows']: continue
        items.append({'image':trim,'source_rect':record['source_rect'],'trim':record['trim_rect_in_cell'],'row':row,'col':col})
    family=job['family']
    # Actor scale follows body height in the walk row; tool effects don't shrink the body.
    heights=[p['image'].height for p in (items[:4] if family in ACTIONS else items)]
    denom=float(np.median(heights)) if family in ACTIONS else max(heights)
    factor=TARGET[family]/denom
    cell=CELL[family]
    # One scale across all cells avoids per-pose stretching.
    factor=min(factor,min((cell[0]-8)/p['image'].width for p in items),min((cell[1]-6)/p['image'].height for p in items))
    for p in items:
        p['image']=p['image'].resize((max(1,round(p['image'].width*factor)),max(1,round(p['image'].height*factor))),Image.Resampling.NEAREST)
        p.update({'source':f"kits/source/{source.name}",'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'direction':job.get('direction','none'),'scale':factor,'job':job['id']})
        if 'row_directions' in job: p['direction']=job['row_directions'][p['row']]
        if 'column_directions' in job: p['direction']=job['column_directions'][p['col']]
        if family in ACTIONS: p['action']=job.get('actions',ACTIONS[family])[p['row']]
        if 'clip_prefix' in job: p['clip_prefix']=job['clip_prefix']
    groups.setdefault(family,[]).extend(items)

for family,items in groups.items():
    cell=CELL[family]; columns=8 if len(items)>16 else 4
    rows=math.ceil(len(items)/columns)
    atlas=Image.new('RGBA',(columns*cell[0],rows*cell[1]))
    spec={'texture':f'res://kits/atlases/{family}.png','cell':cell,'anchor':[cell[0]//2,cell[1]-3],'frames':[],'clips':{},'status':'extracted_candidate','count':len(items),'world_body_height':TARGET[family]}
    for i,p in enumerate(items):
        x=i%columns*cell[0]; y=i//columns*cell[1]
        offset=((cell[0]-p['image'].width)//2,cell[1]-3-p['image'].height)
        atlas.paste(p['image'],(x+offset[0],y+offset[1]))
        record={k:v for k,v in p.items() if k!='image'}
        record.update({'atlas_rect':[x,y,*cell],'anchor':spec['anchor'],'id':f'{family}_{i:03d}'})
        spec['frames'].append(record)
        if family in ACTIONS:
            action=p['action']
            clip=p.get('clip_prefix','')+f"{action}_{p['direction']}"
            spec['clips'].setdefault(clip,{'frames':[],'fps':7 if action in ('walk','trot','run') else 5,'loop':action not in ('shoot','react','medical','rest')})['frames'].append(i)
        else:
            spec['clips'][f'variant_{i:02d}']={'frames':[i],'fps':1,'loop':True}
    if family in ACTIONS:
        for direction in sorted(set(p['direction'] for p in items)):
            walk=spec['clips'].get('walk_'+direction)
            if walk and 'idle_'+direction not in spec['clips']: spec['clips']['idle_'+direction]={'frames':[walk['frames'][0]],'fps':1,'loop':True}
    atlas.save(OUT/f'{family}.png')
    spec['review_notes']=['Candidate poses; timing, silhouette consistency, foot contacts and attachment continuity require motion curation.']
    if family in ('longhorn','cream','spotted'):
        spec['review_notes'].append('North sheets turn toward the camera in some graze/rest poses. Direction labels record requested generation, not verified action coverage.')
    if family=='eleanor':
        spec['review_notes'].append('Medical bag hand and attachment position vary; curate before production animation.')
    if family in ('fence','grass'):
        spec['review_notes'].append('Decorative variants; seamless connections/autotile rules have not been authored or verified.')
    if family=='trees':
        # Exact complementary image layers: their alpha union recreates the original tree.
        # They enable foreground canopy sorting without inventing unseen trunk artwork.
        canopy=Image.new('RGBA',atlas.size); trunk=Image.new('RGBA',atlas.size)
        for frame in spec['frames']:
            x,y,w,h=frame['atlas_rect']
            tile=atlas.crop((x,y,x+w,y+h)); box=tile.getbbox()
            split=box[1]+round((box[3]-box[1])*.65)
            canopy.paste(tile.crop((0,0,w,split)),(x,y))
            trunk.paste(tile.crop((0,split,w,h)),(x,y+split))
            frame['canopy_split_y']=split
        canopy.save(OUT/'trees-canopy.png'); trunk.save(OUT/'trees-trunk.png')
        spec['layers']={'canopy':'res://kits/atlases/trees-canopy.png','trunk':'res://kits/atlases/trees-trunk.png','same_regions_and_anchors':True,'method':'complementary horizontal split at65% silhouette height; no hidden trunk pixels invented','counted_as_new_variants':False}
    # Keep atlas alpha proof on muted terrain at integer2x for close visual review.
    review=Image.new('RGB',(atlas.width,atlas.height),COLORS); review.paste(atlas,(0,0),atlas)
    review.resize((review.width*2,review.height*2),Image.Resampling.NEAREST).save(REV/f'{family}.png')
    catalog['families'][family]=spec
catalog['total_extracted']=sum(v['count'] for v in catalog['families'].values())
(KIT/'manifest.json').write_text(json.dumps(catalog,indent=2)+'\n')
print(json.dumps({'total':catalog['total_extracted'],'families':{k:v['count'] for k,v in catalog['families'].items()}},indent=2))
