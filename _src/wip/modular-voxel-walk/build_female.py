# Base voxel mannequin. One script places every block. Blender runs it.
#
# The keyed frames supply measurements only. Nothing from those frames is
# painted onto the body. No hair yet. Each joint is its own piece.
#
# Keyed cell on the ortho still: sole row y244 lands on the render sole,
# and 346 render px cover the 232 voxels. z = 251 - file_y.
#   The throat stays short. Round shoulder caps sit on the arm tops.
#   The chest is the bust width, and the bust leads the belly.
#   The thigh follows the pant taper into a forward knee. The calf is
#   thinner than the thigh. Boots are not on the shin.
#   The head is the face: wide cheeks, a chin, a crown that rounds back.
# Estimates: elbow in the sleeve, skull depth, breast and glute
# projection past the coat, foot length (the side foot is a stride).

import math
import traceback

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

ROOT = r"C:\Users\Vira\.grok\worktrees\repos-whatdwellsbelow\wdb-art-pipeline-20261109-0527"
KEYED = ROOT + r"\_src\wip\modular-voxel-walk\keyed"
BLEND = ROOT + r"\_src\wip\modular-voxel-walk\female-modular.blend"

CX = 128
GROUND = 251

SKIN_C = (232, 152, 96)
HAIR_C = (29, 19, 15)
HAIR_DARK = (16, 10, 8)
BAND_C = (149, 184, 57)
BAND_DARK = (62, 88, 10)
COAT_C = (100, 40, 42)
COAT_DARK = (62, 28, 32)
PANTS_C = (54, 52, 58)
PANTS_DARK = (32, 30, 36)
BOOT_C = (112, 64, 36)
BOOT_DARK = (64, 32, 20)

# Joints, in voxels. +X is her right. -Y is her front. +Z is up.
# Arm hangs from the pauldron, just outside the chest, so the waist pinch opens a gap.
# Y is mid-torso: the shoulder cap sits behind the bust.
HIP_X = 16
HIP_Z = 100
KNEE_Z = 56
ANKLE_Z = 8
SHOULDER = (30, -2, 162)
UPPER_LEN = 30
FORE_LEN = 26
HAND_LEN = 12

# The base body is the thing on screen. Gear stays off until the body reads.
HIDDEN = set()


def load_top(path):
    image = bpy.data.images.load(path, check_existing=True)
    image.reload()
    width, height = int(image.size[0]), int(image.size[1])
    buf = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(buf)
    return buf.reshape((height, width, 4))[::-1].copy()


def sample(image, file_x, file_y):
    height, width, _ = image.shape
    ix = int(round(file_x))
    iy = int(round(file_y))
    if ix < 0 or iy < 0 or ix >= width or iy >= height:
        return None
    pixel = image[iy, ix]
    if float(pixel[3]) < 0.5:
        return None
    red = int(pixel[0] * 255.0 + 0.5)
    green = int(pixel[1] * 255.0 + 0.5)
    blue = int(pixel[2] * 255.0 + 0.5)
    if red > 240 and blue > 240 and green < 20:
        return None
    return (red, green, blue)


def palette(image, x0, x1, y0, y1):
    found = []
    for file_y in range(y0, y1, 2):
        for file_x in range(x0, x1, 2):
            color = sample(image, file_x, file_y)
            if color is not None and max(color) > 8:
                found.append(color)
    return found


