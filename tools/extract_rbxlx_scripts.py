import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

if len(sys.argv) < 3:
    print("Usage:")
    print('python tools\\extract_rbxlx_scripts.py "YourGame.rbxlx" "."')
    sys.exit(1)

rbxlx_path = Path(sys.argv[1])
output_root = Path(sys.argv[2])

if not rbxlx_path.exists():
    print(f"ERROR: File not found: {rbxlx_path}")
    sys.exit(1)

SCRIPT_CLASSES = {
    "Script": ".server.lua",
    "LocalScript": ".client.lua",
    "ModuleScript": ".lua",
}

SERVICES_TO_EXPORT = {
    "ServerScriptService",
    "ReplicatedStorage",
    "StarterPlayer",
    "StarterGui",
    "ServerStorage",
    "StarterPack",
}

def clean_name(name):
    name = name or "Unnamed"
    name = re.sub(r'[<>:"/\\\\|?*]', "_", name)
    name = name.strip()
    return name or "Unnamed"

def get_prop(item, prop_name):
    props = item.find("Properties")
    if props is None:
        return None

    for child in props:
        if child.attrib.get("name") == prop_name:
            return child.text or ""

    return None

def get_name(item):
    return get_prop(item, "Name") or item.attrib.get("class", "Unnamed")

def get_source(item):
    return get_prop(item, "Source") or ""

def unique_path(path):
    if not path.exists():
        return path

    stem = path.stem
    suffix = path.suffix
    parent = path.parent

    i = 2
    while True:
        candidate = parent / f"{stem}_{i}{suffix}"
        if not candidate.exists():
            return candidate
        i += 1

def walk(item, path_parts):
    class_name = item.attrib.get("class", "")
    name = clean_name(get_name(item))

    if class_name in SCRIPT_CLASSES:
        source = get_source(item)
        ext = SCRIPT_CLASSES[class_name]

        folder = output_root / "src" / Path(*path_parts)
        folder.mkdir(parents=True, exist_ok=True)

        file_path = unique_path(folder / (name + ext))
        file_path.write_text(source, encoding="utf-8")

        print(f"Exported: {file_path}")
        return

    new_path_parts = path_parts + [name]

    for child in item.findall("Item"):
        walk(child, new_path_parts)

print(f"Reading: {rbxlx_path}")

tree = ET.parse(rbxlx_path)
root = tree.getroot()

(output_root / "src").mkdir(parents=True, exist_ok=True)

for item in root.findall("Item"):
    service_name = get_name(item)

    if service_name in SERVICES_TO_EXPORT:
        print(f"Scanning service: {service_name}")

        for child in item.findall("Item"):
            walk(child, [service_name])

print("")
print("DONE.")
print(f"Scripts exported into: {output_root / 'src'}")