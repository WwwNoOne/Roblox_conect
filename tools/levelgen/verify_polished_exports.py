import xml.etree.ElementTree as ET,sys,collections,json
import rbx
from audit_polish import overlaps

def parse(e):
 p=e.find('Properties');i=rbx.Inst(e.get('class'),p.findtext("string[@name='Name']"))
 if i.cls=='Part':
  cf=p.find("CoordinateFrame[@name='CFrame']");sz=p.find("Vector3[@name='size']")
  i.props={'pos':tuple(float(cf.findtext(k)) for k in 'XYZ'),'rot':tuple(float(cf.findtext('R%d%d'%(a,b))) for a in range(3) for b in range(3)), 'size':tuple(float(sz.findtext(k)) for k in 'XYZ'), 'transparency':float(p.findtext("float[@name='Transparency']",'0')), 'shape':{0:'Ball',1:'Block',2:'Cylinder'}[int(p.findtext("token[@name='shape']",'1'))]}
 for c in e.findall('Item'):i.add(parse(c))
 return i
if __name__=='__main__':
 for path in sys.argv[1:]:
  root=parse(ET.parse(path).getroot().find('Item'));ov=overlaps(root)
  print(root.name,'serialized coincident faces:',len(ov),flush=True)
  assert not ov
