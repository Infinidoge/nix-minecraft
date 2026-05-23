#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests python3Packages.jq

import json
import logging
import re
import subprocess
from pathlib import Path

import jq
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()


# TODO: split into a library
def versiontuple(v):
    if isinstance(v, str):
        version = v.partition("-")[0].split(".")
    elif isinstance(v, tuple):
        version = v

    return tuple(map(int, version))


SNAPSHOT_REGEX = re.compile("([0-9]{2})w([0-9]{1,2}).+")


def parse_snapshot(version):
    match = SNAPSHOT_REGEX.fullmatch(version)

    if match:
        return versiontuple(match.groups())
    else:
        return None


ENDPOINT = "https://meta.quiltmc.org/v3/versions"
MAVEN = "https://maven.quiltmc.org/repository/release/"


MINIMUM_LOADER_VERSION = (0, 17, 0)  # loader version
MINIMUM_GAME_VERSION = (1, 18, 2)
MINIMUM_SNAPSHOT_VERSION = (22, 11)

VERSION_MAPPINGS = [
    "intermediary",
    "hashed",
]


# These filters specify which Quilt loader and Minecraft game versions to package.
# Only package Quilt versions greater than 0.17.0 (using QuiltServerLauncher main class)


def LOADER_VERSION_FILTER(version):
    return (
        version["separator"] == "."
        and versiontuple(version["version"]) >= MINIMUM_LOADER_VERSION
    )


# Package all game versions supported by Quilt
def GAME_VERSION_FILTER(version):
    if snapshot := parse_snapshot(version["version"]):
        return snapshot >= MINIMUM_SNAPSHOT_VERSION
    else:
        return versiontuple(version["version"]) >= MINIMUM_GAME_VERSION


# Uncomment to package only major releases:
# GAME_VERSION_FILTER = lambda version: version["stable"] and versiontuple(version["version"]) > (1, 18, 2)


def get(*args: str):
    return requests.get("/".join((ENDPOINT,) + args)).json()


def get_game_versions():
    """
    Returns a list of game versions that the Fabric loader supports, filtered
    using the GAME_VERSION_FILTER above. The `version` variable is in the format
    {"verson": string, "stable": bool}
    """
    logger.info("Fetching game versions")
    data = get("game")
    return [version["version"] for version in data if GAME_VERSION_FILTER(version)]


def get_loader_versions():
    """
    Returns a list of the Fabric loader versions that should be packaged, filtered
    using the LOADER_VERSION_FILTER above. The `version` variable is in the format
    {"separater": string, "build": int, "maven": string, "version": string, "stable": bool}
    """
    logger.info("Fetching loader versions")
    data = get("loader")
    return [version["version"] for version in data if LOADER_VERSION_FILTER(version)]


PROCESS_LOADER_VERSION = jq.compile(
    "{"
    "mainClass: .launcherMeta.mainClass.server,"
    "libraries: ((.launcherMeta.libraries | [.common[], .server[]]) + [{name: .loader.maven, url: $URL}])"
    "}",
    args={"URL": MAVEN},
)


def fetch_loader_version(loader_version):
    """
    Return the loader information for a given loader version
    """
    # Quilt's API doesn't expose loader information without a game version
    game_version = "1.19"

    return PROCESS_LOADER_VERSION.input_value(
        get("loader", game_version, loader_version)
    ).first()


def fetch_game_version(game_version):
    """
    Return game-version-specific libraries for a given game version
    """

    libraries = []

    for library in VERSION_MAPPINGS:
        fetched = get(library, game_version)
        if isinstance(fetched, list):  # TODO: compare against game_version
            libraries.append({"name": fetched[0]["maven"], "url": MAVEN})

    return {"libraries": libraries}


