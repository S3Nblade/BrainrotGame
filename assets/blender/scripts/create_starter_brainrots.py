"""Generate polished original BrainrotGame starter assets in Blender.

Run inside Blender:
    blender --background --python assets/blender/scripts/create_starter_brainrots.py

The generated model names intentionally match BrainrotConfig.ModelName values.
The assets are original cartoony simulator-style starter art, not copied from other games.
"""

from __future__ import annotations

import math
import json
import wave
import struct
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
EXPORT_ROOT = ROOT / "exports"
MODEL_EXPORTS = EXPORT_ROOT / "models"
ANIMATION_EXPORTS = EXPORT_ROOT / "animations"
VFX_EXPORTS = EXPORT_ROOT / "vfx"
ICON_EXPORTS = EXPORT_ROOT / "icons"
SOUND_EXPORTS = EXPORT_ROOT / "sounds"

for folder in (MODEL_EXPORTS, ANIMATION_EXPORTS, VFX_EXPORTS, ICON_EXPORTS, SOUND_EXPORTS):
    folder.mkdir(parents=True, exist_ok=True)


BRAINROTS = [
    ("PipoNuggetini", "Pipo Nuggetini", (1.0, 0.74, 0.22), "nugget"),
]

ANIMATION_CLIPS = ("idle", "run", "stun", "showcase")
SOUND_KEYS = (
    "ui_click",
    "ui_hover",
    "hit",
    "stun",
    "capture_success",
    "reveal_tick",
    "reveal_speedup",
    "reveal_final_pop",
    "reveal_rare",
    "reveal_legendary",
    "money_collect",
    "purchase_success",
    "purchase_fail",
    "quest_complete",
    "rebirth",
    "zone_unlock",
)
RARITY_GLOWS = ("Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret")
GAMEPLAY_VFX = (
    ("VFX_HitSpark", (1.0, 0.82, 0.18), "HitSpark"),
    ("VFX_StunStars", (1.0, 0.95, 0.28), "StunStars"),
    ("VFX_CaptureBurst", (0.28, 0.88, 1.0), "CaptureBurst"),
    ("VFX_MoneyPop", (0.22, 1.0, 0.42), "MoneyPop"),
    ("VFX_QuestComplete", (1.0, 0.58, 0.18), "QuestComplete"),
    ("VFX_RebirthBurst", (0.78, 0.26, 1.0), "RebirthBurst"),
    ("VFX_ZoneUnlockBurst", (0.18, 0.64, 1.0), "ZoneUnlockBurst"),
)
SOUND_FREQUENCIES = {
    "ui_click": 880,
    "ui_hover": 660,
    "hit": 190,
    "stun": 330,
    "capture_success": 740,
    "reveal_tick": 960,
    "reveal_speedup": 1120,
    "reveal_final_pop": 520,
    "reveal_rare": 680,
    "reveal_legendary": 820,
    "money_collect": 1040,
    "purchase_success": 720,
    "purchase_fail": 150,
    "quest_complete": 900,
    "rebirth": 440,
    "zone_unlock": 620,
}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def material(
    name: str,
    color: tuple[float, float, float],
    roughness: float = 0.55,
    metallic: float = 0.0,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if emission_strength > 0 and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def add_uv_sphere(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def add_cube(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("SoftBevel", "BEVEL")
    bevel.width = 0.1
    bevel.segments = 8
    obj.modifiers.new("SoftShade", "WEIGHTED_NORMAL")
    return obj


def add_cylinder(name: str, location: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("SoftEdge", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 5
    obj.modifiers.new("WeightedNormals", "WEIGHTED_NORMAL")
    return obj


def add_cone(name: str, location: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=radius, radius2=0.12, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def add_torus(name: str, location: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.18, major_segments=48, minor_segments=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler[0] = math.radians(90)
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def add_face(parent_name: str, accent: bpy.types.Material, black: bpy.types.Material, white: bpy.types.Material) -> list[bpy.types.Object]:
    parts = []
    for side, x in (("Left", -0.23), ("Right", 0.23)):
        eye = add_uv_sphere(parent_name + f"_{side}Eye", (x, -0.77, 1.68), (0.13, 0.045, 0.14), black)
        shine = add_uv_sphere(parent_name + f"_{side}EyeShine", (x - 0.035, -0.807, 1.735), (0.035, 0.012, 0.035), white)
        brow = add_cube(parent_name + f"_{side}Brow", (x, -0.79, 1.86), (0.16, 0.022, 0.035), accent)
        brow.rotation_euler[1] = math.radians(-10 if side == "Left" else 10)
        parts.extend([eye, shine, brow])

    mouth = add_cube(parent_name + "_Smile", (0, -0.8, 1.4), (0.28, 0.028, 0.055), black)
    tooth = add_cube(parent_name + "_Tooth", (0.08, -0.825, 1.355), (0.045, 0.012, 0.055), white)
    cheek_l = add_uv_sphere(parent_name + "_LeftCheek", (-0.38, -0.78, 1.48), (0.07, 0.018, 0.05), accent)
    cheek_r = add_uv_sphere(parent_name + "_RightCheek", (0.38, -0.78, 1.48), (0.07, 0.018, 0.05), accent)
    parts.extend([mouth, tooth, cheek_l, cheek_r])
    return parts


def add_simulator_details(
    model_name: str,
    style: str,
    accent: bpy.types.Material,
    dark: bpy.types.Material,
    white: bpy.types.Material,
    gold: bpy.types.Material,
    glow: bpy.types.Material,
) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []

    if style == "nugget":
        for i, x in enumerate((-0.32, 0.0, 0.3)):
            spot = add_uv_sphere(f"{model_name}_CrispySpot_{i}", (x, -0.63, 1.98 - i * 0.18), (0.1, 0.025, 0.07), accent)
            parts.append(spot)
    elif style == "cone":
        hat = add_cone(model_name + "_PartyHat", (0, -0.02, 2.34), 0.28, 0.62, accent)
        brim = add_torus(model_name + "_HatBrim", (0, -0.02, 2.08), gold)
        brim.scale = (0.42, 0.42, 0.06)
        parts.extend([hat, brim])
    elif style == "blob":
        bubble = add_uv_sphere(model_name + "_BubbleCrown", (0.22, -0.12, 2.12), (0.16, 0.16, 0.16), glow)
        antenna = add_cylinder(model_name + "_TinyAntenna", (-0.16, -0.03, 2.12), 0.025, 0.42, accent)
        antenna.rotation_euler[1] = math.radians(18)
        parts.extend([bubble, antenna])
    elif style == "pickle":
        for i in range(7):
            x = -0.34 + (i % 3) * 0.34
            z = 1.05 + (i // 3) * 0.34
            parts.append(add_uv_sphere(f"{model_name}_Bump_{i}", (x, -0.69, z), (0.055, 0.02, 0.055), accent))
        parts.append(add_cube(model_name + "_SneakyMask", (0, -0.82, 1.68), (0.5, 0.018, 0.12), dark))
    elif style == "donut":
        for i in range(10):
            sprinkle = add_cube(f"{model_name}_Sprinkle_{i}", (math.cos(i) * 0.42, -0.62, 1.35 + math.sin(i) * 0.24), (0.065, 0.018, 0.018), accent if i % 2 else gold)
            sprinkle.rotation_euler[2] = math.radians(i * 23)
            parts.append(sprinkle)
    elif style == "banana":
        parts.append(add_cone(model_name + "_GoblinLeftEar", (-0.44, -0.05, 1.58), 0.14, 0.42, accent))
        parts[-1].rotation_euler[2] = math.radians(90)
        parts.append(add_cone(model_name + "_GoblinRightEar", (0.44, -0.05, 1.58), 0.14, 0.42, accent))
        parts[-1].rotation_euler[2] = math.radians(-90)
    elif style == "toaster":
        parts.append(add_cube(model_name + "_ShyScreen", (0, -0.81, 1.25), (0.38, 0.018, 0.18), dark))
        parts.append(add_cube(model_name + "_Lever", (0.76, -0.08, 1.28), (0.04, 0.08, 0.24), gold))
    elif style == "meatball":
        for i in range(5):
            flame = add_cone(f"{model_name}_TurboFlame_{i}", (-0.32 + i * 0.16, 0.48, 0.78), 0.075, 0.5, glow)
            flame.rotation_euler[0] = math.radians(75)
            parts.append(flame)
    elif style == "capybara":
        parts.append(add_cube(model_name + "_GlitchVisor", (0, -0.81, 1.52), (0.46, 0.02, 0.1), glow))
        for i in range(3):
            pixel = add_cube(f"{model_name}_GlitchPixel_{i}", (0.42 + i * 0.08, -0.64, 1.28 + i * 0.11), (0.045, 0.018, 0.045), glow)
            parts.append(pixel)
    elif style == "lizard":
        for i in range(5):
            spike = add_cone(f"{model_name}_BackSpike_{i}", (0, 0.22 + i * 0.12, 1.7 - i * 0.16), 0.055, 0.24, accent)
            spike.rotation_euler[0] = math.radians(-25)
            parts.append(spike)
    elif style == "frog":
        for i in range(5):
            swirl = add_torus(f"{model_name}_BrainSwirl_{i}", (-0.24 + i * 0.12, -0.08, 1.86), glow)
            swirl.scale = (0.11, 0.11, 0.018)
            parts.append(swirl)
    elif style == "sneaker_shark":
        sole = add_cube(model_name + "_SneakerSole", (0, -0.04, 0.2), (0.62, 0.42, 0.1), white)
        stripe = add_cube(model_name + "_ShoeStripe", (0, -0.5, 0.38), (0.45, 0.02, 0.045), accent)
        parts.extend([sole, stripe])
    elif style == "wood_drum":
        for i, x in enumerate((-0.32, 0.32)):
            stick = add_cylinder(f"{model_name}_DrumStick_{i}", (x, -0.72, 1.65), 0.035, 0.72, gold)
            stick.rotation_euler[0] = math.radians(65)
            stick.rotation_euler[2] = math.radians(16 if x < 0 else -16)
            parts.append(stick)
        for i in range(4):
            band = add_torus(f"{model_name}_WoodRing_{i}", (0, -0.34 + i * 0.22, 1.15), accent)
            band.scale = (0.52, 0.52, 0.025)
            parts.append(band)
    elif style == "croc_plane":
        for i in range(6):
            tooth = add_cone(f"{model_name}_Tooth_{i}", (-0.25 + i * 0.1, -0.91, 1.0), 0.035, 0.12, white)
            parts.append(tooth)
        tail = add_cone(model_name + "_TailFin", (0, 0.58, 1.18), 0.16, 0.44, accent)
        tail.rotation_euler[0] = math.radians(-90)
        parts.append(tail)
    elif style == "coffee_ballerina":
        for i, x in enumerate((-0.18, 0.18)):
            leg = add_cylinder(f"{model_name}_BalletLeg_{i}", (x, -0.02, 0.42), 0.04, 0.55, white)
            leg.rotation_euler[0] = math.radians(8 if x < 0 else -8)
            parts.append(leg)
        parts.append(add_cube(model_name + "_CupHandle", (0.56, 0, 1.08), (0.08, 0.18, 0.28), accent))
    elif style == "tree_foot":
        for i in range(5):
            leaf = add_uv_sphere(f"{model_name}_LeafTuft_{i}", (-0.36 + i * 0.18, -0.02, 2.15), (0.16, 0.1, 0.12), glow)
            parts.append(leaf)
        parts.append(add_cube(model_name + "_BigLeftFoot", (-0.28, -0.08, 0.22), (0.24, 0.32, 0.1), dark))
        parts.append(add_cube(model_name + "_BigRightFoot", (0.28, -0.08, 0.22), (0.24, 0.32, 0.1), dark))
    elif style == "coffee_ninja":
        scarf = add_cube(model_name + "_RedScarf", (0.48, -0.08, 1.38), (0.26, 0.035, 0.08), accent)
        scarf.rotation_euler[2] = math.radians(-20)
        parts.append(scarf)
        parts.append(add_cube(model_name + "_FoamBelt", (0, -0.56, 1.02), (0.48, 0.028, 0.06), gold))
    elif style == "cactus_elephant":
        for i in range(8):
            spike = add_cone(f"{model_name}_CactusSpike_{i}", (-0.34 + (i % 4) * 0.22, -0.5, 0.88 + (i // 4) * 0.42), 0.025, 0.12, white)
            spike.rotation_euler[0] = math.radians(90)
            parts.append(spike)
    elif style == "burrito_bandit":
        for i in range(3):
            filling = add_cube(f"{model_name}_Filling_{i}", (-0.18 + i * 0.18, -0.54, 1.82), (0.08, 0.04, 0.14), accent if i % 2 else gold)
            parts.append(filling)
        hat = add_torus(model_name + "_TinySombrero", (0, -0.02, 2.02), gold)
        hat.scale = (0.5, 0.5, 0.055)
        parts.append(hat)
    elif style == "banana_chimp":
        for x in (-0.44, 0.44):
            ear = add_uv_sphere(model_name + ("_LeftEar" if x < 0 else "_RightEar"), (x, -0.05, 1.52), (0.16, 0.08, 0.18), accent)
            parts.append(ear)
        parts.append(add_cube(model_name + "_BananaPeelBelt", (0, -0.58, 0.98), (0.5, 0.03, 0.08), gold))
    elif style == "goose_plane":
        wing_l = add_cube(model_name + "_LeftWing", (-0.6, 0.02, 1.05), (0.48, 0.07, 0.07), accent)
        wing_r = add_cube(model_name + "_RightWing", (0.6, 0.02, 1.05), (0.48, 0.07, 0.07), accent)
        wing_l.rotation_euler[2] = math.radians(-8)
        wing_r.rotation_euler[2] = math.radians(8)
        parts.extend([wing_l, wing_r])
    elif style == "doll_frog":
        bow = add_cube(model_name + "_DollBow", (0, -0.56, 2.02), (0.32, 0.03, 0.09), gold)
        bow.rotation_euler[2] = math.radians(12)
        parts.append(bow)
        parts.append(add_uv_sphere(model_name + "_FrogHatLeftEye", (-0.22, -0.2, 1.98), (0.08, 0.04, 0.08), dark))
        parts.append(add_uv_sphere(model_name + "_FrogHatRightEye", (0.22, -0.2, 1.98), (0.08, 0.04, 0.08), dark))
    elif style == "saturn_cow":
        for i, x in enumerate((-0.22, 0.18)):
            spot = add_uv_sphere(f"{model_name}_CowSpot_{i}", (x, -0.62, 1.32 + i * 0.18), (0.16, 0.026, 0.11), dark)
            parts.append(spot)
        horn_l = add_cone(model_name + "_LeftHorn", (-0.24, -0.08, 1.86), 0.07, 0.28, gold)
        horn_r = add_cone(model_name + "_RightHorn", (0.24, -0.08, 1.86), 0.07, 0.28, gold)
        parts.extend([horn_l, horn_r])

    badge = add_torus(model_name + "_ShowcaseBaseRing", (0, 0, 0.25), glow)
    badge.scale = (0.82, 0.82, 0.025)
    parts.append(badge)
    return parts


def make_brainrot(model_name: str, display_name: str, color: tuple[float, float, float], style: str) -> list[bpy.types.Object]:
    main = material(model_name + "_Main", color, 0.48)
    accent = material(model_name + "_Accent", tuple(min(1.0, c + 0.18) for c in color))
    dark = material(model_name + "_Dark", (0.05, 0.06, 0.09))
    white = material(model_name + "_White", (1.0, 0.97, 0.9), 0.35)
    gold = material(model_name + "_Gold", (1.0, 0.72, 0.08), 0.28, 0.15)
    glow = material(model_name + "_Glow", tuple(min(1.0, c + 0.28) for c in color), 0.25, 0.0, 0.18)

    objects: list[bpy.types.Object] = []

    if style == "cone":
        objects.append(add_cone(model_name + "_Body", (0, 0, 1.05), 0.72, 1.82, main))
    elif style == "donut":
        objects.append(add_torus(model_name + "_Body", (0, 0, 1.35), main))
        objects[-1].scale = (1.08, 1.08, 1.08)
    elif style == "toaster":
        objects.append(add_cube(model_name + "_Body", (0, 0, 1.15), (0.78, 0.48, 0.68), main))
        objects.append(add_cube(model_name + "_Toast", (0, 0.02, 1.94), (0.52, 0.14, 0.32), accent))
    elif style == "banana":
        objects.append(add_cone(model_name + "_Body", (0, 0, 1.2), 0.5, 2.05, main))
        objects[-1].rotation_euler[2] = math.radians(11)
    elif style == "spaghetti":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.15), (0.66, 0.5, 0.64), main))
        for i in range(14):
            strand = add_cone(model_name + f"_Noodle_{i:02d}", (math.cos(i) * 0.32, math.sin(i) * 0.16, 1.95), 0.045, 0.72, gold)
            strand.rotation_euler[0] = math.radians(90 + i * 9)
            objects.append(strand)
        objects.append(add_cube(model_name + "_Crown", (0, 0, 2.36), (0.52, 0.14, 0.18), gold))
    elif style == "capybara":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.06), (0.82, 0.46, 0.48), main))
        objects.append(add_uv_sphere(model_name + "_Snout", (0, -0.58, 1.15), (0.28, 0.16, 0.18), accent))
    elif style == "lizard":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.05), (0.7, 0.38, 0.46), main))
        objects.append(add_cone(model_name + "_Tail", (0, 0.65, 0.86), 0.18, 0.88, accent))
        objects[-1].rotation_euler[0] = math.radians(72)
    elif style == "frog":
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.05), (0.7, 0.48, 0.5), main))
        objects.append(add_uv_sphere(model_name + "_BrainDome", (0, -0.03, 1.78), (0.48, 0.36, 0.24), accent))
    elif style == "sneaker_shark":
        objects.append(add_uv_sphere(model_name + "_SharkBody", (0, 0, 1.18), (0.78, 0.34, 0.42), main))
        dorsal = add_cone(model_name + "_DorsalFin", (0, 0.04, 1.74), 0.18, 0.55, accent)
        dorsal.rotation_euler[0] = math.radians(-90)
        objects.append(dorsal)
        snout = add_cone(model_name + "_Snout", (0, -0.64, 1.22), 0.32, 0.7, accent)
        snout.rotation_euler[0] = math.radians(90)
        objects.append(snout)
    elif style == "wood_drum":
        body = add_cylinder(model_name + "_LogBody", (0, 0, 1.15), 0.52, 1.35, main)
        body.rotation_euler[0] = math.radians(90)
        objects.append(body)
        objects.append(add_cylinder(model_name + "_DrumTop", (0, -0.68, 1.15), 0.54, 0.08, accent))
        objects[-1].rotation_euler[0] = math.radians(90)
    elif style == "croc_plane":
        objects.append(add_uv_sphere(model_name + "_CrocBody", (0, 0, 1.1), (0.78, 0.36, 0.34), main))
        snout = add_cube(model_name + "_LongSnout", (0, -0.68, 1.12), (0.38, 0.38, 0.16), accent)
        objects.append(snout)
        wing_l = add_cube(model_name + "_LeftWing", (-0.62, 0.02, 1.14), (0.5, 0.08, 0.08), accent)
        wing_r = add_cube(model_name + "_RightWing", (0.62, 0.02, 1.14), (0.5, 0.08, 0.08), accent)
        wing_l.rotation_euler[2] = math.radians(-8)
        wing_r.rotation_euler[2] = math.radians(8)
        objects.extend([wing_l, wing_r])
    elif style == "coffee_ballerina":
        objects.append(add_cylinder(model_name + "_CupBody", (0, 0, 1.08), 0.52, 0.96, main))
        tutu = add_torus(model_name + "_Tutu", (0, 0, 0.88), accent)
        tutu.scale = (0.95, 0.95, 0.08)
        objects.append(tutu)
        foam = add_uv_sphere(model_name + "_FoamHead", (0, 0, 1.72), (0.46, 0.38, 0.26), white)
        objects.append(foam)
    elif style == "tree_foot":
        objects.append(add_cylinder(model_name + "_TreeBody", (0, 0, 1.05), 0.42, 1.22, main))
        objects.append(add_uv_sphere(model_name + "_LeafHead", (0, 0, 1.84), (0.62, 0.46, 0.42), accent))
    elif style == "coffee_ninja":
        objects.append(add_cylinder(model_name + "_CupBody", (0, 0, 1.08), 0.5, 0.98, main))
        objects.append(add_uv_sphere(model_name + "_FoamHead", (0, 0, 1.7), (0.44, 0.34, 0.25), accent))
        mask = add_cube(model_name + "_NinjaMask", (0, -0.78, 1.68), (0.48, 0.02, 0.12), dark)
        objects.append(mask)
    elif style == "cactus_elephant":
        objects.append(add_uv_sphere(model_name + "_CactusBody", (0, 0, 1.1), (0.5, 0.36, 0.78), main))
        trunk = add_cone(model_name + "_Trunk", (0, -0.64, 1.08), 0.14, 0.72, accent)
        trunk.rotation_euler[0] = math.radians(90)
        objects.append(trunk)
        objects.append(add_uv_sphere(model_name + "_LeftEar", (-0.48, -0.06, 1.36), (0.22, 0.08, 0.26), accent))
        objects.append(add_uv_sphere(model_name + "_RightEar", (0.48, -0.06, 1.36), (0.22, 0.08, 0.26), accent))
    elif style == "burrito_bandit":
        roll = add_cylinder(model_name + "_BurritoBody", (0, 0, 1.14), 0.46, 1.34, main)
        roll.rotation_euler[2] = math.radians(12)
        objects.append(roll)
        objects.append(add_cube(model_name + "_BanditMask", (0, -0.76, 1.54), (0.48, 0.02, 0.12), dark))
    elif style == "banana_chimp":
        objects.append(add_uv_sphere(model_name + "_ChimpBody", (0, 0, 1.08), (0.58, 0.42, 0.56), main))
        banana = add_cone(model_name + "_BananaCrown", (0, -0.02, 1.96), 0.26, 0.72, gold)
        banana.rotation_euler[2] = math.radians(12)
        objects.append(banana)
    elif style == "goose_plane":
        objects.append(add_uv_sphere(model_name + "_GooseBody", (0, 0, 1.06), (0.72, 0.32, 0.42), main))
        neck = add_cylinder(model_name + "_GooseNeck", (0, -0.38, 1.54), 0.12, 0.64, accent)
        neck.rotation_euler[0] = math.radians(-18)
        objects.append(neck)
        beak = add_cone(model_name + "_Beak", (0, -0.78, 1.72), 0.12, 0.38, gold)
        beak.rotation_euler[0] = math.radians(90)
        objects.append(beak)
    elif style == "doll_frog":
        objects.append(add_uv_sphere(model_name + "_DollBody", (0, 0, 1.12), (0.52, 0.38, 0.6), main))
        objects.append(add_uv_sphere(model_name + "_FrogHat", (0, -0.02, 1.82), (0.5, 0.34, 0.22), accent))
    elif style == "saturn_cow":
        objects.append(add_uv_sphere(model_name + "_CowBody", (0, 0, 1.1), (0.68, 0.42, 0.52), main))
        ring = add_torus(model_name + "_SaturnRing", (0, 0, 1.15), gold)
        ring.scale = (1.18, 1.18, 0.04)
        ring.rotation_euler[1] = math.radians(22)
        objects.append(ring)
    else:
        objects.append(add_uv_sphere(model_name + "_Body", (0, 0, 1.12), (0.66, 0.52, 0.58), main))

    if style in {"pickle", "blob", "nugget", "meatball"}:
        objects.append(add_uv_sphere(model_name + "_Head", (0, -0.02, 1.76), (0.48, 0.42, 0.42), accent))

    for x in (-0.52, 0.52):
        arm = add_cube(model_name + ("_LeftArm" if x < 0 else "_RightArm"), (x, -0.02, 1.1), (0.15, 0.15, 0.48), accent)
        arm.rotation_euler[1] = math.radians(10 if x < 0 else -10)
        objects.append(arm)
    for x in (-0.24, 0.24):
        objects.append(add_cube(model_name + ("_LeftFoot" if x < 0 else "_RightFoot"), (x, -0.02, 0.34), (0.2, 0.25, 0.13), dark))

    objects.extend(add_face(model_name, accent, dark, white))
    objects.extend(add_simulator_details(model_name, style, accent, dark, white, gold, glow))

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
        bpy.context.scene.frame_end = 28
        frames = (
            (1, (0, 0, 0), (0, 0, -10), (1.02, 0.98, 1)),
            (7, (0.05, 0, 0.13), (0, 0, 11), (1.08, 0.93, 1.03)),
            (14, (0, 0, 0), (0, 0, -10), (1.02, 0.98, 1)),
            (21, (-0.05, 0, 0.13), (0, 0, 11), (1.08, 0.93, 1.03)),
            (28, (0, 0, 0), (0, 0, 0), (1.02, 0.98, 1)),
        )
    elif clip_name == "stun":
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 42
        frames = (
            (1, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
            (6, (0, 0, 0.05), (0, 0, -22), (1.16, 0.86, 0.9)),
            (13, (0, 0, -0.07), (0, 0, 22), (0.94, 1.08, 0.95)),
            (21, (0, 0, -0.08), (0, 0, -16), (1.1, 0.9, 0.9)),
            (31, (0, 0, -0.04), (0, 0, 12), (1.04, 0.96, 0.94)),
            (42, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
        )
    elif clip_name == "showcase":
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 90
        frames = (
            (1, (0, 0, 0), (0, 0, 0), (0.25, 0.25, 0.25)),
            (10, (0, 0, 0.14), (0, 0, 22), (1.34, 1.34, 1.34)),
            (18, (0, 0, 0.04), (0, 0, 55), (0.94, 0.94, 0.94)),
            (28, (0, 0, 0.08), (0, 0, 90), (1.04, 1.04, 1.04)),
            (58, (0, 0, 0.12), (0, 0, 230), (1, 1, 1)),
            (90, (0, 0, 0.06), (0, 0, 360), (1, 1, 1)),
        )
    else:
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 48
        frames = (
            (1, (0, 0, 0), (0, 0, -3), (1, 1, 1)),
            (12, (0, 0, 0.06), (0, 0, 3), (1.035, 0.965, 1.01)),
            (24, (0, 0, 0), (0, 0, -2), (0.99, 1.01, 1)),
            (36, (0, 0, 0.06), (0, 0, 2), (1.035, 0.965, 1.01)),
            (48, (0, 0, 0.01), (0, 0, 0), (1, 1, 1)),
        )

    for frame, location, rotation, scale in frames:
        bpy.context.scene.frame_set(frame)
        root.location = location
        root.rotation_euler = tuple(math.radians(value) for value in rotation)
        root.scale = scale
        root.keyframe_insert("location", frame=frame)
        root.keyframe_insert("rotation_euler", frame=frame)
        root.keyframe_insert("scale", frame=frame)

    if root.animation_data and root.animation_data.action and hasattr(root.animation_data.action, "fcurves"):
        for curve in root.animation_data.action.fcurves:
            for keyframe in curve.keyframe_points:
                keyframe.interpolation = "BEZIER"


def export_model(model_name: str, objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[-1]

    glb_path = MODEL_EXPORTS / f"{model_name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb_path), use_selection=True, export_format="GLB")


def render_icon(model_name: str, display_name: str, objects: list[bpy.types.Object]) -> None:
    try:
        bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        bpy.context.scene.render.engine = "BLENDER_EEVEE"
    camera_data = bpy.data.cameras.new(model_name + "_IconCamera")
    camera = bpy.data.objects.new(model_name + "_IconCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0, -6.4, 2.35)
    direction = Vector((0, 0, 1.35)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 3.85
    bpy.context.scene.camera = camera

    light_data = bpy.data.lights.new(model_name + "_IconKeyLight", "AREA")
    light = bpy.data.objects.new(model_name + "_IconKeyLight", light_data)
    bpy.context.collection.objects.link(light)
    light.location = (0, -3.2, 4.0)
    light_data.energy = 560
    light_data.size = 4.5

    rim_data = bpy.data.lights.new(model_name + "_IconRimLight", "POINT")
    rim = bpy.data.objects.new(model_name + "_IconRimLight", rim_data)
    bpy.context.collection.objects.link(rim)
    rim.location = (-2.2, 1.2, 3.2)
    rim_data.energy = 120

    base_mat = material(model_name + "_IconGlowDisc", (0.18, 0.52, 1.0), 0.28, 0.0, 0.12)
    disc = add_cylinder(model_name + "_IconGlowDisc", (0, 0.18, 0.04), 1.1, 0.035, base_mat)
    disc.scale = (1.0, 0.72, 1.0)

    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512
    bpy.context.scene.render.film_transparent = True
    if hasattr(bpy.context.scene, "eevee"):
        bpy.context.scene.eevee.taa_render_samples = 32
    bpy.context.scene.render.filepath = str(ICON_EXPORTS / f"{model_name.replace('BR_', '', 1)}.png")
    bpy.ops.render.render(write_still=True)


def export_objects(objects: list[bpy.types.Object], path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_format="GLB")


def create_props() -> None:
    mat_stand = material("PlotStand_Green", (0.24, 0.92, 0.36))
    mat_gate = material("ZoneGate_Blue", (0.2, 0.55, 1.0))
    mat_hide = material("HideProp_Purple", (0.55, 0.32, 1.0))

    plot_stand = [add_cube("PROP_PlotStand", (0, 0, 0.2), (1.2, 1.2, 0.18), mat_stand)]
    zone_gate = [
        add_cube("PROP_ZoneGate_Left", (-0.8, 0, 1.2), (0.18, 0.18, 1.2), mat_gate),
        add_cube("PROP_ZoneGate_Right", (0.8, 0, 1.2), (0.18, 0.18, 1.2), mat_gate),
        add_cube("PROP_ZoneGate_Top", (0, 0, 2.28), (0.98, 0.18, 0.18), mat_gate),
    ]
    hide_bush = [add_uv_sphere("PROP_HideBush", (2.4, 0, 0.55), (0.72, 0.52, 0.42), mat_hide)]
    hide_crate = [add_cube("PROP_HideCrate", (4.0, 0, 0.55), (0.58, 0.58, 0.58), mat_hide)]
    reveal_platform = [add_torus("PROP_RevealPlatform", (-2.4, 0, 0.18), mat_gate)]

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(VFX_EXPORTS / "brainrot_props_placeholder.glb"), use_selection=True, export_format="GLB")
    export_objects(plot_stand, MODEL_EXPORTS / "PROP_PlotStand.glb")
    export_objects(zone_gate, MODEL_EXPORTS / "PROP_ZoneGate.glb")
    export_objects(hide_bush, MODEL_EXPORTS / "PROP_HideBush.glb")
    export_objects(hide_crate, MODEL_EXPORTS / "PROP_HideCrate.glb")
    export_objects(reveal_platform, VFX_EXPORTS / "PROP_RevealPlatform.glb")


def create_rarity_glows() -> None:
    colors = {
        "Common": (0.88, 0.93, 1.0),
        "Uncommon": (0.32, 1.0, 0.42),
        "Rare": (0.18, 0.62, 1.0),
        "Epic": (0.72, 0.25, 1.0),
        "Legendary": (1.0, 0.68, 0.08),
        "Mythic": (1.0, 0.22, 0.62),
        "Secret": (0.2, 1.0, 0.76),
    }

    for rarity, color in colors.items():
        clear_scene()
        mat = material(f"VFX_{rarity}Glow", color, 0.35)
        mat.blend_method = "BLEND"
        ring = add_torus(f"VFX_{rarity}GlowRing", (0, 0, 0.1), mat)
        ring.scale = (1.45, 1.45, 0.08)
        burst = add_uv_sphere(f"VFX_{rarity}GlowCore", (0, 0, 0.18), (0.34, 0.34, 0.08), mat)
        export_objects([ring, burst], VFX_EXPORTS / f"VFX_{rarity}Glow.glb")


def create_gameplay_vfx() -> None:
    for vfx_name, color, _asset_key in GAMEPLAY_VFX:
        clear_scene()
        mat = material(vfx_name + "_Mat", color, 0.32)
        ring = add_torus(vfx_name + "_Ring", (0, 0, 0.12), mat)
        ring.scale = (0.75, 0.75, 0.05)
        parts = [ring]

        for i in range(6):
            angle = (math.pi * 2 / 6) * i
            spark = add_cone(
                f"{vfx_name}_Ray_{i:02d}",
                (math.cos(angle) * 0.62, math.sin(angle) * 0.62, 0.18),
                0.07,
                0.45,
                mat,
            )
            spark.rotation_euler[1] = math.radians(90)
            spark.rotation_euler[2] = angle
            parts.append(spark)

        if vfx_name == "VFX_StunStars":
            for i in range(3):
                star = add_uv_sphere(f"{vfx_name}_Star_{i:02d}", (-0.32 + i * 0.32, 0, 0.72), (0.12, 0.04, 0.12), mat)
                parts.append(star)

        export_objects(parts, VFX_EXPORTS / f"{vfx_name}.glb")


def create_sound_placeholders() -> None:
    sample_rate = 44100
    duration_by_key = {
        "reveal_speedup": 0.42,
        "reveal_final_pop": 0.36,
        "reveal_rare": 0.58,
        "reveal_legendary": 0.72,
        "quest_complete": 0.46,
        "rebirth": 0.78,
        "zone_unlock": 0.58,
    }

    for key in SOUND_KEYS:
        frequency = SOUND_FREQUENCIES.get(key, 440)
        duration = duration_by_key.get(key, 0.22)
        path = SOUND_EXPORTS / f"{key}.wav"
        frame_count = int(sample_rate * duration)

        with wave.open(str(path), "w") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(sample_rate)

            for frame in range(frame_count):
                t = frame / sample_rate
                progress = frame / frame_count
                attack = min(1.0, progress / 0.08)
                fade = max(0.0, 1.0 - progress)
                chirp = frequency * (1.0 + 0.22 * progress)
                harmonic = math.sin(2 * math.pi * chirp * t)
                sparkle = 0.45 * math.sin(2 * math.pi * (frequency * 1.5) * t)
                sub = 0.22 * math.sin(2 * math.pi * max(80, frequency * 0.5) * t)
                noise = 0.08 * math.sin(2 * math.pi * (frequency * 3.7) * t + math.sin(t * 80))
                if "fail" in key:
                    harmonic = math.sin(2 * math.pi * (frequency * (1.0 - 0.35 * progress)) * t)
                    sparkle *= 0.1
                if key in {"reveal_rare", "reveal_legendary", "rebirth", "zone_unlock"}:
                    sparkle *= 1.6
                    sub *= 1.25
                sample = (harmonic + sparkle + sub + noise) * 0.16 * attack * fade
                wav.writeframes(struct.pack("<h", int(sample * 32767)))


def write_manifest() -> None:
    brainrots = []
    for model_name, display_name, _color, _style in BRAINROTS:
        asset_key = model_name.replace("BR_", "", 1)
        brainrots.append(
            {
                "id": asset_key,
                "displayName": display_name,
                "modelName": model_name,
                "modelExport": f"exports/models/{model_name}.glb",
                "iconTarget": f"exports/icons/{asset_key}.png",
                "assetIdsModelKey": f"AssetIds.Models.{asset_key}",
                "assetIdsIconKey": f"AssetIds.Icons.{asset_key}",
                "animations": {
                    clip: {
                        "export": f"exports/animations/{model_name}_{clip}_placeholder.glb",
                        "assetIdsKey": f"AssetIds.Animations.{clip.title() if clip != 'stun' else 'Stun'}",
                    }
                    for clip in ANIMATION_CLIPS
                },
            }
        )

    manifest = {
        "schemaVersion": 1,
        "purpose": "BrainrotGame Roblox upload checklist. Paste uploaded IDs into src/ReplicatedStorage/Shared/AssetIds.lua.",
        "brainrots": brainrots,
        "props": [
            {"name": "PROP_PlotStand", "export": "exports/models/PROP_PlotStand.glb", "assetIdsKey": "AssetIds.VFX.PlotStand"},
            {"name": "PROP_ZoneGate", "export": "exports/models/PROP_ZoneGate.glb", "assetIdsKey": "AssetIds.VFX.ZoneGate"},
            {"name": "PROP_HideBush", "export": "exports/models/PROP_HideBush.glb", "assetIdsKey": "AssetIds.VFX.HideBush"},
            {"name": "PROP_HideCrate", "export": "exports/models/PROP_HideCrate.glb", "assetIdsKey": "AssetIds.VFX.HideCrate"},
            {"name": "PROP_RevealPlatform", "export": "exports/vfx/PROP_RevealPlatform.glb", "assetIdsKey": "AssetIds.VFX.RevealPlatform"},
        ],
        "rarityVfx": [
            {
                "rarity": rarity,
                "export": f"exports/vfx/VFX_{rarity}Glow.glb",
                "assetIdsKey": f"AssetIds.VFX.{rarity}Glow",
            }
            for rarity in RARITY_GLOWS
        ],
        "gameplayVfx": [
            {
                "name": vfx_name,
                "export": f"exports/vfx/{vfx_name}.glb",
                "assetIdsKey": f"AssetIds.VFX.{asset_key}",
            }
            for vfx_name, _color, asset_key in GAMEPLAY_VFX
        ],
        "sounds": [
            {
                "key": key,
                "sourcePlaceholder": f"exports/sounds/{key}.wav",
                "assetIdsKey": f"AssetIds.Sounds.{key}",
            }
            for key in SOUND_KEYS
        ],
    }

    (ROOT / "asset_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Sound Upload Checklist",
        "",
        "Create or source short Roblox-safe SFX for these keys, upload them to Roblox, then paste IDs into `src/ReplicatedStorage/Shared/AssetIds.lua`.",
        "",
    ]
    lines.extend(f"- `{key}` -> `AssetIds.Sounds.{key}`" for key in SOUND_KEYS)
    (SOUND_EXPORTS / "SOUND_KEYS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    clear_scene()

    for model_name, display_name, color, style in BRAINROTS:
        clear_scene()
        objects = make_brainrot(model_name, display_name, color, style)
        keyframe_clip(objects[-1], "idle")
        export_model(model_name, objects)
        render_icon(model_name, display_name, objects)

        for clip_name in ANIMATION_CLIPS:
            keyframe_clip(objects[-1], clip_name)
            anim_path = ANIMATION_EXPORTS / f"{model_name}_{clip_name}_placeholder.glb"
            bpy.ops.export_scene.gltf(filepath=str(anim_path), use_selection=True, export_format="GLB", export_animations=True)

    clear_scene()
    create_props()
    create_rarity_glows()
    create_gameplay_vfx()
    create_sound_placeholders()
    write_manifest()


if __name__ == "__main__":
    main()
