"""Helpers for building Mail Animals! hero models in the KayKit style (docs/ART_BIBLE.md, docs/ASSET_PLAN.md).

The look comes from three things:
  * chunky shapes with soft bevels (every block gets a bevel modifier, applied)
  * one shared texture: the KayKit City Builder atlas (art/export/kaykit/textures/citybits_texture.png, already
    uploaded to the game as Config.Atlases.City). Each part is UV-mapped onto one colour swatch.
  * a vertical gradient inside each swatch: the higher a vertex is on the part, the lighter its colour
    (exactly how KayKit shades), so nothing looks flat.

A model is built from parts. Every part belongs to a GROUP ("Stone", "Water", "Metal"...); at export the parts of
a group are joined into one mesh named "<Model>__<Group>", so a whole model is a handful of MeshParts in Roblox.
tools/import/split_pack.luau turns those back into one Model per hero.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS = os.path.join(REPO, "art", "export", "kaykit", "textures", "citybits_texture.png")
EXPORT = os.path.join(REPO, "art", "export", "hero")
PREVIEWS = os.path.join(REPO, "art", "previews", "hero")
SCENE = "MailAnimals_Build"

# The City atlas is 8 columns x 4 rows of 128 x 256 px swatches, each a top-to-bottom gradient.
# (column, row): what it looks like
SWATCH = {
    "Ink": (0, 0),  # near-black navy
    "White": (1, 0),  # white to light grey
    "Steel": (2, 0),  # light grey to mid grey
    "Slate": (3, 0),  # dark grey
    "Charcoal": (4, 0),
    "Brick": (5, 0),  # salmon brick
    "BrickDark": (6, 0),  # red-brown brick
    "Orange": (7, 0),  # orange to rust
    "Sky": (0, 1),  # light blue
    "Blue": (1, 1),  # strong blue to navy
    "SlateBlue": (2, 1),
    "Gold": (3, 1),  # yellow-gold to brown
    "Red": (4, 1),
    "Sand": (5, 1),  # tan
    "WarmGrey": (6, 1),
    "Taupe": (7, 1),
    "Olive": (0, 2),
    "Teal": (1, 2),
    "Green": (2, 2),
    "DeepGreen": (3, 2),
    "Grey": (4, 2),  # white to black
    "Cream": (5, 2),  # ivory to tan
    "Magenta": (6, 2),
    "Coral": (7, 2),
    "Amber": (2, 3),  # light orange-yellow
}


def swatch_uv(name: str):
    """(u, v_top, v_bottom) of a swatch, staying clear of its edges and the darker strip some swatches have."""
    col, row = SWATCH[name]
    u = (col * 128 + 52) / 1024
    v_top = 1 - (row * 256 + 10) / 1024
    v_bottom = 1 - ((row + 1) * 256 - 10) / 1024
    return u, v_top, v_bottom


# ------------------------------------------------------------------------------------------------------------
# Scene


def fresh_scene():
    """An empty build scene of our own (the owner's other scenes are left alone)."""
    old = bpy.data.scenes.get(SCENE)
    if old:
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        scene = old
    else:
        scene = bpy.data.scenes.new(SCENE)
    for window in bpy.context.window_manager.windows:
        window.scene = scene
    scene.unit_settings.system = "METRIC"
    return scene


def atlas_material(see_through: bool = False):
    """The atlas material. see_through: a clear version for water (only for the preview renders: in Roblox the
    game sets the Water part's transparency)."""
    name = "KK_AtlasClear" if see_through else "KK_Atlas"
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(ATLAS, check_existing=True)
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.65
    if see_through:
        bsdf.inputs["Alpha"].default_value = 0.55
        bsdf.inputs["Roughness"].default_value = 0.1
        mat.surface_render_method = "BLENDED"
    return mat


# ------------------------------------------------------------------------------------------------------------
# Parts

PARTS = []  # (object, group)


def _finish(obj, group: str, color: str, bevel: float, light=(0.05, 0.75), segments: int = 2):
    """Bevel, paint onto a swatch with the height gradient, and remember the part's group."""
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        mod.harden_normals = False
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    paint(obj, color, light)
    obj.data.materials.clear()
    obj.data.materials.append(atlas_material(group == "Water"))
    PARTS.append((obj, group))
    return obj


def paint(obj, color: str, light=(0.05, 0.75)):
    """UV-map every face onto a swatch: u fixed, v from the vertex's height on this part (top = light)."""
    u, v_top, v_bottom = swatch_uv(color)
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    world = obj.matrix_world
    zs = [(world @ v.co).z for v in mesh.vertices]
    z0, z1 = min(zs), max(zs)
    span = max(z1 - z0, 1e-4)
    lo, hi = light
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            t = (zs[vi] - z0) / span  # 0 at the bottom, 1 at the top
            f = lo + (1 - t) * (hi - lo)  # how far down the gradient
            uv[li].uv = (u, v_top + (v_bottom - v_top) * f)


def box(name, size, loc, group="Stone", color="Cream", bevel=0.12, rot=(0, 0, 0), light=(0.05, 0.75)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, group, color, bevel, light)


def prism(name, sides, r_bottom, r_top, height, loc, group="Stone", color="Cream", bevel=0.12, spin=0.0,
          light=(0.05, 0.75), rot=None):
    """An n-sided column / cone frustum standing on loc. rot: lay it some other way (then loc is its centre)."""
    if rot is None:
        bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r_bottom, radius2=r_top, depth=height,
                                        location=(loc[0], loc[1], loc[2] + height / 2), rotation=(0, 0, spin))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r_bottom, radius2=r_top, depth=height,
                                        location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return _finish(obj, group, color, bevel, light)


