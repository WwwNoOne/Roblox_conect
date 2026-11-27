"""Export polished maps and optional localhost Studio patches from the same tree."""
import os,json,argparse
from pathlib import Path
import level1,level2,hospital,school,mansion,mall,polish,rbx
from audit_polish import overlaps
root=str(Path(__file__).resolve().parents[2])
ap=argparse.ArgumentParser()
ap.add_argument('--patch-dir',type=Path)
args=ap.parse_args()
if args.patch_dir:args.patch_dir.mkdir(parents=True,exist_ok=True)
summary=[]
def geom(p,props=None):
 d=props or p.props
 return {'name':p.name,'pos':d['pos'],'size':d['size'],'rot':d['rot']}
for cls,seed in [(level1.Level1,27),(level2.Level2,5),(hospital.Hospital,3),(school.School,3),(mansion.Mansion,3),(mall.Mall,3)]:
 lvl=cls(seed);B=lvl.build()
 marks=[(i.name,dict(i.props),dict(i.attrs)) for i in B.root.iter() if i.cls=='Attachment' or i.name in polish.PROTECTED]
 old=B.root.count(); before=len(overlaps(B.root));clean=polish.clean(B.root);f=polish.enclose(B)
 after=len(overlaps(B.root));assert after==0
 assert marks==[(i.name,dict(i.props),dict(i.attrs)) for i in B.root.iter() if i.cls=='Attachment' or i.name in polish.PROTECTED]
 ops=[{'old':geom(p,oldprops),'new':geom(p)} for p,oldprops in clean['changed']]
 ops += [{'old':geom(p),'delete':True} for p in clean['removed']]
 patch={'map':B.root.name,'dock':lvl.dock.props['pos'],'ops':ops,'barriers':[geom(p) for p in f.children],'boundaryAttrs':f.attrs}
 if args.patch_dir:
  with open(args.patch_dir/(B.root.name+'.json'),'w') as out:json.dump(patch,out,separators=(',',':'))
 rbx.write_rbxmx(B.root,root+'/assets_build/exports/'+B.root.name+'.rbxmx',primary=lvl.dock)
 row={'map':B.root.name,'coincident_faces_before':before,'coincident_faces_after':after,'true_duplicates_removed':len(clean['removed']),'parts_adjusted':len(clean['changed']),'boundary_segments':len(f.children),'instances_before':old,'instances_after':B.root.count(),'boundary_bottom':f.attrs['Bottom'],'boundary_top':f.attrs['Top']}
 summary.append(row);print(json.dumps(row),flush=True)
os.makedirs(root+'/assets_build/reports',exist_ok=True)
with open(root+'/assets_build/reports/map_polish.json','w') as out:json.dump(summary,out,indent=2)
