"""Extract source pixels for controlled gait comparisons; no runtime admission."""
from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image
from sprite_grid import extract_cells
root=Path(__file__).resolve().parents[1]
atlas=Image.new('RGBA',(768,384)); frames=[]
for version in ['v5','v6','v7','v8']:
    source=root/f'kits/source/rider-ne-walk-sequence-{version}.png'
    cells,metadata=extract_cells(Image.open(source),4,2)
    factor=62/float(np.median([im.height for im in cells[:4]]))
    factor=min(factor,min(88/im.width for im in cells),min(90/im.height for im in cells))
    for cell,record in zip(cells,metadata['cells']):
        tile=cell.resize((round(cell.width*factor),round(cell.height*factor)),Image.Resampling.NEAREST)
        index=len(frames); x=index%8*96; y=index//8*96
        atlas.paste(tile,(x+(96-tile.width)//2,y+93-tile.height))
        frames.append({'atlas_rect':[x,y,96,96],'source':str(source.relative_to(root)).replace('\\','/'),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'crop':record['source_trim_rect'],'scale':factor})
atlas.save(root/'assets/stride-trial.png')
variants={}
for name,indices in {'v5':[0,1,2,3,4,5,6,7],'v6_row':[8,9,10,11,12,13,14,15],'v6_curated':[8,9,10,11,12,15,14,13],'v7_row':list(range(16,24)),'v8_row':list(range(24,32))}.items():
    variants[name]={'texture':'res://assets/stride-trial.png','anchor':[47,93],'default_facing':'northeast','frames':frames,'clips':{'idle':{'frames':[indices[0]],'fps':1,'loop':True},'idle_northeast':{'frames':[indices[0]],'fps':1,'loop':True},'walk_east':{'frames':indices,'fps':8.3333333333,'loop':True},'walk_northeast':{'frames':indices,'fps':8.3333333333,'loop':True}},'locomotion':{'nominal_speed':72},'status':'comparison_only_not_selected_gameplay'}
(root/'assets/stride-trial.json').write_text(json.dumps({'status':'diagnostic_only','trial_speed':18.75,'cycle_seconds':0.96,'variants':variants},indent=2)+'\n')
print('Built five diagnostic variants from 32 source cells; runtime selection unchanged')
