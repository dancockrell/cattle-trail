from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parent
ROWS={1:['walk_SE','walk_E','walk_NE_intended','walk_N'],2:['turn_clockwise','turn_counterclockwise','pivot_SE_NE','pivot_SW_NW'],3:['spirit_listen','examine_clue','ring_bell','guide_fireflies'],4:['greet','laugh','explain_trail','invite','sit_down','drink','reassure','stretch']}
for number in range(1,5):
    folder=ROOT/f'sheet{number:02d}'
    source=Image.open(folder/'source.png')
    rgba=np.array(source.convert('RGBA')); rgb=rgba[:,:,:3].astype(int)
    original_alpha=rgba[:,:,3].copy()
    actual_alpha=bool(np.any(original_alpha<255))
    if not actual_alpha:
        neutral=(rgb.max(2)-rgb.min(2)<16)&(rgb.min(2)>140)
        labels,count=ndimage.label(neutral)
        sizes=np.bincount(labels.ravel()); remove=sizes>=12; remove[0]=False
        rgba[:,:,3][remove[labels]]=0
    clean=Image.fromarray(rgba)
    clean.save(folder/'transparent-source.png')
    atlas=Image.new('RGBA',(2560,1280))
    frames=[]; native=folder/'frames';native.mkdir(exist_ok=True)
    w,h=source.size
    for row in range(4):
        y0=round(row*h/4);y1=round((row+1)*h/4)
        mask=rgba[y0:y1,:,3]>0
        labels,count=ndimage.label(mask)
        objects=ndimage.find_objects(labels)
        big=[]
        for label,region in enumerate(objects,1):
            if region and np.count_nonzero(labels[region]==label)>700:
                big.append((region[1].start,region[1].stop))
        big.sort()
        borders=[0]+[round((big[c-1][1]+big[c][0])/2) for c in range(1,8)]+[w] if len(big)==8 else [round(c*w/8) for c in range(9)]
        for col in range(8):
            i=row*8+col;x0,x1=borders[col:col+2]
            tile=clean.crop((x0,y0,x1,y1));bbox=tile.getbbox()
            assert bbox
            figure=tile.crop(bbox)
            assert figure.width<=320 and figure.height<=300,(number,i,figure.size)
            figure.save(native/f'{i:02d}.png')
            position=(col*320+160-figure.width//2,row*320+304-figure.height)
            atlas.paste(figure,position)
            frames.append({'index':i,'source_crop_xywh':[x0+bbox[0],y0+bbox[1],figure.width,figure.height],'atlas_rect_xywh':[col*320,row*320,320,320],'anchor':[160,304],'native_sha256':hashlib.sha256(figure.tobytes()).hexdigest()})
    atlas.save(folder/'atlas.png')
    clips={}
    length=4 if number==4 else 8
    for index,name in enumerate(ROWS[number]):
        order=list(range(index*length,(index+1)*length))
        clips[name]={'frames':order,'frame_duration_ms':125,'loop':False,'status':'review_only','recovery_note':'Reuse suitable existing return frames through metadata; never generate padding.'}
    notes={1:'Walking source repeats leading leg in several rows; NE row faces toward viewer rather than away. Not a complete directional gait.',2:'Standing rotations contain useful back views; some adjacent poses near-duplicate and pivots incomplete. Review and select real facings before assigning clips.',3:'Spirit actions visibly vary; listening/return poses similar. Bell shape and firefly count vary. Review timing and continuity.',4:'Eight four-pose actions, no generated return padding requested. Clothing drift persists: reference-like teal bodice and cream sleeves instead of strictly single-color blouse. Review before runtime.'}
    meta={'character':'ines_vale','age':23,'sheet':number,'source':'source.png','texture':'atlas.png','source_size':list(source.size),'source_mode':source.mode,'source_sha256':hashlib.sha256((folder/'source.png').read_bytes()).hexdigest(),'requested_alpha':True,'actual_source_alpha':actual_alpha,'transparency_method':'preserve source alpha' if actual_alpha else 'Generated RGB checkerboard; neutral components >=12 pixels keyed, retaining source RGB. No repaint or scale.','cell':[320,320],'anchor':[160,304],'frames':frames,'clips':clips,'runtime_admitted':False,'review_notes':notes[number]}
    (folder/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(number,source.size,source.mode,'frames',len(frames),'hashes',len(set(f['native_sha256'] for f in frames)))
(ROOT/'README.md').write_text('# Ines large production kit v2\n\nFour separately generated full sheets; 128 source cells. Exact prompts and originals retained per sheet. Builtin imagegen used, one call per sheet, no retries. Transparency was requested initially but returned images painted checkerboards; extraction preserves native pixels and keys neutral background components.\n\nSheet 4 follows the latest four distinct phases per action rule: eight actions, no generated return padding. Earlier sheets were already generated before that correction. Review metadata records actual limitations; distinct pixel hashes do not prove distinct motion. All clips remain review-only; the walk is not a complete alternating gait.\n')
