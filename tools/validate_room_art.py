from pathlib import Path
import json,hashlib
from PIL import Image
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'assets/room-art.json').read_text())
count=0
for name,spec in manifest['sprites'].items():
    texture=Image.open(root/spec['texture'].replace('res://',''))
    used=set()
    for clip,data in spec['clips'].items():
        if 'durations' in data:
            assert len(data['durations'])==len(data['frames'])
            assert all(isinstance(t,(float,int)) and t>0 for t in data['durations'])
        used.update(data['frames'])
        for index in data['frames']:
            x,y,w,h=spec['frames'][index]['atlas_rect']
            assert 0<=x<x+w<=texture.width and 0<=y<y+h<=texture.height
        if clip in spec.get('clip_anchors',{}):
            ax,ay=spec['clip_anchors'][clip]
            assert 0<=ax<w and 0<=ay<h
        if clip in spec.get('action_events',{}):
            event=spec['action_events'][clip]
            assert 0<=event['frame']<len(data['frames'])
            assert event['once_per_action']
    count+=len(used)
    for index,sockets in spec.get('frame_sockets',{}).items():
        x,y,w,h=spec['frames'][int(index)]['atlas_rect']
        for point in sockets.values(): assert 0<=point[0]<w and 0<=point[1]<h
assert count==manifest['integrated_unique_actor_frames']
ground=manifest['ground']
assert hashlib.sha256((root/ground['source']).read_bytes()).hexdigest()==ground['sha256']
assert Image.open(root/ground['texture'].replace('res://','')).size==tuple(ground['output_dimensions'])
print(f'ROOM ART PASS: {count} selected actor frames; clip anchors and event indices valid; terrain source verified')
