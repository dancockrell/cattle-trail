"""Preserve32 whole candidate cells per additional generated sheet, native scale."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy.ndimage import binary_propagation,label
from PIL import Image
HERE=Path(__file__).resolve().parent
CONFIG={2:([0,236,464,684,912],['walk_nw','walk_n','walk_ne','walk_w']),3:([0,232,463,691,913],['run_e','run_se','run_s','run_sw']),4:([0,242,476,690,913],['idle_breathing','spirit_tracking','lantern_walk','talk_gesture'])}
for number,(rows,groups) in CONFIG.items():
    folder=HERE/f'sheet{number:02d}'
    source=folder/'source.png'
    image=Image.open(source).convert('RGBA')
    a=np.array(image);rgb=a[:,:,:3].astype(int)
    eligible=(rgb.max(2)-rgb.min(2)<35)&(rgb.mean(2)>140)
    seed=np.zeros(eligible.shape,dtype=bool)
    seed[0,:]=eligible[0,:];seed[-1,:]=eligible[-1,:];seed[:,0]=eligible[:,0];seed[:,-1]=eligible[:,-1]
    bg=binary_propagation(seed,mask=eligible);a[bg]=0
    clean=Image.fromarray(a);clean.save(folder/'source-keyed.png')
    # Raw grid cells retained without resizing. Largest human + meaningful detached
    # effects retained; remove isolated sub3px checker debris only in atlas derivative.
    atlas=Image.new('RGBA',(2048,1024));records=[]
    for i in range(32):
        row,col=divmod(i,8)
        box=(round(col*image.width/8),rows[row],round((col+1)*image.width/8),rows[row+1])
        cell=clean.crop(box);cell.save(folder/f'cell-{i:02d}-native.png')
        ca=np.array(cell);components,count=label(ca[:,:,3]>0)
        sizes=np.bincount(components.ravel());tiny=(sizes<3);tiny[0]=False
        ca[tiny[components]]=0;cell=Image.fromarray(ca)
        bounds=cell.getbbox();assert bounds
        figure=cell.crop(bounds);figure.save(folder/f'figure-{i:02d}-native.png')
        assert figure.width<256 and figure.height<=244
        frame=Image.new('RGBA',(256,256));frame.paste(figure,(128-figure.width//2,244-figure.height));atlas.paste(frame,(col*256,row*256))
        records.append({'index':i,'requested_group':groups[row],'requested_group_ordinal':col,'source_rect_xyxy':list(box),'trim_bounds_xyxy':list(bounds),'native_cell':f'cell-{i:02d}-native.png','native_figure':f'figure-{i:02d}-native.png','native_figure_size':list(figure.size),'atlas_rect_xywh':[col*256,row*256,256,256],'anchor':[128,244],'edge_warning':bounds[0]==0 or bounds[1]==0 or bounds[2]==cell.width or bounds[3]==cell.height,'status':'candidate_unverified_phase','duration_ms':None})
    atlas.save(folder/'atlas.png')
    metadata={'schema_version':1,'id':f'ines-sheet{number:02d}','character':'Ines Vale','age':23,'source':'source.png','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'actual_size':list(image.size),'requested_size':[3840,2048],'requested_grid':[8,4],'observed_figure_count':32,'reference':'kits/wardrobe/ines-high-angle-v1/source.png','prompt':'prompt.txt','tool':'builtin image_gen','model':'not exposed','date':'2026-09-08','texture':'atlas.png','cell':[256,256],'anchor':[128,244],'frames':records,'animations':{},'runtime_admitted':False,'source_transparency':'RGB with baked checkerboard, removed by boundary-connected bright neutral key; raw source preserved','transform':'Whole native grid cells, complete figure trims, no rescale or duplicated padding; isolated sub3pixel background debris removed for atlas. Per-frame centering is preview alignment, not animation registration.','review':'Requested row actions are metadata intent, not verified complete cycles. Leading-leg repetitions, body/costume drift and incomplete gutters remain possible. No source pixels duplicated to increase frame counts.'}
    (folder/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(f'INES SHEET{number}:32 native cells extracted; {sum(x["edge_warning"] for x in records)} edge warnings')
