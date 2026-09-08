"""Extract complete native cells; preserve unexpected baked checkerboard source."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy.ndimage import binary_propagation
from PIL import Image
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
source=HERE/'source.png'
image=Image.open(source).convert('RGBA')
a=np.array(image)
rgb=a[:,:,:3].astype(int)
# The generator baked its transparency checkerboard into RGB. Remove only the
# bright neutral field connected to the outer boundary, leaving enclosed details.
eligible=(rgb.max(2)-rgb.min(2)<35)&(rgb.mean(2)>140)
seed=np.zeros(eligible.shape,dtype=bool)
seed[0,:]=eligible[0,:];seed[-1,:]=eligible[-1,:]
seed[:,0]=eligible[:,0];seed[:,-1]=eligible[:,-1]
background=binary_propagation(seed,mask=eligible)
a[background]=0
clean=Image.fromarray(a)
clean.save(HERE/'source-keyed.png')
rows=[0,190,365,555,747,925,1122]
atlas=Image.new('RGBA',(256*8,256*6))
records=[]
groups=['se_walk','ne_walk','east_walk','direction_stands','spirit_tracking','talk_emotes']
for i in range(48):
    row,col=divmod(i,8)
    box=(round(col*image.width/8),rows[row],round((col+1)*image.width/8),rows[row+1])
    cell=clean.crop(box)
    cell.save(HERE/f'cell-{i:02d}-native.png')
    bounds=cell.getbbox()
    assert bounds,'Empty source cell'
    figure=cell.crop(bounds)
    figure.save(HERE/f'figure-{i:02d}-native.png')
    # Preserve exact source pixels and actual motion height; no per-frame resize.
    frame=Image.new('RGBA',(256,256))
    x=128-figure.width//2;y=244-figure.height
    assert x>=0 and y>=0
    frame.paste(figure,(x,y))
    atlas.paste(frame,(col*256,row*256))
    records.append({'index':i,'requested_group':groups[row],'requested_group_ordinal':col,'source_rect_xyxy':list(box),'native_cell':f'cell-{i:02d}-native.png','native_figure':f'figure-{i:02d}-native.png','trim_bounds_xyxy':list(bounds),'atlas_rect_xywh':[col*256,row*256,256,256],'anchor':[128,244],'native_figure_size':list(figure.size),'edge_warning':bounds[0]==0 or bounds[1]==0 or bounds[2]==cell.width or bounds[3]==cell.height,'status':'candidate_unverified_phase','duration_ms':None})
atlas.save(HERE/'atlas.png')
ref=ROOT/'kits/wardrobe/ines-high-angle-v1/source.png'
metadata={'schema_version':1,'id':'ines-v1','character':'Ines Vale','age':23,'source':'source.png','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'reference':'kits/wardrobe/ines-high-angle-v1/source.png','reference_sha256':hashlib.sha256(ref.read_bytes()).hexdigest(),'prompt':'prompt.txt','requested_size':[3840,3072],'actual_size':list(image.size),'requested_grid':[8,6],'observed_figure_count':48,'source_transparency':'RGB with baked checkerboard; not true generated alpha','extraction':'Boundary-connected bright-neutral checkerboard removal, native whole-cell crops and whole-figure trims, no rescaling or anatomy assembly; atlas alignment is static preview only, not measured animation registration.','cell':[256,256],'anchor':[128,244],'texture':'atlas.png','frames':records,'animations':{},'runtime_admitted':False,'tool':'builtin image_gen','model':'not exposed','date':'2026-09-08','review':'48 intact-looking subjects visible. Walking rows repeat leading-leg shapes; phase alternation unverified. Direction row includes several ambiguous facings. Spirit and social rows add distinct gesture silhouettes. Lower-than-requested resolution and keyed checkerboard require final extraction inspection.'}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('INES BIG SHEET:48 native cells/figures extracted; edge warnings',sum(r['edge_warning'] for r in records))
