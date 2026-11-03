import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// A flat polygon in 3D space, filled with a single colour.
class Face {
  final List<vm.Vector3> points;
  final Color color;

  const Face(this.points, this.color);
}

/// A collection of faces plus a cached bounding sphere, so whole meshes can be
/// rejected with one distance test instead of projecting every face.
class Mesh3D {
  final List<Face> faces;
  final vm.Vector3 centre;
  final double radius;

  Mesh3D._(this.faces, this.centre, this.radius);

  factory Mesh3D(List<Face> faces) {
    if (faces.isEmpty) {
      return Mesh3D._(faces, vm.Vector3.zero(), 0);
    }
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (final f in faces) {
      for (final p in f.points) {
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.z < minZ) minZ = p.z;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
        if (p.z > maxZ) maxZ = p.z;
      }
    }
    final c = vm.Vector3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2);
    final r = math.sqrt(math.pow(maxX - minX, 2) +
            math.pow(maxY - minY, 2) +
            math.pow(maxZ - minZ, 2)) /
        2;
    return Mesh3D._(faces, c, r);
  }

  /// Copy rotated around Y and translated.
  Mesh3D placed(vm.Vector3 offset, double yaw) {
    final rotation = vm.Matrix4.rotationY(yaw);
    final out = <Face>[];
    for (final face in faces) {
      final pts = <vm.Vector3>[];
      for (final p in face.points) {
        final v = rotation.transform3(p);
        pts.add(vm.Vector3(v.x + offset.x, v.y + offset.y, v.z + offset.z));
      }
      out.add(Face(pts, face.color));
    }
    return Mesh3D(out);
  }
}

/// Axis-aligned box, faces wound outwards.
Mesh3D box(vm.Vector3 min, vm.Vector3 max, Color color) {
  final x0 = min.x, y0 = min.y, z0 = min.z;
  final x1 = max.x, y1 = max.y, z1 = max.z;
  final v = <vm.Vector3>[
    vm.Vector3(x0, y0, z0),
    vm.Vector3(x1, y0, z0),
    vm.Vector3(x1, y1, z0),
    vm.Vector3(x0, y1, z0),
    vm.Vector3(x0, y0, z1),
    vm.Vector3(x1, y0, z1),
    vm.Vector3(x1, y1, z1),
    vm.Vector3(x0, y1, z1),
  ];
  return Mesh3D(<Face>[
    Face([v[4], v[5], v[6], v[7]], color), // +z
    Face([v[1], v[0], v[3], v[2]], color), // -z
    Face([v[0], v[4], v[7], v[3]], color), // -x
    Face([v[5], v[1], v[2], v[6]], color), // +x
    Face([v[3], v[7], v[6], v[2]], color), // +y
    Face([v[0], v[1], v[5], v[4]], color), // -y
  ]);
}

/// Right-handed look-at view matrix (camera looks down its own -Z).
vm.Matrix4 _lookAt(vm.Vector3 eye, vm.Vector3 target, vm.Vector3 up) {
  final forward = target - eye;
  forward.normalize();
  final right = forward.cross(up);
  right.normalize();
  final trueUp = right.cross(forward);

  final m = vm.Matrix4.identity();
  m.setRow(0, vm.Vector4(right.x, right.y, right.z, -right.dot(eye)));
  m.setRow(1, vm.Vector4(trueUp.x, trueUp.y, trueUp.z, -trueUp.dot(eye)));
  m.setRow(2, vm.Vector4(-forward.x, -forward.y, -forward.z, forward.dot(eye)));
  m.setRow(3, vm.Vector4(0.0, 0.0, 0.0, 1.0));
  return m;
}

vm.Matrix4 _perspective(double fovY, double aspect, double near, double far) {
  final f = 1.0 / math.tan(fovY / 2.0);
  final nf = 1.0 / (near - far);
  final m = vm.Matrix4.identity();
  m.setRow(0, vm.Vector4(f / aspect, 0.0, 0.0, 0.0));
  m.setRow(1, vm.Vector4(0.0, f, 0.0, 0.0));
  m.setRow(2, vm.Vector4(0.0, 0.0, (far + near) * nf, 2.0 * far * near * nf));
  m.setRow(3, vm.Vector4(0.0, 0.0, -1.0, 0.0));
  return m;
}

class Camera3D {
  vm.Vector3 position = vm.Vector3(0, 20, -60);
  vm.Vector3 target = vm.Vector3(0, 0, 0);
  final vm.Vector3 up = vm.Vector3(0, 1, 0);
  double fov = 62 * math.pi / 180;
  double near = 0.5;
  double far = 4000;
  late vm.Matrix4 vp;

