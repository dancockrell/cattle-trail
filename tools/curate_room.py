"""Select inspected source frames for the bounded room; no new art synthesis."""
from pathlib import Path
import json,copy,hashlib
from PIL import Image
root=Path(__file__).resolve().parents[1]
kit=json.loads((root/'kits/manifest.json').read_text())
original=json.loads((root/'assets/sprites.json').read_text())
out={'schema_version':1,'status':'integrated_room_review','source_catalog':'kits/manifest.json','sprites':{},'scenery':[],'excluded':'Cattle graze/rest turns; Eleanor medical/camp bag changes; rustler reaction strips; unverified environment connections.'}
ground_path=root/'source/ground-v3.png'
if ground_path.exists():
    ground=Image.open(ground_path).convert('RGB')
    ground.resize((640,360),Image.Resampling.NEAREST).save(root/'assets/ground-v3.png')
    out['ground']={'texture':'res://assets/ground-v3.png','source':'source/ground-v3.png','sha256':hashlib.sha256(ground_path.read_bytes()).hexdigest(),'source_dimensions':list(ground.size),'output_dimensions':[640,360],'sampling':'nearest','provenance':'Quieter clustered empty-ground derivative generated from approved source/concept-start.jpg; prompt in source/ground-v3-prompt.txt'}
for name in ['rider','longhorn','cream','spotted','eleanor','rustler']:
    spec=copy.deepcopy(kit['families'][name]); spec['clips']={}
    source=kit['families'][name]['clips']
    directions=['east','west','north','south']
    if name in ['rider','longhorn','cream','spotted']: directions += [d for d in ['northeast','northwest','southeast','southwest'] if 'walk_'+d in source]
    for direction in directions:
        for action in ['idle','walk']:
            clip_name=action+'_'+direction
            source_name='v4_'+clip_name if 'v4_'+clip_name in source else clip_name
            spec['clips'][clip_name]=copy.deepcopy(source[source_name])
            if action=='idle': spec['clips'][action+'_'+direction]['fps']=3
    if name=='rider':
        alignment=json.loads((root/'assets/rider-anchors.json').read_text())
        spec['clip_anchors']={clip:data['anchor'] for clip,data in alignment['clips'].items()}
        for clip in spec['clips']:
            if 'v4_'+clip in alignment['clips']: spec['clip_anchors'][clip]=alignment['clips']['v4_'+clip]['anchor']
        spec['anchor_policy']=alignment['method']
        spec['action_events']={}
        for direction in directions:
            for action in ['lasso','shoot']:
                clip=copy.deepcopy(source[action+'_'+direction]);clip['loop']=False;clip['fps']=10 if action=='shoot' else 8
                spec['clips'][action+'_'+direction]=clip
                if action=='lasso' and direction in ['northwest','southeast']:
                    # Exclude the candidate's wrong-side extension; hold its correctly facing overhead loop.
                    f=clip['frames'];clip['frames']=[f[0],f[1],f[1],f[3]]
                spec['action_events'][action+'_'+direction]={'name':'fire' if action=='shoot' else 'rope_release','frame':(0 if direction=='north' else 1) if action=='shoot' else 2,'basis':'Visible muzzle flash for shoot; extended loop pose for lasso','once_per_action':True}
                if action=='lasso' and direction in ['northwest','southeast']:
                    spec['action_events'][action+'_'+direction]['basis']='Release during held overhead loop; wrong-side source extension excluded'
    if name=='eleanor':
        # Two standing hand gestures keep the bag out of the animation.
        spec['clips']['talk_east']={'frames':[4,5,4,5],'fps':3,'loop':False}
    if name=='rider' and 'v5_lasso_northeast' in source:
        sequence=json.loads((root/'assets/sequence-curation.json').read_text())
        spec['frame_sockets']={}
        for action in ['walk','lasso']:
            recipe=sequence[action]; frames=source[recipe['source_clip']]['frames']
            clip_name=action+'_northeast'
            spec['clips'][clip_name]={'frames':[frames[i] for i in recipe['order']],'fps':8,'loop':action=='walk','durations':recipe['durations']}
            spec['clip_anchors'][clip_name]=alignment['clips'][recipe['source_clip']]['anchor']
        lasso_frames=source[sequence['lasso']['source_clip']]['frames']
        for frame,point in zip(lasso_frames,sequence['lasso']['hand_sockets']): spec['frame_sockets'][str(frame)]={'rope_hand':point}
        for frame in source[sequence['walk']['source_clip']]['frames']: spec['frame_sockets'][str(frame)]={'rope_hand':[54,51]}
        spec['clips']['idle_northeast']={'frames':[lasso_frames[-1]],'fps':1,'loop':True}
        spec['clip_anchors']['idle_northeast']=spec['clip_anchors']['lasso_northeast']
        spec['action_events']['lasso_northeast']={'name':'rope_release','frame':sequence['lasso']['release_ordinal'],'basis':'Clean open-hand release; engine owns the single rope','once_per_action':True}
        spec['procedural_rope_clips']=['lasso_northeast']
    if name in ['longhorn','cream','spotted']:
        necks={'east':[53,40],'west':[18,40],'north':[36,31],'south':[36,43],'northeast':[47,36],'northwest':[24,36],'southeast':[48,42],'southwest':[23,42]}
        spec['frame_sockets']={str(i):{'rope_neck':necks[frame['direction']]} for i,frame in enumerate(spec['frames']) if frame['direction'] in necks}
    spec['clips']['idle']=copy.deepcopy(spec['clips']['idle_east'])
    if 'idle_northeast' in spec['clips']:
        spec['default_facing']='northeast'
        spec['clips']['idle']=copy.deepcopy(spec['clips']['idle_northeast'])
        if name=='rider': spec['clip_anchors']['idle']=spec['clip_anchors']['idle_northeast']
    spec['status']='selected_for_room_review'
    spec['locomotion']={'nominal_speed':72 if name=='rider' else 36,'facing_bias':1.2,'phase_policy':'Preserve walk-cycle phase across facing changes','speed_scale_limits':[0.35,1.8],'idle_when_blocked':True}
    spec['selection_note']='Walk and stationary facing reviewed together; action strips selectively enabled. Final room acceptance is separate.'
    out['sprites'][name]=spec