def cylinder_x(name, radius, length, loc, group="Metal", color="Steel", sides=12, bevel=0.04, light=(0.05, 0.6)):
    """A round bar lying along X (rollers, axles)."""
    return prism(name, sides, radius, radius, length, loc, group, color, bevel, light=light,
                 rot=(0, math.pi / 2, 0))


def cylinder_y(name, radius, length, loc, group="Metal", color="Steel", sides=12, bevel=0.04, light=(0.05, 0.6)):
    """A round bar lying along Y (front to back)."""
    return prism(name, sides, radius, radius, length, loc, group, color, bevel, light=light,
                 rot=(math.pi / 2, 0, 0))


def ball(name, radius, loc, group="Trim", color="Red", subdivisions=2, light=(0.0, 0.5)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return _finish(obj, group, color, 0, light)


def finish(model: str, views=((35, 25), (215, 18))):
    """Join the parts, export the FBX and render previews; prints a one-line summary."""
    parts = joined_groups(model)
    path = export_fbx(model, parts)
    shots = render_preview(model, parts, views=views)
    print(f"BUILT {model}: {len(parts)} parts {[o.name.split('__')[-1] for o in parts]}, "
          f"{triangles(parts)} tris -> {os.path.basename(path)}; previews {[os.path.basename(p) for p in shots]}")
    return parts


def ring_blocks(name, sides, r_mid, thickness, height, z, group="Stone", color="Cream", gap=0.06, bevel=0.1,
                spin=0.0, light=(0.05, 0.75), every=1):
    """An n-sided ring made of separate bevelled blocks (one per side), like a stone wall course."""
    # Each block is as long as the side at its OUTER face, so neighbours meet at the corners (no dark gaps)
    side = 2 * (r_mid + thickness / 2) * math.tan(math.pi / sides)
    out = []
    for i in range(0, sides, every):
        a = spin + (i + 0.5) * 2 * math.pi / sides
        x, y = math.cos(a) * r_mid, math.sin(a) * r_mid
        out.append(box(f"{name}{i}", (thickness, side - gap, height), (x, y, z + height / 2), group, color, bevel,
                       rot=(0, 0, a), light=light))
    return out


def masonry_ring(name, sides, r_mid, thickness, height, z, courses=2, per_side=(2, 3), group="Stone",
                 color="Sand", gap=0.07, bevel=0.1, spin=0.0, light=(0.1, 0.7), jitter=0.06):
    """A wall ring built from stacked courses of stone blocks with staggered joints (real masonry, not one slab
    per side). per_side: blocks per side in alternating courses."""
    out = []
    course_h = height / courses
    for c in range(courses):
        count = per_side[c % len(per_side)]
        zc = z + c * course_h
        for i in range(sides):
            a = spin + (i + 0.5) * 2 * math.pi / sides
            side = 2 * (r_mid + thickness / 2) * math.tan(math.pi / sides)
            along = (-math.sin(a), math.cos(a))
            for k in range(count):
                length = side / count
                offset = -side / 2 + (k + 0.5) * length
                x = math.cos(a) * r_mid + along[0] * offset
                y = math.sin(a) * r_mid + along[1] * offset
                wobble = ((i * 7 + k * 3 + c * 5) % 5 - 2) * jitter * 0.5
                out.append(box(f"{name}{c}_{i}_{k}", (thickness + wobble * 0.5, length - gap, course_h - gap),
                               (x, y, zc + course_h / 2), group, color, bevel, rot=(0, 0, a), light=light))
    return out


def stream(name, points, thickness=0.18, group="Water", color="Sky", light=(0.0, 0.3)):
    """A stylized water stream: a smooth tube through the given points (a falling arc from a spout)."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = thickness
    curve.bevel_resolution = 2
    curve.resolution_u = 8
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, p in zip(spline.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    return _finish(obj, group, color, 0, light)


def gable(name, width, depth, rise, loc, group="Roof", color="Red", bevel=0.1, light=(0.1, 0.7), rot_z=0.0):
    """A solid gable (triangular prism): `width` along X, ridge along Y, `rise` tall, base at loc."""
    import bmesh as _bm

    mesh = bpy.data.meshes.new(name)
    bm = _bm.new()
    w, d = width / 2, depth / 2
    verts = [bm.verts.new(v) for v in [(-w, -d, 0), (w, -d, 0), (0, -d, rise), (-w, d, 0), (w, d, 0), (0, d, rise)]]
    for face in [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]:
        bm.faces.new([verts[i] for i in face])
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (0, 0, rot_z)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return _finish(obj, group, color, bevel, light)


def shingles(name, width, depth, rise, base_z, rows=6, overhang=0.6, group="Roof", color="Red",
             light=(0.05, 0.7), thickness=0.28, center=(0, 0)):
    """Rows of overlapping roof boards on both slopes of a gable (ridge along Y), for a tiled-roof look."""
    half = width / 2 + overhang
    slope = math.atan2(rise, width / 2)
    length = math.hypot(half, rise * half / (width / 2))
    out = []
    for side in (-1, 1):
        for r in range(rows):
            t0 = r / rows
            seg = length / rows * 1.18
            along = (t0 + 0.5 / rows) * length
            x = center[0] + side * (half - math.cos(slope) * along)
            z = base_z - overhang * math.tan(slope) + math.sin(slope) * along + thickness * 0.6
            out.append(box(f"{name}{side}_{r}", (seg, depth + overhang * 2, thickness), (x, center[1], z), group,
                           color, 0.08, rot=(0, side * slope, 0), light=light))
    return out


def text3d(name, body, size, loc, depth=0.12, group="Metal", color="Gold", font="ariblk.ttf", rot=(math.pi / 2, 0, 0),
           light=(0.0, 0.45)):
    """Chunky 3D letters (Arial Black), standing up, facing -Y by default."""
    bpy.ops.object.text_add(location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.body = body
    obj.data.size = size
    obj.data.extrude = depth
    obj.data.bevel_depth = 0.0
    obj.data.resolution_u = 2  # (coarse curves: smooth enough at this size, a tenth of the triangles)
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    path = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", font)
    if os.path.exists(path):
        obj.data.font = bpy.data.fonts.load(path, check_existing=True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    return _finish(obj, group, color, 0, light)


def ngon_slab(name, sides, radius, height, z, group="Water", color="Sky", bevel=0.0, spin=0.0, light=(0.1, 0.5)):
    return prism(name, sides, radius, radius, height, (0, 0, z), group, color, bevel, spin, light)


# ------------------------------------------------------------------------------------------------------------
# Output


def joined_groups(model: str):
    """Join each group's parts into one mesh named <model>__<group>. Returns the joined objects."""
    by_group = {}
    for obj, group in PARTS:
        by_group.setdefault(group, []).append(obj)
    out = []
    for group, objs in by_group.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = f"{model}__{group}"
        joined.data.name = joined.name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        out.append(joined)
    PARTS.clear()
    return out


def triangles(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def export_fbx(model: str, objs):
    os.makedirs(EXPORT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = os.path.join(EXPORT, f"{model}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
        path_mode="STRIP",
        embed_textures=False,
    )
    return path


def render_preview(model: str, objs, views=((35, 25), (215, 18)), size=(1000, 760)):
    """Renders the model from a few angles (Eevee, soft sun, sky-blue world) into art/previews/hero/."""
    scene = bpy.context.scene
    os.makedirs(PREVIEWS, exist_ok=True)
    lo = Vector((min((o.matrix_world @ Vector(c)).x for o in objs for c in o.bound_box),
                 min((o.matrix_world @ Vector(c)).y for o in objs for c in o.bound_box),
                 min((o.matrix_world @ Vector(c)).z for o in objs for c in o.bound_box)))
    hi = Vector((max((o.matrix_world @ Vector(c)).x for o in objs for c in o.bound_box),
                 max((o.matrix_world @ Vector(c)).y for o in objs for c in o.bound_box),
                 max((o.matrix_world @ Vector(c)).z for o in objs for c in o.bound_box)))
    center = (lo + hi) / 2
    radius = (hi - lo).length / 2

    world = scene.world or bpy.data.worlds.new("MA_World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.75, 0.95, 1)
    bg.inputs["Strength"].default_value = 1.1

    sun = bpy.data.objects.get("MA_Sun")
    if not sun:
        sun = bpy.data.objects.new("MA_Sun", bpy.data.lights.new("MA_Sun", "SUN"))
        scene.collection.objects.link(sun)
    sun.data.energy = 3.4
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))

    ground = bpy.data.objects.get("MA_Ground")
    if not ground:
        bpy.ops.mesh.primitive_plane_add(size=1, location=(center.x, center.y, lo.z - 0.01))
        ground = bpy.context.active_object
        ground.name = "MA_Ground"
        mat = bpy.data.materials.new("MA_GroundMat")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.55, 0.45, 1)
        ground.data.materials.append(mat)
    ground.scale = (radius * 6, radius * 6, 1)

    cam = bpy.data.objects.get("MA_Camera")
    if not cam:
        cam = bpy.data.objects.new("MA_Camera", bpy.data.cameras.new("MA_Camera"))
        scene.collection.objects.link(cam)
    cam.data.lens = 45
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - High Contrast"
    # A player for scale: 3.1 studs tall (players are drawn at 60%), standing at the front-right
    figure = bpy.data.objects.get("MA_ScaleFigure")
    if not figure:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.55, depth=3.1)
        figure = bpy.context.active_object
        figure.name = "MA_ScaleFigure"
        mat = bpy.data.materials.new("MA_FigureMat")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.3, 0.3, 1)
        figure.data.materials.append(mat)
    figure.location = (hi.x + 1.5, lo.y - 1.5, lo.z + 1.55)
    paths = []
    for index, (yaw, pitch) in enumerate(views):
        a, p = math.radians(yaw), math.radians(pitch)
        distance = radius * 3.0
        cam.location = center + Vector((math.cos(a) * math.cos(p), math.sin(a) * math.cos(p), math.sin(p))) * distance
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(PREVIEWS, f"{model}_{index + 1}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths
