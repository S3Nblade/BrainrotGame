"""Generate placeholder BrainrotGame starter assets in Blender.

Run inside Blender:
    blender --background --python assets/blender/scripts/create_starter_brainrots.py

The generated model names intentionally match BrainrotConfig.ModelName values.
These are asset-ready placeholders, not final art.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
EXPORT_ROOT = ROOT / "exports"
MODEL_EXPORTS = EXPORT_ROOT / "models"
ANIMATION_EXPORTS = EXPORT_ROOT / "animations"
VFX_EXPORTS = EXPORT_ROOT / "vfx"

for folder in (MODEL_EXPORTS, ANIMATION_EXPORTS, VFX_EXPORTS):
    folder.mkdir(parents=True, exist_ok=True)


BRAINROTS = [
    ("BR_WobbleNugget", "Wobble Nugget", (1.0, 0.72, 0.24), "nugget"),
    ("BR_GoofyCone", "Goofy Cone", (1.0, 0.42, 0.18), "cone"),
    ("BR_TinyBloop", "Tiny Bloop", (0.24, 0.72, 1.0), "blob"),
    ("BR_SneakyPickle", "Sneaky Pickle", (0.16, 0.78, 0.25), "pickle"),
    ("BR_DizzyDonut", "Dizzy Donut", (1.0, 0.55, 0.75), "donut"),
    ("BR_BananaGoblin", "Banana Goblin", (1.0, 0.88, 0.12), "banana"),
    ("BR_ShyToaster", "Shy Toaster", (0.82, 0.72, 0.56), "toaster"),
    ("BR_TurboMeatball", "Turbo Meatball", (0.72, 0.24, 0.16), "meatball"),
    ("BR_GlitchyCapybara", "Glitchy Capybara", (0.55, 0.42, 0.31), "capybara"),
    ("BR_BubbleLizard", "Bubble Lizard", (0.18, 0.9, 0.75), "lizard"),
    ("BR_GoldenSpaghettiKing", "Golden Spaghetti King", (1.0, 0.76, 0.12), "spaghetti"),
    ("BR_CosmicBrainFrog", "Cosmic Brain Frog", (0.46, 0.32, 1.0), "frog"),
]


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def material(name: str, color: tuple[float, float, float], roughness: float = 0.65) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1)
        bsdf.inputs["Roughness"].default_value = roughness
    return mat


def add_uv_sphere(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    return obj


def add_cube(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("SoftBevel", "BEVEL")
    bevel.width = 0.08
    bevel.segments = 5
    obj.modifiers.new("SoftShade", "WEIGHTED_NORMAL")
    return obj


def add_cone(name: str, location: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=radius, radius2=0.12, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_torus(name: str, location: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.18, major_segments=48, minor_segments=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler[0] = math.radians(90)
    obj.data.materials.append(mat)
    return obj


def add_face(parent_name: str, accent: bpy.types.Material, black: bpy.types.Material) -> list[bpy.types.Object]:
    left = add_uv_sphere(parent_name + "_LeftEye", (-0.22, -0.72, 1.68), (0.09, 0.035, 0.09), black)
    right = add_uv_sphere(parent_name + "_RightEye", (0.22, -0.72, 1.68), (0.09, 0.035, 0.09), black)
    mouth = add_cube(parent_name + "_Mouth", (0, -0.77, 1.42), (0.22, 0.025, 0.04), accent)
    return [left, right, mouth]


def make_brainrot(model_name: str, display_name: str, color: tuple[float, float, float], style: str) -> list[bpy.types.Object]:
    main = material(model_name + "_Main", color)
    accent = material(model_name + "_Accent", tuple(min(1.0, c + 0.18) for c in color))
    dark = material(model_name + "_Dark", (0.05, 0.06, 0.09))
    gold = material(model_name + "_Gold", (1.0, 0.72, 0.08))

    objects: list[bpy.types.Object] = []

    if style == "cone":
        objects.append(add_cone(model_name + "_Body", (0, 0, 1.05), 0.62, 1.75, main))
    elif style == "donut":
        objects.append(add_torus(model_name + "_Body", (0, 0, 1.35), main))
    elif style == "toaster":
        objects.append(add_cube(model_name + "_Body", (0, 0, 1.15), (0.68, 0.44, 0.58), main))
        objects.append(add_cube(model_name + "_Toast", (0, 0.02, 1.88), (0.46, 0.12, 0.28), accent))
    elif style == "banana":
        objects.append(add_cone(model_name + "_Body", (0, 0, 1.2), 0.42, 1.95, main))
        objects[-1].rotation_euler[2] = math.radians(11)
    elif style == "spaghetti":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.15), (0.58, 0.44, 0.58), main))
        for i in range(10):
            strand = add_cone(model_name + f"_Noodle_{i:02d}", (math.cos(i) * 0.32, math.sin(i) * 0.16, 1.95), 0.045, 0.72, gold)
            strand.rotation_euler[0] = math.radians(90 + i * 9)
            objects.append(strand)
        objects.append(add_cube(model_name + "_Crown", (0, 0, 2.36), (0.46, 0.12, 0.16), gold))
    elif style == "capybara":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.06), (0.75, 0.42, 0.44), main))
        objects.append(add_uv_sphere(model_name + "_Snout", (0, -0.58, 1.15), (0.28, 0.16, 0.18), accent))
    elif style == "lizard":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.05), (0.64, 0.34, 0.42), main))
        objects.append(add_cone(model_name + "_Tail", (0, 0.65, 0.86), 0.18, 0.88, accent))
        objects[-1].rotation_euler[0] = math.radians(72)
    elif style == "frog":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.05), (0.62, 0.42, 0.45), main))
        objects.append(add_uv_sphere(model_name + "_BrainDome", (0, -0.03, 1.74), (0.42, 0.32, 0.22), accent))
    else:
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.12), (0.58, 0.46, 0.52), main))

    if style in {"pickle", "blob", "nugget", "meatball"}:
        objects.append(add_uv_sphere(model_name + "_Head", (0, -0.02, 1.72), (0.42, 0.38, 0.38), accent))

    for x in (-0.52, 0.52):
        objects.append(add_cube(model_name + ("_LeftArm" if x < 0 else "_RightArm"), (x, -0.02, 1.1), (0.13, 0.13, 0.42), accent))
    for x in (-0.24, 0.24):
        objects.append(add_cube(model_name + ("_LeftFoot" if x < 0 else "_RightFoot"), (x, -0.02, 0.34), (0.16, 0.22, 0.12), dark))

    objects.extend(add_face(model_name, accent, dark))

    for obj in objects:
        obj["BrainrotDisplayName"] = display_name
        obj["BrainrotModelName"] = model_name

    empty = bpy.data.objects.new(model_name, None)
    bpy.context.collection.objects.link(empty)
    for obj in objects:
        obj.parent = empty
    empty.location = (0, 0, 0)
    objects.append(empty)
    return objects


def clear_animation(root: bpy.types.Object) -> None:
    if root.animation_data:
        root.animation_data_clear()


def keyframe_clip(root: bpy.types.Object, clip_name: str) -> None:
    clear_animation(root)
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, 0)
    root.scale = (1, 1, 1)

    if clip_name == "run":
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 32
        frames = (
            (1, (0, 0, 0), (0, 0, -7), (1, 1, 1)),
            (8, (0, 0, 0.08), (0, 0, 7), (1.04, 0.96, 1)),
            (16, (0, 0, 0), (0, 0, -7), (1, 1, 1)),
            (24, (0, 0, 0.08), (0, 0, 7), (1.04, 0.96, 1)),
            (32, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
        )
    elif clip_name == "stun":
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 48
        frames = (
            (1, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
            (12, (0, 0, -0.05), (0, 0, -16), (1.08, 0.92, 0.92)),
            (24, (0, 0, -0.05), (0, 0, 16), (1.08, 0.92, 0.92)),
            (36, (0, 0, -0.05), (0, 0, -10), (1.05, 0.95, 0.95)),
            (48, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
        )
    elif clip_name == "showcase":
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 96
        frames = (
            (1, (0, 0, 0), (0, 0, 0), (0.25, 0.25, 0.25)),
            (18, (0, 0, 0.08), (0, 0, 35), (1.16, 1.16, 1.16)),
            (32, (0, 0, 0.02), (0, 0, 80), (1, 1, 1)),
            (64, (0, 0, 0.1), (0, 0, 220), (1, 1, 1)),
            (96, (0, 0, 0.02), (0, 0, 360), (1, 1, 1)),
        )
    else:
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 48
        frames = (
            (1, (0, 0, 0), (0, 0, -2), (1, 1, 1)),
            (16, (0, 0, 0.05), (0, 0, 2), (1.02, 0.98, 1)),
            (32, (0, 0, 0), (0, 0, -2), (1, 1, 1)),
            (48, (0, 0, 0.05), (0, 0, 0), (1.02, 0.98, 1)),
        )

    for frame, location, rotation, scale in frames:
        bpy.context.scene.frame_set(frame)
        root.location = location
        root.rotation_euler = tuple(math.radians(value) for value in rotation)
        root.scale = scale
        root.keyframe_insert("location", frame=frame)
        root.keyframe_insert("rotation_euler", frame=frame)
        root.keyframe_insert("scale", frame=frame)


def export_model(model_name: str, objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[-1]

    glb_path = MODEL_EXPORTS / f"{model_name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb_path), use_selection=True, export_format="GLB")


def create_props() -> None:
    mat_stand = material("PlotStand_Green", (0.24, 0.92, 0.36))
    mat_gate = material("ZoneGate_Blue", (0.2, 0.55, 1.0))
    mat_hide = material("HideProp_Purple", (0.55, 0.32, 1.0))

    add_cube("PROP_PlotStand", (0, 0, 0.2), (1.2, 1.2, 0.18), mat_stand)
    add_cube("PROP_ZoneGate_Left", (-0.8, 0, 1.2), (0.18, 0.18, 1.2), mat_gate)
    add_cube("PROP_ZoneGate_Right", (0.8, 0, 1.2), (0.18, 0.18, 1.2), mat_gate)
    add_cube("PROP_ZoneGate_Top", (0, 0, 2.28), (0.98, 0.18, 0.18), mat_gate)
    add_uv_sphere("PROP_HideBush", (2.4, 0, 0.55), (0.72, 0.52, 0.42), mat_hide)
    add_torus("PROP_RevealPlatform", (-2.4, 0, 0.18), mat_gate)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(VFX_EXPORTS / "brainrot_props_placeholder.glb"), use_selection=True, export_format="GLB")


def main() -> None:
    clear_scene()

    for model_name, display_name, color, style in BRAINROTS:
        clear_scene()
        objects = make_brainrot(model_name, display_name, color, style)
        keyframe_clip(objects[-1], "idle")
        export_model(model_name, objects)

        for clip_name in ("idle", "run", "stun", "showcase"):
            keyframe_clip(objects[-1], clip_name)
            anim_path = ANIMATION_EXPORTS / f"{model_name}_{clip_name}_placeholder.glb"
            bpy.ops.export_scene.gltf(filepath=str(anim_path), use_selection=True, export_format="GLB", export_animations=True)

    clear_scene()
    create_props()


if __name__ == "__main__":
    main()
