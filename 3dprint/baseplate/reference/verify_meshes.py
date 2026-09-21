"""Check binary STL closure, winding, component counts, and dimensions."""
from pathlib import Path
import collections
import json
import math
import struct

ROOT = Path(__file__).resolve().parent.parent

def inspect(path, expected_components):
    data = path.read_bytes()
    count = struct.unpack_from('<I', data, 80)[0]
    assert len(data) == 84 + 50 * count, f'{path}: invalid binary STL length'
    vertices, faces, ids = [], [], {}
    for i in range(count):
        row = struct.unpack_from('<12fH', data, 84 + 50 * i)
        face = []
        for j in range(3):
            p = tuple(round(v, 5) for v in row[3 + 3*j:6 + 3*j])
            assert all(math.isfinite(v) for v in p)
            if p not in ids:
                ids[p] = len(vertices)
                vertices.append(p)
            face.append(ids[p])
        assert len(set(face)) == 3, f'{path}: degenerate triangle'
        faces.append(face)
    edges = collections.defaultdict(list)
    adjacency = collections.defaultdict(set)
    signed_volume = 0
    for a, b, c in faces:
        for u, v in [(a,b), (b,c), (c,a)]:
            edges[tuple(sorted((u,v)))].append((u,v))
            adjacency[u].add(v)
            adjacency[v].add(u)
        p, q, r = vertices[a], vertices[b], vertices[c]
        cross = (q[1]*r[2]-q[2]*r[1], q[2]*r[0]-q[0]*r[2], q[0]*r[1]-q[1]*r[0])
        signed_volume += sum(p[k]*cross[k] for k in range(3))/6
    assert all(len(e)==2 and e[0]==e[1][::-1] for e in edges.values()), f'{path}: open or inconsistently wound edge'
    unseen, components = set(range(len(vertices))), 0
    while unseen:
        components += 1
        stack = [unseen.pop()]
        while stack:
            nxt = adjacency[stack.pop()] & unseen
            unseen.difference_update(nxt)
            stack.extend(nxt)
    assert components == expected_components, f'{path}: {components} components'
    assert signed_volume > 0, f'{path}: non-positive signed volume'
    lo = [min(v[k] for v in vertices) for k in range(3)]
    hi = [max(v[k] for v in vertices) for k in range(3)]
    return dict(file=path.name, triangles=count, closed_consistent_edges=True,
                components=components, bounds_mm=[lo,hi],
                size_mm=[round(hi[k]-lo[k],5) for k in range(3)],
                volume_mm3=round(signed_volume,3))

if __name__ == '__main__':
    parts = [('lamp-base-plate.stl',1), ('feet.stl',6), ('foot.stl',1),
             ('lamp-fit-test.stl',1), ('box-fit-test.stl',1),
             ('foot-tpu95a.stl',1), ('feet-tpu95a.stl',6),
             ('lamp-base-plate-alternative.stl',1),
             ('lamp-base-plate-five.stl',1),
             ('lamp-position-cover.stl',1),
             ('foot-tpu95a-v2.stl',1), ('feet-tpu95a-v2.stl',6)]
    result = [inspect(ROOT/'output'/name,n) for name,n in parts]
    by_name = {item['file']: item for item in result}
    assert by_name['lamp-base-plate.stl']['size_mm'][:2] == [200,180]
    assert by_name['lamp-base-plate-alternative.stl']['size_mm'][:2] == [160,208]
    assert by_name['lamp-base-plate-five.stl']['size_mm'][:2] == [160,160]
    assert by_name['lamp-position-cover.stl']['size_mm'] == [43.36,43.566,1.2]
    for part in ['foot', 'feet']:
        assert (ROOT/'output'/f'{part}-tpu95a.stl').read_bytes() == (ROOT/'output'/f'{part}-tpu95a-v2.stl').read_bytes()
    report = json.dumps(result,indent=2)+'\n'
    (ROOT/'output'/'mesh-checks.json').write_text(report)
    print(report)
