from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
source=HERE/'source.png'
image=Image.open(source).convert('RGBA')
a=np.array(image)
rgb=a[:,:,:3].astype(int)
key=(rgb[:,:,0]>80)&(rgb[:,:,2]>80)&(rgb[:,:,1]<rgb[:,:,0]*.7)&(rgb[:,:,1]<rgb[:,:,2]*.7)
a[key]=0
a[~key,3]=255
clean=Image.fromarray(a)
bounds=clean.getbbox()
assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<image.width and bounds[3]<image.height
figure=clean.crop(bounds)
figure.save(HERE/'ines-native.png')
width=round(figure.width*160/figure.height)
small=figure.resize((width,160),Image.Resampling.NEAREST)
cell=Image.new('RGBA',(256,256))
cell.paste(small,(128-width//2,84))
cell.save(HERE/'atlas.png')
cell.resize((512,512),Image.Resampling.NEAREST).save(HERE/'preview.png')
metadata={'schema_version':1,'id':'ines-high-angle-v1','character':'Ines Vale','age':23,'source':'source.png','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_size':list(image.size),'native_image':'ines-native.png','trim_bounds_xyxy':list(bounds),'texture':'atlas.png','cell':[256,256],'anchor':[128,244],'figure_height':160,'atlas_rect_xywh':[0,0,256,256],'requested_facing':'southeast','observed_facing':'front-right/southeast','requested_elevation_degrees':40,'observed_elevation':'Clearly above head; crown, upper shoulders and boot top planes visible; stronger vertical foreshortening than prior turnaround. Exact degrees not measurable from generated sprite.','status':'candidate_static_camera_reference','runtime_admitted':False,'animations':{},'tool':'builtin image_gen','model':'not exposed','date':'2026-09-08','prompt':'prompt.txt','identity_reference':'kits/wardrobe/ines-period-turnaround-v1/southeast-native.png','camera_reference':'source/reference_0.png','transform':'Magenta key; preserve native whole-figure trim; nearest-neighbor whole-figure resize160px; no repaint/rig/assembly','approval_scope':'No room/camera approval claimed. Prior clothing coverage reference approved, this new period costume remains candidate.'}
metadata['id']='ines-high-angle-passing-v1'
metadata['identity_reference']='kits/wardrobe/ines-high-angle-v1/ines-native.png'
metadata['status']='candidate_single_advancing_pose_not_verified_mid_passing'
metadata['requested_pose']='Far boot planted under hip; near leg passing low with lifted heel.'
metadata['observed_pose']='Near knee bends and near boot advances southeast; far leg recedes beneath skirt. Feet remain separated fore/aft rather than a narrow ankle-level mid-pass.'
metadata['foot_notes']='Far boot is visually behind hip and appears elevated; grounded far support and near lifted heel are not unequivocal. Do not label as verified planted-far mid-passing.'
metadata['duration_ms_provisional']=160
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(cell)[:,:,3])).issubset({0,255})
print('INES HIGH ANGLE PASS:whole native cutout and160px/256cell anchor128,244; binaryalpha')
