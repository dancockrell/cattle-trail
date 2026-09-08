"""Extract four generated large sheets; never duplicate poses or invent phase approval."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
from scipy.ndimage import label,find_objects
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
specs=[(HERE,4,['walk_northwest','walk_north','walk_northeast','walk_west'])]
for sheet_number,(folder,rows,row_names) in enumerate(specs,2):
 source=folder/'source.png';a=np.array(Image.open(source).convert('RGBA'));rgb=a[:,:,:3].astype(int);r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
 bg=((rgb.min(2)>180)&((rgb.max(2)-rgb.min(2))<22)) if sheet_number==1 else ((r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8))
 a[:,:,3]=np.where(bg,0,255);a[a[:,:,3]==0]=0;labels,n=label(a[:,:,3]>0);sizes=np.bincount(labels.ravel());height,width=a.shape[:2];cw,ch=width/8,height/rows
 assigned={};merged=[]
 for ident,slices in enumerate(find_objects(labels),1):
  if sizes[ident]<1000:continue
  ys,xs=slices
  if ys.stop-ys.start>ch*1.5:
   merged.append(ident);continue
  col=min(7,max(0,int((xs.start+xs.stop)/2/cw)));row=min(rows-1,max(0,int((ys.start+ys.stop)/2/ch)))
  if (row,col) in assigned:raise ValueError('Multiple major silhouettes assigned one cell')
  assigned[row,col]=(ident,None)
 if sheet_number==1:
  assert len(merged)==1
  # Raw generation joins the SW stand and following repair figure at one edge.
  # Preserve the raw source and explicitly flag the two crop boundaries.
  assigned[3,7]=(merged[0],(0,729));assigned[4,7]=(merged[0],(729,height))
 assert len(assigned)==rows*8, f'Sheet{sheet_number}: {len(assigned)} figures instead of{rows*8}'
 figures=[];frames=[]
 for row in range(rows):
  for col in range(8):
   index=row*8+col;ident,yrange=assigned[row,col];visible=labels==ident
   if yrange:
    visible[:yrange[0]]=False;visible[yrange[1]:]=False
   pixels=a.copy();pixels[~visible]=0;im=Image.fromarray(pixels);bounds=im.getbbox();assert bounds
   whole=im.crop(bounds);whole.save(folder/f'{index:02}-native.png');figures.append(whole)
   frames.append({'index':index,'row':row,'column':col,'requested_row':row_names[row],'requested_order':col,'verified_phase':None,'phase_status':'not_verified','source_bounds_xyxy':list(bounds),'native_size':list(whole.size),'native_image':f'{index:02}-native.png','native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest(),'touching_neighbor_crop':bool(yrange),'touches_source_edge':bounds[0]==0 or bounds[1]==0 or bounds[2]==width or bounds[3]==height})
 scale=min(160/max(f['native_size'][1] for f in frames),232/max(f['native_size'][0] for f in frames))
 row_ground=[max(f['source_bounds_xyxy'][3]-f['row']*ch for f in frames if f['row']==row) for row in range(rows)]
 atlas=Image.new('RGBA',(2048,rows*256));native_atlas=Image.fromarray(a);native_atlas.save(folder/'atlas-native.png')
 for whole,frame in zip(figures,frames):
  row,col=frame['row'],frame['column'];x0,y0,_,_=frame['source_bounds_xyxy'];scaled=(round(whole.width*scale),round(whole.height*scale))
  offset=(round(128+(x0-(col+.5)*cw)*scale),round(244+(y0-row*ch-row_ground[row])*scale))
  assert min(offset)>=0 and offset[0]+scaled[0]<256 and offset[1]+scaled[1]<=256
  cell=Image.new('RGBA',(256,256));cell.paste(whole.resize(scaled,Image.Resampling.NEAREST),offset);cell.save(folder/f'{frame["index"]:02}-whole-frame.png');atlas.paste(cell,(col*256,row*256))
  frame.update({'atlas_rect':[col*256,row*256,256,256],'anchor':[128,244],'offset':list(offset),'scaled_size':list(scaled),'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest()})
 atlas.save(folder/'atlas.png')
 notes=['Generated artwork is unique source output; no frame duplication, recoloring, mirroring or padding was performed by extraction.','Requested eight-phase order is preserved as source column order, not verified anatomical timing.','One fixed scale and per-row source-coordinate ground registration preserve relative bob; no per-pose resizing.']
 if sheet_number==1:notes+=['Generator returned1448x1086, not requested4K; original detail preserved.','Baked pale checkerboard keyed; neutralbright tool highlights may also be removed. Rawsource retained.','Two source figures touch at row4/5 col8, flagged boundary crops; first figure reaches source topedge.','Walking rows contain repeated lead-leg silhouettes; turn/repair/emote rows are pose banks, not approved complete loops.']
 if sheet_number==2:notes+=['Observed row1 points back-right (NE-like) while requestedNW; observedrow3 points back-left (NW-like) while requestedNE.','Walking rows repeat several contact/support shapes; completeopposite-phase order not established.']
 if sheet_number==3:notes+=['Jog has dynamic raisedlegs/arms but repeatedlead-leg silhouettes; requested complete eightphase loop not verified.']
 if sheet_number==4:notes+=['Idle/repair/talk/care gestures differ visibly; endpoints and consistentprops not all cleanly matched.','Some sip frames contain a mug atwaist plus a second drinkingmug; retain as faulty sourceposes, not approved campcareloop.']
 metadata={'id':'ada-directional-sheet-v2','character':'ada_mercer','age':22,'sheet_number':sheet_number,'status':'generated_big_sheet_candidates_unadmitted','runtime_admitted':False,'edit_references':['kits/big-sheets/ada-v1/sheet02/source.png','kits/workcycles/ada-continuous-walk-v1/extracted/e026731eea63e23f/candidate-24-35/contact-sheet.png'],'source':'source.png','source_sha256':sha(source),'source_dimensions':[width,height],'prompt':'prompt.txt','reference':'kits/wardrobe/ada-high-angle-v1/source.png','reference_sha256':sha(ROOT/'kits/wardrobe/ada-high-angle-v1/source.png'),'texture':'atlas.png','native_texture':'atlas-native.png','columns':8,'rows':rows,'cell':[256,256],'anchor':[128,244],'pixels_per_world_unit':4,'uniform_scale':scale,'row_ground_source_local':row_ground,'frames':frames,'row_labels':row_names,'clips':{name+'_review':{'frames':list(range(row*8,(row+1)*8)),'fps':8,'loop':True,'admitted':False,'timing':'provisional_source_order_review'}for row,name in enumerate(row_names)},'review':notes,'provenance':{'tool':'builtin image_gen','successful_calls_this_sheet':1,'transforms':['background key','connectedwholefigure native extraction','nativeatlas preserves original layout','one uniform nearest scale','rowregistered256cell atlas']}}
 (folder/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
 print(f'ADA BIG SHEET{sheet_number} EXTRACTED:{rows*8} sourcefigures; requestedphasesnotverified')