  void update(double aspect) {
    vp = _perspective(fov, aspect, near, far) * _lookAt(position, target, up);
  }
}

class _Projected {
  final List<Offset> pts;
  final Color color;
  final double depth;

  _Projected(this.pts, this.color, this.depth);
}

const double _nearEps = 0.1;

/// Sutherland-Hodgman clip of a polygon against w > eps, in clip space.
List<vm.Vector4> _clipNear(List<vm.Vector4> poly) {
  final out = <vm.Vector4>[];
  final n = poly.length;
  for (var i = 0; i < n; i++) {
    final cur = poly[i];
    final nxt = poly[(i + 1) % n];
    final curIn = cur.w > _nearEps;
    final nxtIn = nxt.w > _nearEps;
    if (curIn) out.add(cur);
    if (curIn != nxtIn) {
      final t = (_nearEps - cur.w) / (nxt.w - cur.w);
      out.add(vm.Vector4(
        cur.x + (nxt.x - cur.x) * t,
        cur.y + (nxt.y - cur.y) * t,
        cur.z + (nxt.z - cur.z) * t,
        _nearEps,
      ));
    }
  }
  return out;
}

vm.Vector3 _centroid(List<vm.Vector3> pts) {
  var x = 0.0, y = 0.0, z = 0.0;
  for (final p in pts) {
    x += p.x;
    y += p.y;
    z += p.z;
  }
  final n = pts.length.toDouble();
  return vm.Vector3(x / n, y / n, z / n);
}

/// Static sun direction used for face shading.
final vm.Vector3 kLightDir = vm.Vector3(0.45, 0.92, 0.35)..normalize();

Color shadeFace(Face face) {
  if (face.points.length < 3) return face.color;
  final a = face.points[0];
  final b = face.points[1];
  final c = face.points[2];
  final n = (b - a).cross(c - a);
  if (n.length2 < 1e-9) return face.color;
  n.normalize();
  final k = 0.62 + 0.38 * n.dot(kLightDir).abs();
  return Color.lerp(Colors.black, face.color, k)!;
}

List<_Projected> _project(List<Mesh3D> meshes, Camera3D cam, Size size,
    {double cullRadius = 1400}) {
  final items = <_Projected>[];
  final eye = cam.position;
  for (final mesh in meshes) {
    // Reject whole meshes that cannot be on screen.
    final d = (mesh.centre - eye).length;
    if (d - mesh.radius > cullRadius) continue;
    for (final face in mesh.faces) {
      if (face.points.length >= 3) {
        final a = face.points[0];
        final b = face.points[1];
        final c = face.points[2];
        final n = (b - a).cross(c - a);
        if (n.length2 > 1e-9) {
          n.normalize();
          if (n.dot(eye - _centroid(face.points)) < 0) continue;
        }
      }

      final clip = <vm.Vector4>[];
      for (final p in face.points) {
        clip.add(cam.vp.transform(vm.Vector4(p.x, p.y, p.z, 1.0)));
      }
      final clipped = _clipNear(clip);
      if (clipped.length < 3) continue;

      final pts = <Offset>[];
      var depth = 0.0;
      for (final c in clipped) {
        final sx = ((c.x / c.w) * 0.5 + 0.5) * size.width;
        final sy = (1.0 - ((c.y / c.w) * 0.5 + 0.5)) * size.height;
        pts.add(Offset(sx, sy));
        depth += c.w;
      }
      items.add(_Projected(pts, shadeFace(face), depth / clipped.length));
    }
  }
  return items;
}

void _paint(Canvas canvas, _Projected item) {
  final pts = item.pts;
  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx, pts[i].dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = item.color);
}

/// Painter's-algorithm draw of every mesh.
void renderMeshes(Canvas canvas, Size size, Camera3D cam, List<Mesh3D> meshes,
    {double cullRadius = 1400}) {
  final items = _project(meshes, cam, size, cullRadius: cullRadius);
  items.sort((a, b) => b.depth.compareTo(a.depth));
  for (final item in items) {
    _paint(canvas, item);
  }
}

/// Draws without sorting, for ground planes that must always sit underneath.
void renderFlat(Canvas canvas, Size size, Camera3D cam, List<Mesh3D> meshes) {
  for (final item in _project(meshes, cam, size, cullRadius: 5000)) {
    _paint(canvas, item);
  }
}
