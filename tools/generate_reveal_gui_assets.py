import math
import os

import bpy


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(ROOT, "generated_assets", "reveal_gui")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_mat(name, color, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    mat.blend_method = "BLEND"
    mat.show_transparent_back = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Alpha"].default_value = color[3]
    bsdf.inputs["Roughness"].default_value = 0.34
    if emission_strength > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def setup_render(size):
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.render.film_transparent = True
    bpy.context.scene.render.resolution_x = size
    bpy.context.scene.render.resolution_y = size
    bpy.context.scene.render.fps = 24
    bpy.context.scene.view_settings.view_transform = "Standard"
    bpy.context.scene.view_settings.look = "Medium High Contrast"
    bpy.context.scene.view_settings.exposure = 0
    bpy.context.scene.view_settings.gamma = 1

    bpy.ops.object.camera_add(location=(0, 0, 6), rotation=(0, 0, 0))
    cam = bpy.context.object
    cam.name = "OrthoAssetCamera"
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.2
    bpy.context.scene.camera = cam

    bpy.ops.object.light_add(type="AREA", location=(0, 0, 4))
    light = bpy.context.object
    light.name = "SoftAssetLight"
    light.data.energy = 420
    light.data.size = 5


def render_asset(name, size, build_fn):
    clear_scene()
    setup_render(size)
    build_fn()
    bpy.context.scene.render.filepath = os.path.join(OUT_DIR, name)
    bpy.ops.render.render(write_still=True)


def add_disc(name, radius, mat, z=0):
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=radius, fill_type="TRIFAN", location=(0, 0, z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_ring(name, radius, thickness, mat, z=0):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radius,
        minor_radius=thickness,
        major_segments=128,
        minor_segments=8,
        location=(0, 0, z),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def add_rounded_rect_mesh(name, width, height, radius, mat, z=0):
    verts = []
    steps = 10
    centers = [
        (width / 2 - radius, height / 2 - radius, 0),
        (-width / 2 + radius, height / 2 - radius, math.pi / 2),
        (-width / 2 + radius, -height / 2 + radius, math.pi),
        (width / 2 - radius, -height / 2 + radius, math.pi * 1.5),
    ]
    for cx, cy, start in centers:
        for i in range(steps + 1):
            a = start + i * (math.pi / 2) / steps
            verts.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius, z))
    faces = [tuple(range(len(verts)))]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def add_star(name, radius, inner, mat, loc=(0, 0, 0)):
    verts = [(0, 0, 0)]
    faces = []
    for i in range(10):
        angle = math.radians(90 + i * 36)
        r = radius if i % 2 == 0 else inner
        verts.append((math.cos(angle) * r, math.sin(angle) * r, 0))
    for i in range(1, 11):
        faces.append((0, i, 1 if i == 10 else i + 1))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.data.materials.append(mat)
    return obj


def soft_radial_glow():
    for i in range(10, 0, -1):
        alpha = 0.035 + i * 0.012
        color = (1.0, 0.72, 0.12, alpha)
        add_disc(f"GlowLayer_{i}", i * 0.15, make_mat(f"GlowMat_{i}", color, 1.1))


def rarity_burst_ring():
    add_ring("OuterGoldRing", 0.98, 0.035, make_mat("OuterGold", (1, 0.64, 0.08, 0.92), 1.6))
    add_ring("InnerWhiteRing", 0.67, 0.026, make_mat("InnerWhite", (1, 0.95, 0.76, 0.8), 1.2))
    for i in range(16):
        ray = add_rounded_rect_mesh(f"BurstRay_{i}", 0.055, 0.55, 0.025, make_mat(f"RayMat_{i}", (1, 0.78, 0.18, 0.55), 1.2))
        ray.location.y = 0.9
        ray.rotation_euler.z = math.radians(i * 22.5)