out['sprites']['wagon']=copy.deepcopy(original['sprites']['wagon'])
def add(family,index,x,y,solid=0):
    spec=kit['families'][family]
    out['scenery'].append({'family':family,'frame':index,'texture':spec['texture'],'region':spec['frames'][index]['atlas_rect'],'anchor':spec['anchor'],'position':[x,y],'collision_radius':solid,'source_frame_id':spec['frames'][index]['id']})
for item in [(1,55,103),(6,280,108),(5,436,100),(2,586,104),(14,363,94)]:add('trees',*item,solid=9)
for item in [(0,32,276),(3,603,288),(9,437,302),(14,163,303),(1,360,103)]:add('rocks',*item,solid=6)
for item in [(0,50,323),(2,205,93),(4,464,303),(8,578,317),(12,322,315)]:add('scrub',*item)
for item in [(0,64,139),(4,51,119),(9,108,148),(7,125,139),(12,49,163)]:add('camp',*item)
for i,(x,y) in enumerate([(76,285),(123,304),(216,305),(255,318),(346,292),(398,313),(522,297),(565,277),(598,121),(410,96),(315,109),(169,97),(234,72),(462,91),(542,95),(37,205),(611,223),(90,185),(446,267),(194,278)]):
    add('grass',[0,1,3,4,5,8,9,10,12,13][i%10],x,y)
out['integrated_unique_actor_frames']=sum(len({i for c in s['clips'].values() for i in c['frames']}) for s in out['sprites'].values())
out['integrated_unique_scenery_frames']=len({(s['family'],s['frame']) for s in out['scenery']})
(root/'assets/room-art.json').write_text(json.dumps(out,indent=2)+'\n')
print('Room selection:',out['integrated_unique_actor_frames'],'actor frames;',out['integrated_unique_scenery_frames'],'scenery variants;',len(out['scenery']),'placements')