def prefetch_libraries(logger, version_libraries, libraries):
    logger = logger.getChild("libraries")
    ret = []

    for library in version_libraries:
        name, url = library["name"], library["url"]

        if name not in libraries or any(not v for v in libraries[name].values()):
            logger.info(f"Fetching {name}")
            ldir, lname, lversion = name.split(":")
            lfilename = f"{lname}-{lversion}.jar"
            lurl = "/".join(
                (
                    url.rstrip("/"),
                    ldir.replace(".", "/"),
                    lname,
                    lversion,
                    f"{lname}-{lversion}.jar",
                )
            )

            lhash = subprocess.run(
                ["nix-prefetch-url", lurl], capture_output=True, encoding="UTF-8"
            ).stdout.rstrip("\n")

            libraries[name] = {"name": lfilename, "url": lurl, "sha256": lhash}
        else:
            logger.debug(f"Using cached {name}")

        ret.append(name)

    return ret


def gen_loader_locks(logger, version, libraries):
    """
    Return the lock information for a given loader version, returned in the format
    {
        "mainClass": string,
        "libraries": [
            {"name": string, "url": string, "sha256": string},
            ...
        ]
    }
    """
    ret = {
        "mainClass": version["mainClass"],
        "libraries": prefetch_libraries(logger, version["libraries"], libraries),
    }

    return ret


def gen_game_locks(logger, version, libraries):
    """
    Return the lock information for a given loader version, returned in the format
    {
        "libraries": [
            {"name": string, "url": string, "sha256": string},
            ...
        ]
    }
    """
    return {"libraries": prefetch_libraries(logger, version["libraries"], libraries)}


def main(
    versions_loader, versions_game, libraries, loader_locks, game_locks, lib_locks
):
    """
    Fetch the relevant information and update the lockfiles.
    `versions` and `libraries` are data from the existing files, while
    `locks` and `lib_locks` are file objects to be written to
    """
    loader_versions = get_loader_versions()
    game_versions = get_game_versions()

    logger.info("Starting fetch")
    try:
        logger.info("Fetching loader versions")
        loader_logger = logger.getChild("loader")
        for loader_version in loader_versions:
            if not versions_loader.get(loader_version, None):
                loader_logger.info(f"Fetching version: {loader_version}")
                versions_loader[loader_version] = gen_loader_locks(
                    loader_logger, fetch_loader_version(loader_version), libraries
                )
            else:
                loader_logger.info(f"Version {loader_version} already locked")

        logger.info("Fetching game versions")
        game_logger = logger.getChild("game")
        for game_version in game_versions:
            if not versions_game.get(game_version, None):
                game_logger.info(f"Fetching version: {game_version}")
                versions_game[game_version] = gen_game_locks(
                    game_logger, fetch_game_version(game_version), libraries
                )
            else:
                game_logger.info(f"Version {game_version} already locked")

    except KeyboardInterrupt:
        logger.warning("Cancelled fetching, writing and exiting")

    json.dump(versions_loader, loader_locks, indent=2)
    json.dump(versions_game, game_locks, indent=2)
    json.dump(libraries, lib_locks, indent=2)
    loader_locks.write("\n")
    game_locks.write("\n")
    lib_locks.write("\n")


if __name__ == "__main__":
    folder = Path(__file__).parent
    llo = folder / "loader_locks.json"
    glo = folder / "game_locks.json"
    llo.touch()
    glo.touch()

    build_support_folder = folder.parent / "build-support"
    li = build_support_folder / "libraries.json"
    li.touch()

    with (
        open(llo, "r") as loader_locks,
        open(glo, "r") as game_locks,
        open(li, "r") as lib_locks,
    ):
        versions_loader = {} if llo.stat().st_size == 0 else json.load(loader_locks)
        versions_game = {} if glo.stat().st_size == 0 else json.load(game_locks)
        libraries = {} if li.stat().st_size == 0 else json.load(lib_locks)

    with (
        open(llo, "w") as loader_locks,
        open(glo, "w") as game_locks,
        open(li, "w") as lib_locks,
    ):
        main(
            versions_loader,
            versions_game,
            libraries,
            loader_locks,
            game_locks,
            lib_locks,
        )
