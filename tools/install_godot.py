#!/usr/bin/env python3
"""Install pinned official Linux editor and Web templates without a GUI.

Archives are verified against SHA-256 digests from the official GitHub release.
Only the two Web template files are extracted (not the other platform templates).
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile

VERSION = "4.6.3"
RELEASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable"
ARCHIVES = {
    f"Godot_v{VERSION}-stable_linux.x86_64.zip": "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3",
    f"Godot_v{VERSION}-stable_export_templates.tpz": "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8",
}


def download(name, destination):
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == ARCHIVES[name]:
        return
    request = urllib.request.Request(f"{RELEASE}/{name}", headers={"User-Agent": "KIKORI-build/1.0"})
    temporary = destination.with_suffix(".part")
    with urllib.request.urlopen(request, timeout=60) as response, temporary.open("wb") as output:
        shutil.copyfileobj(response, output)
    if hashlib.sha256(temporary.read_bytes()).hexdigest() != ARCHIVES[name]:
        temporary.unlink()
        raise RuntimeError(f"SHA-256 mismatch: {name}")
    temporary.replace(destination)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="/tmp/kikori-godot-tools")
    args = parser.parse_args()
    destination = Path(args.directory).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    for name in ARCHIVES:
        download(name, destination / name)
    with zipfile.ZipFile(destination / next(iter(ARCHIVES))) as archive:
        executable = f"Godot_v{VERSION}-stable_linux.x86_64"
        with archive.open(executable) as source, (destination / "godot").open("wb") as output:
            shutil.copyfileobj(source, output)
    (destination / "godot").chmod(0o755)
    data = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    templates = data / "godot/export_templates" / f"{VERSION}.stable"
    templates.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination / f"Godot_v{VERSION}-stable_export_templates.tpz") as archive:
        for name in ["web_nothreads_debug.zip", "web_nothreads_release.zip"]:
            with archive.open(f"templates/{name}") as source, (templates / name).open("wb") as output:
                shutil.copyfileobj(source, output)
    print(f"Godot installed: {destination / 'godot'}")
    if os.environ.get("GITHUB_PATH"):
        with open(os.environ["GITHUB_PATH"], "a") as path_file:
            path_file.write(str(destination) + "\n")


if __name__ == "__main__":
    main()
