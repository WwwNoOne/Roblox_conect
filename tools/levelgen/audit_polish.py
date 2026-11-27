"""Count same-facing coplanar rectangle overlaps, including partial overlap.

Independent of the repair function; ignores invisible parts, curved/meshed parts
and non-axis-aligned blocks. Counts faces, not unique part pairs.
"""
import sys, collections, itertools, json, math
import level1,level2,hospital,school,mansion,mall

def walk(root,path=''):
 for c in root.children:
  yield c,root,path+'/'+c.name
  yield from walk(c,path+'/'+c.name)

def bounds(p):
 r=p.props['rot']
 if p.cls!='Part' or p.props.get('shape') not in (None,'Block') or any(c.cls == 'SpecialMesh' for c in p.children): return
 if any(min(abs(v),abs(abs(v)-1))>1e-6 for v in r): return
 size=[sum(abs(r[i*3+j])*p.props['size'][j] for j in range(3)) for i in range(3)]
 return tuple(round(p.props['pos'][i]-size[i]/2,5) for i in range(3)),tuple(round(p.props['pos'][i]+size[i]/2,5) for i in range(3))
def overlaps(root):
 faces=collections.defaultdict(list); out=[]
 for p,par,path in walk(root):
  if p.props.get('transparency',1)>=1:continue
  b=bounds(p)
  if not b:continue
  lo,hi=b
  for ax in range(3):
   other=[i for i in range(3) if i!=ax]
   for sign in (0,1):
    plane=math.floor(b[sign][ax]*1000);key=(ax,sign,plane);bucket=faces[key]
    candidates=[entry for k in range(plane-1,plane+2) for entry in faces[(ax,sign,k)] if abs(entry[1][sign][ax]-b[sign][ax])<=.001]
    for q,qb,qpath in candidates:
     ds=[min(hi[i],qb[1][i])-max(lo[i],qb[0][i]) for i in other]
     if min(ds)>0.001:
      out.append((p,q,path,qpath,ax,ds[0]*ds[1]))
    bucket.append((p,b,path))
 return out
if __name__=='__main__':
 for cls in [level1.Level1,level2.Level2,hospital.Hospital,school.School,mansion.Mansion,mall.Mall]:
  lvl=cls() if cls in (level1.Level1,level2.Level2) else cls(3);B=lvl.build();ov=overlaps(B.root)
  pairs={tuple(sorted((id(p),id(q)))):(p,q,a,b,ax,area) for p,q,a,b,ax,area in ov}
  groups=collections.Counter((a.split('/')[-1],b.split('/')[-1]) for p,q,a,b,ax,area in pairs.values())
  print(B.root.name, 'pairs',len(pairs),'groups',groups.most_common(25),flush=True)
  print('examples',[(a,b,ax,round(area,3),p.props['pos'],q.props['pos']) for p,q,a,b,ax,area in sorted(pairs.values(),key=lambda x:-x[-1])[:6]],flush=True)
