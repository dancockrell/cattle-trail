from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
from scipy.ndimage import binary_propagation,label,find_objects
BASE=Path(__file__).resolve().parent
groups=[['walk_se','walk_e','walk_ne','walk_n'],['turn_clockwise','turn_counterclockwise','pivot','crouch'],['calm','lasso','shoot','bandage'],['wave','laugh','drink','point','listen','shy_smile','sit','compass']]
for s in range(1,5):
    home=BASE/f'sheet{s:02d}'
    source=Image.open(home/'source.png').convert('RGBA')
    full=np.array(source); rgb=full[:,:,:3].astype(int)
    bg=(rgb.max(2)-rgb.min(2)<24)&(rgb.min(2)>160)
    seeds=np.zeros(bg.shape,bool);seeds[0]=bg[0];seeds[-1]=bg[-1];seeds[:,0]=bg[:,0];seeds[:,-1]=bg[:,-1]
    full[:,:,3]=np.where(binary_propagation(seeds,mask=bg),0,255)
    labels,_=label(full[:,:,3]>0)
    components=[(j+1,b) for j,b in enumerate(find_objects(labels)) if b and (b[0].stop-b[0].start)*(b[1].stop-b[1].start)>4000]
    assert len(components)==32,len(components)
    components.sort(key=lambda item:(item[1][0].start+item[1][0].stop)/2)
    components=[item for row in range(4) for item in sorted(components[row*8:row*8+8],key=lambda item:item[1][1].start)]
    atlas=Image.new('RGBA',(320*8,320*4)); frames=[]
    for i in range(32):
        component,b=components[i];y0,y1=b[0].start,b[0].stop;x0,x1=b[1].start,b[1].stop
        a=full[y0:y1,x0:x1].copy();a[:,:,3]=np.where(labels[y0:y1,x0:x1]==component,255,0)
        cut=Image.fromarray(a); box=cut.getbbox(); assert box
        trim=cut.crop(box); trim.save(home/f'{i:02d}-native.png')
        assert trim.width<320 and trim.height<308
        cell=Image.new('RGBA',(320,320));offset=[160-trim.width//2,308-trim.height]
        cell.alpha_composite(trim,tuple(offset));cell.save(home/f'{i:02d}-whole-frame.png')
        ax,ay=i%8*320,i//8*320;atlas.alpha_composite(cell,(ax,ay))
        action=groups[s-1][i//(4 if s==4 else 8)]
        frames.append({'index':i,'requested_row':action,'source_rect':[x0+box[0],y0+box[1],trim.width,trim.height],
            'atlas_rect':[ax,ay,320,320],'offset':offset,'anchor':[160,308],
            'touches_grid_boundary':False,'extraction':'whole connected figure outside artificial grid boundaries',
            'native_sha256':hashlib.sha256((home/f'{i:02d}-native.png').read_bytes()).hexdigest()})
    atlas.save(home/'atlas.png')
    width=4 if s==4 else 8
    actions=[{'name':name,'frames':list(range(n*width,(n+1)*width)),'runtime_admitted':False} for n,name in enumerate(groups[s-1])]
    m={'version':1,'source':'source.png','source_sha256':hashlib.sha256((home/'source.png').read_bytes()).hexdigest(),
       'atlas':'atlas.png','cell':[320,320],'anchor':[160,308],'frames':frames,'actions':actions,
       'runtime_admitted':False,'alpha':'Source RGB painted checker; border-connected neutral key, binary alpha.',
       'processing':'Native whole connected figures, no rescale or drawing; bottom alignment for review only.',
       'limitations':['Detached effects and motion marks omitted; no seamless loop inferred from cell count.',
           'Enclosed checker pixels may remain.','Walk repeats leading leg; shoot pose 21 has an unwanted second revolver.']}
    (home/'metadata.json').write_text(json.dumps(m,indent=2)+'\n')
    print(home.name,len(frames),'cells;',sum(f['touches_grid_boundary'] for f in frames),'boundary flags')
