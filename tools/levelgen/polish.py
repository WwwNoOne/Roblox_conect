"""Offline geometry polish: remove true duplicates and recess coincident block faces.

Does not change scripts, markers, rotated silhouettes or floor elevations. Recesses
are 0.02 studs per conflict, capped at 0.12 per face; collision remains enabled.
This is deliberately NOT an arbitrary interpenetration/CSG remover: crossed props,
wall joints and stairs need their overlap. Only coincident outward faces flicker.
"""
from collections import defaultdict, deque
import math
import rbx

EPS=0.02
PROTECTED={'Platform','Bounds','ElevatorDock','Escondite','Beacon'}
FLOORS={'Suelo','Sendero','Claro','Tarima','Tablones','Pasarela','Piso','Techo','Tejado'}

def walk(root):
    for c in root.children:
        yield c,root
        yield from walk(c)

def block_bounds(p):
    if p.cls!='Part' or p.props.get('shape') not in (None,'Block') or p.children:
        return None
    r=p.props['rot']
    if any(min(abs(v),abs(abs(v)-1))>1e-6 for v in r): return None
    size=[sum(abs(r[i*3+j])*p.props['size'][j] for j in range(3)) for i in range(3)]
    return [[round(p.props['pos'][i]-size[i]/2,6) for i in range(3)],
            [round(p.props['pos'][i]+size[i]/2,6) for i in range(3)]]

def signature(p):
    def freeze(v):
        if isinstance(v,dict):return tuple((k,freeze(vv)) for k,vv in sorted(v.items()) if not k.startswith('_'))
        if isinstance(v,(tuple,list)):return tuple(freeze(vv) for vv in v)
        if isinstance(v,float):return round(v,6)
        return v
    return p.cls,p.name,freeze(p.props),freeze(p.attrs),tuple(p.tags),tuple(signature(c) for c in p.children)

def clean(root):
    nodes=list(walk(root));seen={}; removed=[]; changed=[]
    for p,parent in nodes:
        if 'size' not in p.props or p.props.get('transparency',0)>=1 or p.name in PROTECTED or p.attrs or p.tags:
            continue
        # Mesh children are visual; never discard lights, attachments or interactive objects.
        if any(c.cls not in ('SpecialMesh',) for c in p.children):continue
        box=block_bounds(p)
        if box:
            props={k:v for k,v in p.props.items() if k not in ('pos','rot','size') and not k.startswith('_')}
            key=(p.cls,p.name,str(sorted(props.items())),tuple(box[0]),tuple(box[1]))
        else:
            key=signature(p)
        if key in seen:
            parent.children.remove(p);removed.append(p)
        else: seen[key]=p
    nodes=[(p,parent) for p,parent in walk(root) if p.props.get('transparency',1)<1 and block_bounds(p)]
    # Floors and semantic volumes win; small decorative pieces yield to architecture.
    nodes.sort(key=lambda pair:(0 if pair[0].name in PROTECTED else 1 if pair[0].name in FLOORS else 2))
    faces=defaultdict(list)
    for p,parent in nodes:
        b=block_bounds(p);original=[v[:] for v in b]
        if p.name not in PROTECTED:
            for ax in range(3):
                other=[j for j in range(3) if j!=ax]
                for side in (0,1):
                    for attempt in range(7):
                        conflicts=faces[(ax,side,round(b[side][ax],5))]
                        if not any(all(min(b[1][j],q[1][j])-max(b[0][j],q[0][j])>0.001 for j in other) for q in conflicts):break
                        if attempt==6:
                            raise ValueError(f'Cannot separate {root.name}/{p.name} without changing its shape')
                        if b[1][ax]-b[0][ax]<0.05+EPS:
                            # Painted lines/puddles already have minimum thickness. Lift
                            # the whole thin slab instead of collapsing it into the floor.
                            b[0][ax]=round(b[0][ax]+EPS,6)
                            b[1][ax]=round(b[1][ax]+EPS,6)
                        else:
                            b[side][ax]=round(b[side][ax]+(EPS if side==0 else -EPS),6)
        if b!=original:
            old=dict(p.props)
            p.props['pos']=tuple((b[0][j]+b[1][j])/2 for j in range(3))
            world_size=[b[1][j]-b[0][j] for j in range(3)]
            r=p.props['rot']
            p.props['size']=tuple(sum(abs(r[i*3+j])*world_size[i] for i in range(3)) for j in range(3))
            changed.append((p,old))
        for ax in range(3):
            for side in (0,1):faces[(ax,side,round(b[side][ax],5))].append(b)
    return {'removed':removed,'changed':changed}

def perimeter(lay):
    """Exterior of the union of ALL floors; no walls across stairs or upper bridges."""
    occupied={(x,z) for l,x,z in lay.occ}
    outside={(-1,-1)};todo=deque(outside)
    while todo:
        x,z=todo.popleft()
        for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
            n=(x+dx,z+dz)
            if -1<=n[0]<=lay.w and -1<=n[1]<=lay.h and n not in occupied and n not in outside:
                outside.add(n);todo.append(n)
    edges=defaultdict(list)
    for x,z in sorted(occupied):
        for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
            if (x+dx,z+dz) not in outside:continue
            axis='z' if dx else 'x'
            line=x+(dx>0) if dx else z+(dz>0)
            a=z if dx else x
            edges[axis,line].append(a)
    runs=[]
    for (axis,line),starts in sorted(edges.items()):
        merged=[]
        for a in sorted(starts):
            if merged and a==merged[-1][1]:merged[-1][1]=a+1
            else:merged.append([a,a+1])
        runs.extend((axis,line,a,b) for a,b in merged)
    return runs

def enclose(B,jump_height=7.2):
    root=B.root
    if any(c.name=='ContencionExterior' for c in root.children):raise ValueError('Already enclosed')
    solid=[p for p in root.iter() if 'size' in p.props and p.props.get('collide')]
    def extent(p,sign):
        return p.props['pos'][1]+sign*sum(abs(p.props['rot'][3+j])*p.props['size'][j]/2 for j in range(3))
    low=min(extent(p,-1) for p in solid)-16
    # Includes climbable props/roof peaks, plus jump and a full avatar-height margin.
    high=max(extent(p,1) for p in solid)+jump_height+8
    f=rbx.folder(root,'ContencionExterior')
    runs=perimeter(B.lay)
    for i,(axis,line,a,b) in enumerate(runs):
        B.wall_box(f,f'Limite_{i+1:03d}',axis,line*B.C,a*B.C-.3,b*B.C+.3,low,high,.6,(0,0,0),
                   transparency=1,shadow=False,attrs={'MapBoundary':True})
    f.attrs.update(JumpHeightVerified=jump_height,Bottom=low,Top=high,Segments=len(runs))
    return f