def darken(color, num, den):
    return tuple(max(0, min(255, channel * num // den)) for channel in color)


def frame(origin, z_dir, y_hint):
    """Local +Z follows z_dir. Local +Y follows y_hint."""
    z_axis = Vector(z_dir).normalized()
    y_axis = Vector(y_hint)
    y_axis = y_axis - z_axis * y_axis.dot(z_axis)
    if y_axis.length < 1e-6:
        y_axis = Vector((0.0, 0.0, 1.0))
        y_axis = y_axis - z_axis * y_axis.dot(z_axis)
    y_axis.normalize()
    x_axis = y_axis.cross(z_axis).normalized()
    y_axis = z_axis.cross(x_axis).normalized()
    return Matrix((
        (x_axis.x, y_axis.x, z_axis.x, origin[0]),
        (x_axis.y, y_axis.y, z_axis.y, origin[1]),
        (x_axis.z, y_axis.z, z_axis.z, origin[2]),
        (0.0, 0.0, 0.0, 1.0),
    ))


def translation(x_pos, y_pos, z_pos):
    mat = Matrix.Identity(4)
    mat.translation = Vector((x_pos, y_pos, z_pos))
    return mat


def point_of(mat, x_pos, y_pos, z_pos):
    transformed = mat @ Vector((float(x_pos), float(y_pos), float(z_pos), 1.0))
    return (transformed.x, transformed.y, transformed.z)


class Voxels:
    def __init__(self, x0, x1, y0, y1, z0, z1):
        self.x0 = int(x0)
        self.y0 = int(y0)
        self.z0 = int(z0)
        self.mask = np.zeros((int(x1 - x0 + 1), int(y1 - y0 + 1), int(z1 - z0 + 1)), dtype=bool)
        self.col = np.zeros(self.mask.shape + (3,), dtype=np.uint8)

    def _box(self, x0, x1, y0, y1, z0, z1):
        ix0 = max(0, int(math.floor(x0)) - self.x0)
        ix1 = min(self.mask.shape[0] - 1, int(math.ceil(x1)) - self.x0)
        iy0 = max(0, int(math.floor(y0)) - self.y0)
        iy1 = min(self.mask.shape[1] - 1, int(math.ceil(y1)) - self.y0)
        iz0 = max(0, int(math.floor(z0)) - self.z0)
        iz1 = min(self.mask.shape[2] - 1, int(math.ceil(z1)) - self.z0)
        return ix0, ix1, iy0, iy1, iz0, iz1

    def fill_ellipsoid(self, cx, cy, cz, rx, ry, rz, color):
        if rx < 0.4 or ry < 0.4 or rz < 0.4:
            return
        ix0, ix1, iy0, iy1, iz0, iz1 = self._box(cx - rx, cx + rx, cy - ry, cy + ry, cz - rz, cz + rz)
        if ix1 < ix0 or iy1 < iy0 or iz1 < iz0:
            return
        xs = (np.arange(ix0, ix1 + 1) + self.x0 - cx)[:, None, None] / rx
        ys = (np.arange(iy0, iy1 + 1) + self.y0 - cy)[None, :, None] / ry
        zs = (np.arange(iz0, iz1 + 1) + self.z0 - cz)[None, None, :] / rz
        disc = (xs * xs + ys * ys + zs * zs) <= 1.0
        self.mask[ix0:ix1 + 1, iy0:iy1 + 1, iz0:iz1 + 1][disc] = True
        self.col[ix0:ix1 + 1, iy0:iy1 + 1, iz0:iz1 + 1][disc] = color

    def fill_disc(self, z_pos, cx, cy, rx, ry, color, shell=0):
        if rx < 0.4 or ry < 0.4:
            return
        iz = int(z_pos) - self.z0
        if iz < 0 or iz >= self.mask.shape[2]:
            return
        ix0, ix1, iy0, iy1, _, _ = self._box(cx - rx, cx + rx, cy - ry, cy + ry, z_pos, z_pos)
        if ix1 < ix0 or iy1 < iy0:
            return
        xs = (np.arange(ix0, ix1 + 1) + self.x0 - cx)[:, None] / rx
        ys = (np.arange(iy0, iy1 + 1) + self.y0 - cy)[None, :] / ry
        disc = (xs * xs + ys * ys) <= 1.0
        if shell > 0 and rx > shell + 0.4 and ry > shell + 0.4:
            inner_x = (np.arange(ix0, ix1 + 1) + self.x0 - cx)[:, None] / (rx - shell)
            inner_y = (np.arange(iy0, iy1 + 1) + self.y0 - cy)[None, :] / (ry - shell)
            disc = disc & ~((inner_x * inner_x + inner_y * inner_y) <= 1.0)
        self.mask[ix0:ix1 + 1, iy0:iy1 + 1, iz][disc] = True
        self.col[ix0:ix1 + 1, iy0:iy1 + 1, iz][disc] = color

    def clear_disc(self, z_pos, cx, cy, rx, ry):
        iz = int(z_pos) - self.z0
        if iz < 0 or iz >= self.mask.shape[2] or rx < 0.4 or ry < 0.4:
            return
        ix0, ix1, iy0, iy1, _, _ = self._box(cx - rx, cx + rx, cy - ry, cy + ry, z_pos, z_pos)
        if ix1 < ix0 or iy1 < iy0:
            return
        xs = (np.arange(ix0, ix1 + 1) + self.x0 - cx)[:, None] / rx
        ys = (np.arange(iy0, iy1 + 1) + self.y0 - cy)[None, :] / ry
        disc = (xs * xs + ys * ys) <= 1.0
        self.mask[ix0:ix1 + 1, iy0:iy1 + 1, iz][disc] = False

    def paint_ends(self, front_at, back_at):
        columns = np.argwhere(self.mask.any(axis=1))
        for ix, iz in columns:
            ys = np.flatnonzero(self.mask[ix, :, iz])
            if len(ys) == 0:
                continue
            x_pos = self.x0 + int(ix)
            z_pos = self.z0 + int(iz)
            y_front = self.y0 + int(ys[0])
            front = front_at(x_pos, y_front, z_pos)
            if front is not None:
                self.col[ix, int(ys[0]), iz] = front
            if back_at is None or int(ys[-1]) == int(ys[0]):
                continue
            y_back = self.y0 + int(ys[-1])
            back = back_at(x_pos, y_back, z_pos)
            if back is not None:
                self.col[ix, int(ys[-1]), iz] = back


def lerp_keys(z_pos, keys):
    if z_pos <= keys[0][0]:
        return keys[0][1:]
    if z_pos >= keys[-1][0]:
        return keys[-1][1:]
    for index in range(1, len(keys)):
        if z_pos <= keys[index][0]:
            z0, *start = keys[index - 1]
            z1, *end = keys[index]
            blend = (z_pos - z0) / float(z1 - z0)
            return tuple(a + (b - a) * blend for a, b in zip(start, end))
    return keys[-1][1:]


def _plane(mask, axis, depth):
    if axis == 0:
        return mask[depth, :, :]
    if axis == 1:
        return mask[:, depth, :]
    return mask[:, :, depth]


def _orient(plane, axis):
    if axis != 1:
        return plane
    if plane.ndim == 2:
        return plane.T
    return np.transpose(plane, (1, 0, 2))


def _rects(slab, scol):
    height, width = slab.shape
    seen = np.zeros_like(slab)
    found = []
    for u_pos in range(height):
        v_pos = 0
        while v_pos < width:
            if not slab[u_pos, v_pos] or seen[u_pos, v_pos]:
                v_pos += 1
                continue
            tone = (
                int(scol[u_pos, v_pos, 0]),
                int(scol[u_pos, v_pos, 1]),
                int(scol[u_pos, v_pos, 2]),
            )
            span = 1
            while v_pos + span < width and slab[u_pos, v_pos + span] and not seen[u_pos, v_pos + span]:
                other = (
                    int(scol[u_pos, v_pos + span, 0]),
                    int(scol[u_pos, v_pos + span, 1]),
                    int(scol[u_pos, v_pos + span, 2]),
                )
                if other != tone:
                    break
                span += 1
            rise = 1
            while u_pos + rise < height:
                ok = True
                for step in range(span):
                    if not slab[u_pos + rise, v_pos + step] or seen[u_pos + rise, v_pos + step]:
                        ok = False
                        break
                    other = (
                        int(scol[u_pos + rise, v_pos + step, 0]),
                        int(scol[u_pos + rise, v_pos + step, 1]),
                        int(scol[u_pos + rise, v_pos + step, 2]),
                    )
                    if other != tone:
                        ok = False
                        break
                if not ok:
                    break
                rise += 1
            seen[u_pos:u_pos + rise, v_pos:v_pos + span] = True
            found.append((u_pos, v_pos, rise, span, tone))
            v_pos += span
    return found


def greedy_mesh(mask, cols, origin):
    dims = mask.shape
    verts = []
    faces = []
    tones = []
    for axis in range(3):
        du = (axis + 1) % 3
        dv = (axis + 2) % 3
        count = dims[axis]
        for sign in (1, -1):
            for depth in range(count):
                here = _orient(_plane(mask, axis, depth), axis)
                if not here.any():
                    continue
                neighbor = depth + sign
                if neighbor < 0 or neighbor >= count:
                    outside = np.ones_like(here, dtype=bool)
                else:
                    outside = ~_orient(_plane(mask, axis, neighbor), axis)
                slab = here & outside
                if not slab.any():
                    continue
                scol = _orient(_plane(cols, axis, depth), axis)
                face_depth = depth + 1 if sign > 0 else depth

                def corner(u_pos, v_pos, face_depth=face_depth):
                    point = [0, 0, 0]
                    point[axis] = face_depth
                    point[du] = u_pos
                    point[dv] = v_pos
                    return (
                        point[0] + origin[0],
                        point[1] + origin[1],
                        point[2] + origin[2],
                    )

                for u_pos, v_pos, rise, span, tone in _rects(slab, scol):
                    p00 = corner(u_pos, v_pos)
                    p_u = corner(u_pos + rise, v_pos)
                    p_uv = corner(u_pos + rise, v_pos + span)
                    p_v = corner(u_pos, v_pos + span)
                    base = len(verts)
                    verts.extend((p00, p_u, p_uv, p_v))
                    if sign > 0:
                        faces.append((base, base + 1, base + 2, base + 3))
                    else:
                        faces.append((base, base + 3, base + 2, base + 1))
                    tones.append(tone)
    return verts, faces, tones


def paint_mesh(mesh, tones):
    attr = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    index = 0
    for tone in tones:
        color = (tone[0] / 255.0, tone[1] / 255.0, tone[2] / 255.0, 1.0)
        for _ in range(4):
            attr.data[index].color = color
            index += 1


# Review shots only. The live body stays one skin color.
# Left and right differ so the join is visible. Lighter faces are toward -Y.
REVIEW_PARTS = {
    "FemaleHead": (232, 176, 128),
    "FemaleNeck": (240, 216, 160),
    "FemaleChest": (196, 88, 104),
    "FemalePelvis": (176, 112, 72),
    "FemaleUpperArmR": (88, 140, 208),
    "FemaleUpperArmL": (48, 96, 168),
    "FemaleForearmR": (128, 176, 224),
    "FemaleForearmL": (72, 128, 184),
    "FemaleHandR": (176, 208, 232),
    "FemaleHandL": (136, 176, 208),
    "FemaleThighR": (88, 176, 104),
    "FemaleThighL": (48, 136, 72),
    "FemaleShinR": (144, 200, 120),
    "FemaleShinL": (96, 168, 88),
    "FemaleFootR": (208, 168, 88),
    "FemaleFootL": (176, 136, 64),
}


def apply_review_style(enabled):
    """Part colors and a front-to-back shade. False restores flat skin."""
    skin = (SKIN_C[0] / 255.0, SKIN_C[1] / 255.0, SKIN_C[2] / 255.0, 1.0)
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.data is None:
            continue
        attr = obj.data.color_attributes.get("Col")
        if attr is None:
            continue
        if not enabled:
            for corner in attr.data:
                corner.color = skin
            continue
        base = REVIEW_PARTS.get(obj.name, SKIN_C)
        world = obj.matrix_world
        for poly in obj.data.polygons:
            total = 0.0
            for vertex_index in poly.vertices:
                total += (world @ obj.data.vertices[vertex_index].co).y
            shade = 1.0 - (total / len(poly.vertices) + 0.05) / 0.35
            shade = max(0.42, min(1.0, shade))
            color = (
                base[0] / 255.0 * shade,
                base[1] / 255.0 * shade,
                base[2] / 255.0 * shade,
                1.0,
            )
            for loop_index in poly.loop_indices:
                attr.data[loop_index].color = color


def add_mesh(name, vox, origin, socket, collection):
    if vox is None or not vox.mask.any():
        return None
    verts, faces, tones = greedy_mesh(vox.mask, vox.col, origin)
    if not faces:
        return None
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    paint_mesh(mesh, tones)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = socket
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Identity(4)
    for poly in mesh.polygons:
        poly.use_smooth = False
    if name in HIDDEN:
        obj.hide_set(True)
        obj.hide_render = True
    return obj


def add_socket(name, world, parent, collection):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 4
    collection.objects.link(empty)
    empty.parent = parent
    bpy.context.view_layer.update()
    empty.matrix_world = world
    bpy.context.view_layer.update()
    return empty


def bust_offset(z_pos):
    span = abs(z_pos - 150) / 16.0
    if span >= 1.0:
        return 0.0
    return -4.0 * (1.0 - span * span)


def coat_profile(z_pos):
    # z, cx, cy, rx, ry. Depth is estimated under the side span.
    cy, rx, ry = lerp_keys(z_pos, (
        (106, -2.0, 42.0, 18.0),
        (124, -3.0, 34.0, 17.0),
        (140, -4.0, 26.0, 15.0),
        (156, -4.0, 22.0, 14.0),
        (168, -4.0, 16.0, 12.0),
    ))
    return 0.0, cy + bust_offset(z_pos), rx, ry


def body_profile(z_pos):
    # cy, rx, ry. Bust at z148 is the reference ribcage (about 40 wide)
    # and leads the belly. The shoulder caps, not this disc, reach the arms.
    cy, rx, ry = lerp_keys(z_pos, (
        (112, -2.0, 16.0, 13.0),
        (124, -4.0, 16.0, 14.0),
        (136, -8.0, 18.0, 16.0),
        (148, -10.0, 20.0, 18.0),
        (158, -6.0, 17.0, 14.0),
        (168, -3.0, 14.0, 11.0),
        (176, -4.0, 11.0, 9.0),
        (186, -5.0, 8.0, 7.0),
    ))
    return 0.0, cy, rx, ry


def pelvis_profile(z_pos):
    # Hip under the waist. The back of this disc is the seat.
    cy, rx, ry = lerp_keys(z_pos, (
        (100, 2.0, 24.0, 16.0),
        (106, 0.0, 20.0, 15.0),
        (112, -2.0, 16.0, 13.0),
    ))
    return 0.0, cy, rx, ry


def photo_front(image, world, x_pos, y_pos, z_pos, fallback):
    if world is None:
        wx, wz = x_pos, z_pos
    else:
        wx, _, wz = point_of(world, x_pos, y_pos, z_pos)
    color = sample(image, CX - wx, GROUND - wz)
    return fallback if color is None else color


def build_coat(image, colors):
    vox = Voxels(-50, 50, -28, 24, 104, 172)
    for z_pos in range(106, 169):
        cx, cy, rx, ry = coat_profile(z_pos)
        vox.fill_disc(z_pos, cx, cy, rx, ry, COAT_DARK, shell=3)
    for z_pos in range(106, 109):
        cx, cy, rx, ry = coat_profile(z_pos)
        vox.fill_disc(z_pos, cx, cy, max(1.0, rx - 3), max(1.0, ry - 3), COAT_DARK, shell=0)
    for z_pos in range(160, 169):
        vox.clear_disc(z_pos, 0.0, -4.0, 8.0, 8.0)

    def front_at(x_pos, y_pos, z_pos):
        return photo_front(image, None, x_pos, y_pos, z_pos, COAT_C)

    def back_at(x_pos, y_pos, z_pos):
        del y_pos
        return colors[(x_pos + z_pos) % len(colors)]

    vox.paint_ends(front_at, back_at)
    return vox


def fill_cord(vox, start, end, r0, r1, steps):
    """Rounded ridge from start to end. Used for the trapezius, which is a slope."""
    x0, y0, z0 = start
    x1, y1, z1 = end
    for step in range(steps + 1):
        tee = step / float(steps)
        radius = r0 + (r1 - r0) * tee
        vox.fill_ellipsoid(
            x0 + (x1 - x0) * tee,
            y0 + (y1 - y0) * tee,
            z0 + (z1 - z0) * tee,
            radius,
            radius * 0.75,
            radius * 0.85,
            SKIN_C,
        )


def build_chest():
    vox = Voxels(-42, 42, -40, 22, 104, 200)
    for z_pos in range(112, 187):
        cx, cy, rx, ry = body_profile(z_pos)
        vox.fill_disc(z_pos, cx, cy, rx, ry, SKIN_C, shell=0)
    # Eight voxels from the narrow yoke into the throat.
    for z_pos in range(186, 195):
        tee = (z_pos - 186) / 8.0
        curve = tee * tee * (3.0 - 2.0 * tee)
        rx = 8.0 + (7.0 - 8.0) * curve
        ry = 7.0 + (6.0 - 7.0) * curve
        cy = -5.0 + (-6.0 - -5.0) * curve
        vox.fill_disc(z_pos, 0.0, cy, rx, ry, SKIN_C, shell=0)
    for sign in (-1, 1):
        # Round cap on the arm top. Inner edge meets the chest. Outer edge
        # meets the arm. It does not stay wide down the ribcage.
        vox.fill_ellipsoid(sign * 26.0, -3.0, 166, 13.0, 9.0, 9.0, SKIN_C)
    return vox


def build_collar(image):
    vox = Voxels(-16, 16, -18, 8, 164, 180)
    for z_pos in range(166, 179):
        vox.fill_disc(z_pos, 0.0, -6.0, 11.0, 9.0, SKIN_C, shell=0)

    def front_at(x_pos, y_pos, z_pos):
        return photo_front(image, None, x_pos, y_pos, z_pos, SKIN_C)

    vox.paint_ends(front_at, None)
    return vox


def build_neck():
    """Throat only. Width matches the band core on the front cell (about 14)."""
    vox = Voxels(-10, 10, -14, 8, 192, 206)
    for z_pos in range(194, 204):
        vox.fill_disc(z_pos, 0.0, -6.0, 7.0, 6.0, SKIN_C, shell=0)
    vox.fill_ellipsoid(0.0, -10.0, 198, 4.0, 3.0, 3.5, SKIN_C)
    return vox


def build_band(colors):
    vox = Voxels(-20, 20, -18, 14, 176, 196)
    for z_pos in range(178, 195):
        vox.fill_disc(z_pos, 0.0, -4.0, 16.0, 12.0, BAND_DARK, shell=5)

    def pick(x_pos, y_pos, z_pos):
        del y_pos
        return colors[(x_pos * 3 + z_pos) % len(colors)]

    vox.paint_ends(pick, pick)
    return vox


def build_head():
    """A face pad on a round cranium. The cheek plane matches the front skin."""
    skull = Voxels(-30, 30, -36, 20, 190, 238)
    for z_pos in range(196, 233):
        fcy, frx, fry = lerp_keys(z_pos, (
            (196, -16.0, 7.0, 6.0),
            (204, -16.0, 14.0, 8.0),
            (210, -16.0, 20.0, 10.0),
            (216, -15.0, 23.0, 10.0),
            (222, -14.0, 20.0, 9.0),
            (228, -10.0, 12.0, 7.0),
            (232, -6.0, 5.0, 4.0),
        ))
        ccy, crx, cry = lerp_keys(z_pos, (
            (196, -4.0, 6.0, 6.0),
            (204, -2.0, 12.0, 10.0),
            (210, 0.0, 16.0, 12.0),
            (218, 1.0, 18.0, 13.0),
            (224, 2.0, 16.0, 13.0),
            (230, 2.0, 11.0, 11.0),
            (232, 1.0, 7.0, 8.0),
        ))
        skull.fill_disc(z_pos, 0.0, fcy, frx, fry, SKIN_C, shell=0)
        skull.fill_disc(z_pos, 0.0, ccy, crx, cry, SKIN_C, shell=0)
    skull.fill_ellipsoid(0.0, -26.0, 210, 2.0, 3.5, 6.0, SKIN_C)
    skull.fill_ellipsoid(0.0, -20.0, 198, 4.0, 3.0, 3.0, SKIN_C)
    for sign in (-1, 1):
        skull.fill_ellipsoid(sign * 20.0, -1.0, 214, 3.5, 2.0, 4.5, SKIN_C)
    return skull


def build_pelvis():
    vox = Voxels(-40, 40, -32, 26, 78, 126)
    for z_pos in range(100, 113):
        cx, cy, rx, ry = pelvis_profile(z_pos)
        vox.fill_disc(z_pos, cx, cy, rx, ry, SKIN_C, shell=0)
    for sign in (-1, 1):
        # Round hip at the joint. The back of it is the seat, over the thigh.
        vox.fill_ellipsoid(sign * 14.0, 2.0, 102, 12.0, 13.0, 10.0, SKIN_C)
    return vox


def _radius_spec(radius_at, tee):
    spec = radius_at(tee)
    if len(spec) == 2:
        rx, ry = spec
        return rx, ry, 0.0, 0.0
    rx, ry, cx, cy = spec
    return rx, ry, cx, cy


def build_tube(length, radius_at, fill, pad, z_start=0):
    """Limb along local +Z. z_start below 0 sinks the root into the parent joint."""
    z0 = int(z_start)
    vox = Voxels(-pad, pad, -pad, pad, z0, length + pad)
    for z_pos in range(z0, length + 1):
        tee = min(1.0, max(0.0, z_pos / float(max(1, length))))
        rx, ry, cx, cy = _radius_spec(radius_at, tee)
        vox.fill_disc(z_pos, cx, cy, rx, ry, fill, shell=0)
    rx0, ry0, cx0, cy0 = _radius_spec(radius_at, 0.0)
    rx1, ry1, cx1, cy1 = _radius_spec(radius_at, 1.0)
    vox.fill_ellipsoid(cx0, cy0, z0, rx0, ry0, rx0, fill)
    vox.fill_ellipsoid(cx1, cy1, length, rx1, ry1, rx1, fill)
    return vox


def paint_tube(vox, world, image, colors, do_sample):
    def front_at(x_pos, y_pos, z_pos):
        if do_sample:
            return photo_front(image, world, x_pos, y_pos, z_pos, colors[0])
        return colors[(z_pos * 5 + x_pos * 3) % len(colors)]

    def back_at(x_pos, y_pos, z_pos):
        del x_pos, y_pos, z_pos
        return darken(colors[0], 2, 3)

    vox.paint_ends(front_at, back_at)


def build_hand(sign):
    """Palm, four separated fingers, and a thumb on the outer side."""
    vox = Voxels(-14, 14, -6, 5, -2, 18)
    for z_pos in range(0, 7):
        vox.fill_disc(z_pos, 0.0, 0.3, 6.0, 2.2, SKIN_C, shell=0)
    for fx, tip in ((-6.0, 14), (-2.0, 16), (2.0, 16), (6.0, 13)):
        for z_pos in range(6, tip + 1):
            vox.fill_disc(z_pos, fx, -0.2, 1.15, 1.0, SKIN_C, shell=0)
    outward = -sign
    for step, z_pos in enumerate(range(1, 8)):
        vox.fill_disc(z_pos, outward * (5.0 + step * 0.7), -1.4, 1.4, 1.2, SKIN_C, shell=0)
    return vox


def build_foot(palette_colors, sole):
    vox = Voxels(-10, 10, -10, 4, -8, 22)
    for z_pos in range(-5, 16):
        width = 8 if z_pos < 12 else 6
        vox.fill_disc(z_pos, 0.0, -4.0, width, 4.0, palette_colors[0], shell=0)
    for z_pos in range(16, 21):
        vox.fill_disc(z_pos, 0.0, -5.0, 5.0, 3.0, palette_colors[0], shell=0)
    # Disc axis is Z. The sole is the low local Y, painted below.
    columns = np.argwhere(vox.mask.any(axis=1))
    for ix, iz in columns:
        ys = np.flatnonzero(vox.mask[ix, :, iz])
        if len(ys) == 0:
            continue
        vox.col[ix, int(ys[0]), iz] = sole
        vox.col[ix, int(ys[-1]), iz] = palette_colors[(iz + ix) % len(palette_colors)]
    return vox


def clear_defaults():
    for obj in list(bpy.data.objects):
        if obj.name in {"Cube", "Light"} or obj.name.startswith("Female") or obj.name.startswith("Socket"):
            mesh = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh is not None and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
    female = bpy.data.collections.get("Female")
    if female is not None:
        bpy.data.collections.remove(female)


def frame_view(rig):
    for area in bpy.context.screen.areas:
        if area.type != "VIEW_3D":
            continue
        for space in area.spaces:
            if space.type != "VIEW_3D":
                continue
            space.shading.type = "SOLID"
            space.shading.color_type = "VERTEX"
            space.shading.light = "FLAT"
            space.clip_end = 5000
            region = space.region_3d
            region.view_perspective = "PERSP"
            region.view_location = Vector((0.0, 0.0, 1.15))
            region.view_distance = 3.4
            region.view_rotation = Euler((math.radians(74), 0.0, math.radians(38)), "XYZ").to_quaternion()
        area.tag_redraw()
    rig.location = (0.0, 0.0, 0.0)
    rig.scale = (0.01, 0.01, 0.01)


def _limb_pair(sign, upper_dir, fore_dir):
    shoulder = (sign * SHOULDER[0], SHOULDER[1], SHOULDER[2])
    upper = Vector((sign * upper_dir.x, upper_dir.y, upper_dir.z))
    fore = Vector((sign * fore_dir.x, fore_dir.y, fore_dir.z))
    elbow = Vector(shoulder) + upper * UPPER_LEN
    wrist = elbow + fore * FORE_LEN
    return shoulder, elbow, wrist, upper, fore


def main():
    clear_defaults()
    # Nearly straight hang from the pauldron. A small elbow so the arm is not locked.
    upper_dir = Vector((0.04, 0.0, -1.0)).normalized()
    fore_dir = Vector((-0.02, -0.04, -0.99)).normalized()
    right = _limb_pair(1, upper_dir, fore_dir)
    left = _limb_pair(-1, upper_dir, fore_dir)

    collection = bpy.data.collections.new("Female")
    bpy.context.scene.collection.children.link(collection)
    rig = bpy.data.objects.new("FemaleRig", None)
    rig.empty_display_type = "PLAIN_AXES"
    rig.empty_display_size = 12
    collection.objects.link(rig)
    bpy.context.view_layer.update()

    worlds = {}
    sockets = {}

    def socket(name, world, parent_name):
        parent = rig if parent_name is None else sockets[parent_name]
        worlds[name] = world
        sockets[name] = add_socket(name, world, parent, collection)
        return sockets[name]

    socket("SocketPelvis", translation(0, -2, HIP_Z), None)
    socket("SocketChest", translation(0, -4, 140), "SocketPelvis")
    socket("SocketNeck", translation(0, -4, 176), "SocketChest")
    socket("SocketHead", translation(0, -6, 200), "SocketNeck")

    for side, packed in (("R", right), ("L", left)):
        shoulder, elbow, wrist, upper, fore = packed
        socket("SocketShoulder" + side, frame(shoulder, upper, (0, 1, 0)), "SocketChest")
        socket("SocketElbow" + side, frame(tuple(elbow), fore, (0, 1, 0)), "SocketShoulder" + side)
        socket("SocketWrist" + side, frame(tuple(wrist), fore, (0, 1, 0)), "SocketElbow" + side)

    down = Vector((0.0, 0.0, -1.0))
    for side, sign in (("R", 1), ("L", -1)):
        hip = (sign * HIP_X, -2, HIP_Z)
        knee = (sign * HIP_X, -2, KNEE_Z)
        ankle = (sign * HIP_X, -2, ANKLE_Z)
        socket("SocketHip" + side, frame(hip, down, (0, 1, 0)), "SocketPelvis")
        socket("SocketKnee" + side, frame(knee, down, (0, 1, 0)), "SocketHip" + side)
        # Foot points forward (-Y). Local +Y is up.
        socket("SocketAnkle" + side, frame(ankle, (0, -1, 0), (0, 0, 1)), "SocketKnee" + side)

    made = []

    def place_world(name, vox, socket_name):
        origin_shift = worlds[socket_name].translation
        origin = (vox.x0 - origin_shift.x, vox.y0 - origin_shift.y, vox.z0 - origin_shift.z)
        obj = add_mesh(name, vox, origin, sockets[socket_name], collection)
        if obj is not None:
            made.append(obj.name)
            return int(vox.mask.sum())
        return 0

    def place_local(name, vox, socket_name):
        origin = (vox.x0, vox.y0, vox.z0)
        obj = add_mesh(name, vox, origin, sockets[socket_name], collection)
        if obj is not None:
            made.append(obj.name)
            return int(vox.mask.sum())
        return 0

    counts = {}
    counts["Head"] = place_world("FemaleHead", build_head(), "SocketHead")
    counts["Neck"] = place_world("FemaleNeck", build_neck(), "SocketNeck")
    counts["Chest"] = place_world("FemaleChest", build_chest(), "SocketChest")
    counts["Pelvis"] = place_world("FemalePelvis", build_pelvis(), "SocketPelvis")

    def arm_radius(tee):
        rx, ry = lerp_keys(tee, ((0.0, 7.0, 6.5), (1.0, 5.5, 5.0)))
        return rx, ry

    def fore_radius(tee):
        rx, ry = lerp_keys(tee, ((0.0, 5.2, 4.6), (1.0, 3.6, 3.2)))
        return rx, ry

    def thigh_radius(tee):
        # Pant taper: wide under the hip, narrower and forward at the knee.
        return lerp_keys(tee, (
            (0.00, 18.0, 16.0, 0.0, 4.0),
            (0.40, 14.0, 13.0, 0.0, 2.0),
            (0.75, 11.0, 11.0, 0.0, 0.0),
            (1.00, 10.0, 10.0, 0.0, -5.0),
        ))

    def shin_radius(tee):
        # Thinner than the thigh. A calf belly, then the ankle. No boot.
        return lerp_keys(tee, (
            (0.00, 8.0, 7.0, 0.0, -4.0),
            (0.35, 7.0, 10.0, 0.0, 2.0),
            (0.70, 5.5, 6.0, 0.0, 0.5),
            (1.00, 4.5, 4.5, 0.0, 0.0),
        ))

    for side, sign in (("R", 1), ("L", -1)):
        upper = build_tube(UPPER_LEN, arm_radius, SKIN_C, 12, z_start=-10)
        counts["UpperArm" + side] = place_local("FemaleUpperArm" + side, upper, "SocketShoulder" + side)
        fore = build_tube(FORE_LEN, fore_radius, SKIN_C, 10, z_start=-8)
        counts["Forearm" + side] = place_local("FemaleForearm" + side, fore, "SocketElbow" + side)
        counts["Hand" + side] = place_local(
            "FemaleHand" + side, build_hand(sign), "SocketWrist" + side,
        )

        thigh_len = HIP_Z - KNEE_Z
        shin_len = KNEE_Z - ANKLE_Z
        thigh = build_tube(thigh_len, thigh_radius, SKIN_C, 24, z_start=-12)
        thigh.fill_ellipsoid(0.0, -13.0, thigh_len, 11.0, 6.0, 6.0, SKIN_C)
        counts["Thigh" + side] = place_local("FemaleThigh" + side, thigh, "SocketHip" + side)
        counts["Shin" + side] = place_local(
            "FemaleShin" + side,
            build_tube(shin_len, shin_radius, SKIN_C, 16, z_start=-8),
            "SocketKnee" + side,
        )
        counts["Foot" + side] = place_local(
            "FemaleFoot" + side,
            build_foot([SKIN_C], darken(SKIN_C, 3, 4)),
            "SocketAnkle" + side,
        )

    frame_view(rig)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    shoulder, elbow, wrist, upper, fore = right
    check = point_of(worlds["SocketShoulderR"], 0, 0, UPPER_LEN)
    return {
        "ok": True,
        "pose": "base-mannequin",
        "objects": made,
        "counts": counts,
        "joints": {
            "shoulder_r": [round(v, 1) for v in shoulder],
            "elbow_r": [round(float(v), 1) for v in elbow],
            "wrist_r": [round(float(v), 1) for v in wrist],
            "upper_check": [round(v, 1) for v in check],
        },
        "blend": BLEND,
    }


if __name__ in ("__main__", "<run_path>"):
    try:
        RESULT = main()
    except Exception:
        RESULT = {"ok": False, "error": traceback.format_exc()}
