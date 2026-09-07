"""Select inspected source frames for the bounded room; no new art synthesis."""
from pathlib import Path
import json,copy
root=Path(__file__).resolve().parents[1]
kit=json.loads((root/'kits/manifest.json').read_text())
original=json.loads((root/'assets/sprites.json').read_text())
out={'schema_version':1,'status':'integrated_room_review','source_catalog':'kits/manifest.json','sprites':{},'scenery':[],'excluded':'Cattle graze/rest turns; Eleanor medical/camp bag changes; rustler reaction strips; unverified environment connections.'}
for name in ['rider','longhorn','cream','spotted','eleanor','rustler']:
    spec=copy.deepcopy(kit['families'][name]); spec['clips']={}
    source=kit['families'][name]['clips']
    directions=['east','west','north','south']
    for direction in directions:
        for action in ['idle','walk']:
            spec['clips'][action+'_'+direction]=copy.deepcopy(source[action+'_'+direction])
    if name=='rider':
        for direction in directions:
            for action in ['lasso','shoot']:
                clip=copy.deepcopy(source[action+'_'+direction]);clip['loop']=False;clip['fps']=10 if action=='shoot' else 8
                spec['clips'][action+'_'+direction]=clip
    if name=='eleanor':
        # Two standing hand gestures keep the bag out of the animation.
        spec['clips']['talk_east']={'frames':[4,5,4,5],'fps':3,'loop':False}
    spec['clips']['idle']=copy.deepcopy(spec['clips']['idle_east'])
    spec['status']='selected_for_room_review'
    spec['selection_note']='Walk and stationary facing reviewed together; action strips selectively enabled. Final room acceptance is separate.'
    out['sprites'][name]=spec
out['sprites']['wagon']=copy.deepcopy(original['sprites']['wagon'])
def add(family,index,x,y,solid=0):
    spec=kit['families'][family]
    out['scenery'].append({'family':family,'frame':index,'texture':spec['texture'],'region':spec['frames'][index]['atlas_rect'],'anchor':spec['anchor'],'position':[x,y],'collision_radius':solid,'source_frame_id':spec['frames'][index]['id']})
for item in [(1,40,93),(6,280,79),(5,436,70),(2,611,104),(0,363,62)]:add('trees',*item,solid=9)
for item in [(0,32,276),(3,603,288),(9,437,302),(14,163,303),(1,360,103)]:add('rocks',*item,solid=6)
for item in [(0,50,323),(2,205,93),(4,464,303),(8,578,317),(12,322,315)]:add('scrub',*item)
for item in [(0,64,139),(4,51,119),(9,108,148),(7,125,139),(12,49,163)]:add('camp',*item)
for i,(x,y) in enumerate([(76,285),(123,304),(216,305),(255,318),(346,292),(398,313),(522,297),(565,277),(598,121),(410,96),(315,109),(169,97),(234,72),(462,91),(542,95),(37,205),(611,223),(90,185),(446,267),(194,278)]):
    add('grass',[0,1,3,4,5,8,9,10,12,13][i%10],x,y)
out['integrated_unique_actor_frames']=sum(len({i for c in s['clips'].values() for i in c['frames']}) for s in out['sprites'].values())
out['integrated_unique_scenery_frames']=len({(s['family'],s['frame']) for s in out['scenery']})
(root/'assets/room-art.json').write_text(json.dumps(out,indent=2)+'\n')
print('Room selection:',out['integrated_unique_actor_frames'],'actor frames;',out['integrated_unique_scenery_frames'],'scenery variants;',len(out['scenery']),'placements')
