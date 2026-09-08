"""Adapt selected role performances to Actor's exact timing and atlas contract."""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'kits/big-sheets'
outputs=[]

def read(path): return json.loads(path.read_text(encoding='utf-8'))
def emit(folder,name,character,age,texture,cell,anchor,frames,clips,density,source):
    texture=texture.resolve()
    im=Image.open(texture).convert('RGBA')
    for frame in frames:
        x,y,w,h=frame['atlas_rect']
        assert x>=0 and y>=0 and x+w<=im.width and y+h<=im.height
        assert im.crop((x,y,x+w,y+h)).getbbox()
    for clip in clips.values():
        assert len(clip['frames'])==len(clip['durations'])
        assert all(math.isfinite(t) and t>0 for t in clip['durations'])
        assert all(0<=n<len(frames) for n in clip['frames'])
    # Actor always starts with idle, even for a performance-only preview spec.
    if 'idle' not in clips:
        clips['idle']={'frames':[0],'durations':[1.0],'fps':1,'loop':False,'admitted':False}
    out=folder/'integration';out.mkdir(exist_ok=True)
    target=out/(name+'.json')
    spec={'schema_version':1,'character_id':character,'age':age,
      'runtime_admitted':False,'usage':'selected_performance_review',
      'texture':'res://'+texture.relative_to(ROOT).as_posix(),
      'texture_sha256':hashlib.sha256(texture.read_bytes()).hexdigest(),
      'cell':cell,'anchor':anchor,'pixels_per_world_unit':density,
      'directional':False,'default_facing':'southeast','frames':frames,'clips':clips,
      'source_metadata':source.relative_to(ROOT).as_posix(),
      'source_metadata_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
      'note':'Exact selected source frames and authored timing; review scale is provisional. No art admission or gameplay change.'}
    target.write_text(json.dumps(spec,indent=2)+'\n',encoding='utf-8')
    outputs.append(target.relative_to(ROOT).as_posix())

folder=BASE/'ada-v1/selected-loops';source=folder/'actor-spec.json';m=read(source)
clips={}
for name,c in m['clips'].items():
    clips[name]={'frames':c['frames'],'durations':c.get('durations',[1/c['fps']]*len(c['frames'])),
                 'fps':c['fps'],'loop':c['loop'],'admitted':False}
emit(folder,'ada','ada_mercer',22,ROOT/m['texture'].removeprefix('res://'),m['cell'],m['anchor'],m['frames'],clips,4,source)

folder=BASE/'eleanor-v1/selected-loops'
for source in sorted(folder.glob('*/metadata.json')):
    m=read(source);frames=[]
    for f in m['frames']:
        frames.append({'index':f['index'],'atlas_rect':f.get('atlas_rect',f.get('atlas_rect_xywh'))})
    clips={name:{'frames':c['frames'],'durations':c['durations_seconds'],'fps':1,
                 'loop':c['loop'],'admitted':False} for name,c in m['clips'].items()}
    emit(folder,source.parent.name,'eleanor',24,source.parent/m['texture'],m['cell'],m['anchor'],frames,clips,4,source)

folder=BASE/'ines-v1/selected-loops';source=folder/'metadata.json';m=read(source)
for name,c in m['clips'].items():
    frames=[{'index':f['index'],'atlas_rect':f['atlas_rect_xywh']} for f in c['frames']]
    clips={name:{'frames':list(range(len(frames))),'durations':[f['duration_ms']/1000 for f in c['frames']],
                 'fps':1,'loop':c['loop'],'admitted':False}}
    emit(folder,name,'ines_vale',23,folder/c['texture'],m['cell'],m['anchor'],frames,clips,6,source)
(BASE/'role-actor-specs.json').write_text(json.dumps({'runtime_admitted':False,'specs':outputs},indent=2)+'\n',encoding='utf-8')
print(f'ROLE SPECS: {len(outputs)} engine-compatible review packages with validated frame bounds and exact authored holds')