def sparkle_star():
    add_star("SparkleStar", 1.0, 0.42, make_mat("SparkleWhite", (1, 0.95, 0.70, 0.95), 1.8))
    add_star("SparkleCore", 0.45, 0.20, make_mat("SparkleCore", (1, 1, 1, 0.95), 2.0), (0, 0, 0.02))


def shine_streak():
    mat = make_mat("Shine", (1, 1, 1, 0.78), 1.4)
    add_rounded_rect_mesh("DiagonalShine", 0.22, 2.2, 0.11, mat).rotation_euler.z = math.radians(-25)
    add_rounded_rect_mesh("ThinBlueShine", 0.06, 2.0, 0.03, make_mat("BlueShine", (0.35, 0.78, 1, 0.45), 1.1)).rotation_euler.z = math.radians(-25)


def reveal_podium():
    add_rounded_rect_mesh("PodiumTop", 2.2, 0.62, 0.31, make_mat("PodiumTopMat", (0.24, 0.55, 1.0, 0.96), 0.35), 0.02)
    base = add_rounded_rect_mesh("PodiumBase", 1.72, 0.46, 0.23, make_mat("PodiumBaseMat", (0.15, 0.32, 0.86, 0.95), 0.2), 0.01)
    base.location.y = -0.42
    add_disc("PodiumGlow", 1.0, make_mat("PodiumGlowMat", (0.35, 0.82, 1.0, 0.24), 1.0), -0.01).scale.y = 0.24


def reveal_card_glow():
    add_rounded_rect_mesh("CardGlowBack", 2.25, 2.75, 0.32, make_mat("CardGlowBackMat", (1.0, 0.77, 0.18, 0.35), 1.2))
    add_rounded_rect_mesh("CardGlowFront", 1.85, 2.35, 0.26, make_mat("CardGlowFrontMat", (1.0, 0.96, 0.72, 0.22), 0.8), 0.02)


def egg_crack_flash():
    add_disc("FlashCore", 0.72, make_mat("FlashCoreMat", (1, 1, 1, 0.85), 2.0))
    for i in range(8):
        shard = add_rounded_rect_mesh(f"FlashShard_{i}", 0.08, 0.8, 0.04, make_mat(f"ShardMat_{i}", (1, 0.88, 0.25, 0.75), 1.8), 0.02)
        shard.location.y = 0.56
        shard.rotation_euler.z = math.radians(i * 45)


def new_badge():
    badge = add_rounded_rect_mesh("NewBadgeBody", 1.9, 0.74, 0.28, make_mat("NewBadgeBodyMat", (1.0, 0.23, 0.34, 0.98), 0.6))
    badge.rotation_euler.z = math.radians(-8)
    add_rounded_rect_mesh("NewBadgeHighlight", 1.45, 0.16, 0.08, make_mat("NewBadgeHighlightMat", (1, 1, 1, 0.35), 0.8), 0.02).location.y = 0.16


def tap_to_continue_panel():
    add_rounded_rect_mesh("TapPanel", 2.25, 0.56, 0.28, make_mat("TapPanelMat", (0.08, 0.11, 0.18, 0.72), 0.2))
    add_rounded_rect_mesh("TapPanelStroke", 2.05, 0.40, 0.20, make_mat("TapPanelInnerMat", (1, 1, 1, 0.12), 0.4), 0.02)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    assets = [
        ("soft_radial_glow.png", 1024, soft_radial_glow),
        ("rarity_burst_ring.png", 1024, rarity_burst_ring),
        ("sparkle_star.png", 512, sparkle_star),
        ("shine_streak.png", 512, shine_streak),
        ("reveal_podium.png", 1024, reveal_podium),
        ("reveal_card_glow.png", 1024, reveal_card_glow),
        ("egg_crack_flash.png", 1024, egg_crack_flash),
        ("new_badge.png", 512, new_badge),
        ("tap_to_continue_panel.png", 1024, tap_to_continue_panel),
    ]
    for filename, size, builder in assets:
        render_asset(filename, size, builder)


if __name__ == "__main__":
    main()
