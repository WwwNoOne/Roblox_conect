import unittest
import rbx
import polish
from audit_polish import overlaps
class PolishTests(unittest.TestCase):
 def test_partial_faces(self):
  root=rbx.model(None,'Level_1')
  rbx.box(root,'Muro',0,10,0,10,0,1,(100,100,100))
  rbx.box(root,'Muro',9,20,0,10,0,1,(100,100,100))
  polish.clean(root)
  self.assertEqual(len(overlaps(root)),0)
 def test_crossed_silhouettes_and_markers_survive(self):
  root=rbx.model(None,'Level_2')
  for angle in [0,90]: rbx.ellipsoid(root,'Silueta',(0,0,0),(10,20,.4),(50,70,50),rot=rbx.rot_y(angle))
  for _ in range(2): rbx.part(root,'Escondite',(0,0,0),(2,6,2),(0,0,0),transparency=1)
  polish.clean(root)
  self.assertEqual(len(root.children),4)
 def test_floor_top_and_collision_remain(self):
  root=rbx.model(None,'Level_1')
  floor=rbx.box(root,'Platform',0,20,-1,0,0,20,(100,100,100))
  original=floor.props.copy()
  wall=rbx.box(root,'Muro',0,1,-1,0,0,20,(200,100,100))
  polish.clean(root)
  self.assertEqual(floor.props,original)
  self.assertTrue(wall.props['collide'])
  self.assertEqual(len(overlaps(root)),0)
 def test_thin_paint_keeps_minimum_thickness(self):
  root=rbx.model(None,'Level_1')
  for x in (0,1):rbx.part(root,'Linea',(x,.025,0),(4,.05,4),(255,255,255),collide=False)
  polish.clean(root)
  self.assertEqual(len(overlaps(root)),0)
  self.assertTrue(all(p.props['size'][1]>=.05-1e-8 for p in root.children))
 def test_boundary_uses_upper_bridge_projection(self):
  from types import SimpleNamespace
  from build import Builder
  lay=SimpleNamespace(occ={(0,0,0):0,(1,1,0):0,(0,2,0):0},w=3,h=1,links={})
  B=Builder(lay,10,14,'Level_1')
  rbx.part(B.root,'Roof',(15,20,5),(30,1,10),(100,100,100))
  f=polish.enclose(B)
  self.assertEqual(len(f.children),4)
  self.assertGreater(f.attrs['Top'],20.5+7.2)
  self.assertTrue(all(p.props['collide'] and p.props['query'] for p in f.children))
  # No barrier at either internal connection of the upper bridge.
  for p in f.children:
   self.assertFalse(p.props['size'][0]<1 and p.props['pos'][0] in (10,20))

if __name__=='__main__':unittest.main()
