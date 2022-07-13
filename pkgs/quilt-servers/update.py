#!/usr/bin/env nix-shell
#!nix-shell -i python3.10 -p python310Packages.requests

import json
import subprocess
import requests
import re
from pathlib import Path


def versiontuple(v):
    return tuple(map(int, (v.partition("-")[0].split("."))))


ENDPOINT = "https://meta.quiltmc.org/v3/versions"

# These filters specify which Quilt loader and Minecraft game versions to package.

# Only package Quilt versions greater than 0.17.0 (using QuiltServerLauncher main class)
LOADER_VERSION_FILTER = lambda version: (
    version["separator"] == "." and versiontuple(version["version"]) >= (0, 17, 0)
)

SNAPSHOT_REGEX = re.compile("([0-9]{2})w([0-9]{1,2})[a-z]+")

# Package all game versions supported by Quilt
def GAME_VERSION_FILTER(version):
    snapshotmatch = re.fullmatch(SNAPSHOT_REGEX, version["version"])

    if snapshotmatch == None:
        return versiontuple(version["version"]) >= (1, 18, 2)
    else:
        return tuple(map(int, snapshotmatch.groups())) >= (22, 11)


# Uncomment to package only major releases:
# GAME_VERSION_FILTER = lambda version: version["stable"] and versiontuple(version["version"]) > (1, 18, 2)


def get_game_versions():
    """
    Returns a list of game versions that the Quilt loader supports, filtered
    using the GAME_VERSION_FILTER above. The `version` variable is in the format
    {"verson": string, "stable": bool}
    """
    print("Fetching game versions")
    data = requests.get(f"{ENDPOINT}/game").json()
    return [version["version"] for version in data if GAME_VERSION_FILTER(version)]


def get_loader_versions():
    """
    Returns a list of the Quilt loader versions that should be packaged, filtered
    using the LOADER_VERSION_FILTER above. The `version` variable is in the format
    {"separater": string, "build": int, "maven": string, "version": string, "stable": bool}
    """
    print("Fetching loader versions")
    data = requests.get(f"{ENDPOINT}/loader").json()
    return [version["version"] for version in data if LOADER_VERSION_FILTER(version)]


def fetch_version(game_version, loader_version):
    """
    Return the server json for a given game and loader version
    """
    return requests.get(
        f"{ENDPOINT}/loader/{game_version}/{loader_version}/server/json"
    ).json()


def gen_locks(version, libraries):
    """
    Return the lock information for a given server json, returned in the format
    {
        "mainClass": string,
        "libraries": [
            {"name": string, "url": string, "sha256": string},
            ...
        ]
    }
    """
    ret = {"mainClass": version["mainClass"], "libraries": []}

    for library in version["libraries"]:
        name, url = library["name"], library["url"]

        if not name in libraries:
            print(f"- - - Fetching library {name}")
            ldir, lname, lversion = name.split(":")
            lfilename = f"{lname}-{lversion}.zip"
            lurl = f"{url}{ldir.replace('.', '/')}/{lname}/{lversion}/{lname}-{lversion}.jar"

            lhash = subprocess.run(
                ["nix-prefetch-url", lurl], capture_output=True, encoding="UTF-8"
            ).stdout.rstrip("\n")

            libraries[name] = {"name": lfilename, "url": lurl, "sha256": lhash}
        else:
            pass
            # print(f"- - - Using cached library {name}")

        ret["libraries"].append(name)

    return ret


def main(versions, libraries, locks, lib_locks):
    """
    Fetch the relevant information and update the lockfiles.
    `versions` and `libraries` are data from the existing files, while
    `locks` and `lib_locks` are file objects to be written to
    """
    loader_versions = get_loader_versions()
    game_versions = get_game_versions()

    print("Starting fetch")
    try:
        for loader_version in loader_versions:
            print(f"- Loader: {loader_version}")
            if not versions.get(loader_version, None):
                versions[loader_version] = {}

            for game_version in game_versions:
                if not versions[loader_version].get(game_version, None):
                    print(f"- - Game: {game_version}")
                    versions[loader_version][game_version] = gen_locks(
                        fetch_version(game_version, loader_version), libraries
                    )
                else:
                    print(f"- - Game: {game_version}: Already locked")

    except KeyboardInterrupt:
        print("Cancelled fetching, writing and exiting")

    json.dump(versions, locks, indent=2)
    json.dump(libraries, lib_locks, indent=2)
    locks.write("\n")
    lib_locks.write("\n")


if __name__ == "__main__":
    folder = Path(__file__).parent
    with (
        open(lo := folder / "locks.json", "r") as locks,
        open(li := folder / "libraries.json", "r") as lib_locks,
    ):
        versions = {} if lo.stat().st_size == 0 else json.load(locks)
        libraries = {} if li.stat().st_size == 0 else json.load(lib_locks)

    with (
        open(lo, "w") as locks,
        open(li, "w") as lib_locks,
    ):
        main(versions, libraries, locks, lib_locks)
