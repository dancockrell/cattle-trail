"""Measure rider-body anchors without changing source or atlas pixels."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np,json
root=Path(__file__).resolve().parents[1]
kit=json.loads((root/'kits/manifest.json').read_text())['families']['rider']
atlas=Image.open(root/kit['texture'].replace('res://','')).convert('RGBA')
measurements={}
for index,frame in enumerate(kit['frames']):
    x,y,w,h=frame['atlas_rect']; tile=atlas.crop((x,y,x+w,y+h))
    a=np.asarray(tile); hsv=np.asarray(tile.convert('RGB').convert('HSV'))
    blue=(a[:,:,3]>0)&(hsv[:,:,0]>=130)&(hsv[:,:,0]<=175)&(hsv[:,:,1]>70)&(hsv[:,:,2]>35)
    yy,xx=np.where(blue)
    assert len(xx)>10,(index,'Insufficient shirt pixels')
    # Brown/dark opaque body pixels exclude the pale detached dust beneath hooves.
    body=(a[:,:,3]>0)&(a[:,:,0]<150)&(a[:,:,1]<130)&(a[:,:,2]<125)
    by,bx=np.where(body)
    measurements[index]={'shirt_x':float(np.median(xx)),'hoof_y':int(by.max()+1),'blue_pixels':len(xx)}
clips={}
for name,clip in kit['clips'].items():
    indices=clip['frames']
    clips[name]={'anchor':[round(float(np.median([measurements[i]['shirt_x'] for i in indices]))),round(float(np.median([measurements[i]['hoof_y'] for i in indices])))],'frames':indices,'observed':{str(i):measurements[i] for i in indices}}
clips['idle']={'anchor':clips['idle_east']['anchor'],'frames':[0]}
out={'schema_version':1,'family':'rider','method':'Per-clip median shirt center X and dark hoof contact Y; one shared anchor per strip preserves intra-cycle recoil and gait. Detached pale dust is excluded from ground measurement. Atlas pixels unchanged.','status':'measured_for_visual_review','clips':clips}
(root/'assets/rider-anchors.json').write_text(json.dumps(out,indent=2)+'\n')
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',14)
review=Image.new('RGB',(1024,4*220),'#65703c');d=ImageDraw.Draw(review)
for row,direction in enumerate(['east','west','north','south']):
    for col,action in enumerate(['walk','lasso','shoot']):
        name=action+'_'+direction;spec=clips[name];ox=col*336;oy=row*220
        d.text((ox+8,oy+6),f'{name}: {spec["anchor"]}',font=font,fill='white')
        for n,index in enumerate(spec['frames']):
            x,y,w,h=kit['frames'][index]['atlas_rect'];tile=atlas.crop((x,y,x+w,y+h))
            # Unscaled frames share visible ground and rider-body guide coordinates.
            px=ox+44+n*80;py=oy+142
            review.paste(tile,(px-spec['anchor'][0],py-spec['anchor'][1]),tile)
            d.line((px-25,py,px+25,py),fill='#f4c977')
            d.line((px,py+3,px,py+9),fill='#f4c977')
review.save(root/'kits/reviews/rider-anchor-review.png')
print(json.dumps({name:data['anchor'] for name,data in clips.items()},indent=2))
