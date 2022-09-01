#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests python3Packages.jq

import json
from pathlib import Path
from typing import Union, Dict

import jq
import requests

# These versions don't have servers
BLACKLIST = [
    "1.2.4",
    "1.2.3",
    "1.2.2",
    "1.2.1",
    "1.1",
    "1.0",
]

# Transforms the version manifest into a dict of {id: url}
MANIFEST_PARSER = jq.compile(
    ".versions "
    '| map(select(.type == "release" or .type == "snapshot")) '  # Ignore alpha/beta versions
    "| [.[] | {key:.id,value:.url}] | from_entries"  # Convert to {id: url}
)

# Transforms the version json into the lock format {url:str, sha1:str, version:str, javaVersion:int}
# If the java version isn't present, defaults to 8
VERSION_PARSER = jq.compile(
    "if .downloads.server "
    "then {url:.downloads.server.url, sha1:.downloads.server.sha1, version:.id, javaVersion:(.javaVersion.majorVersion // 8)} "
    "else null end"
)


def parse_manifest() -> Dict[str, str]:
    """
    Fetches the version manifest from Mojang and runs it through the jq process MANIFEST_PARSER
    Returns its output as {id: url}
    """

    print("Fetching manifest")
    response = requests.get(
        "https://launchermeta.mojang.com/mc/game/version_manifest.json"
    )
    response.raise_for_status()
    return MANIFEST_PARSER.input(response.json()).first()


def parse_version(url) -> Dict[str, Union[str, int]]:
    """
    Fetches the version JSON at the URl and runs it through the jq process VERSION_PARSER
    Returns a dict in the form:
    {
        "url": string,
        "sha1": string,
        "version": string,
        javaVersion: int,
        manifestUrl: string
    }
    """

    print(f"Fetching {url}")
    response = requests.get(url)
    response.raise_for_status()
    return VERSION_PARSER.input(response.json()).first() | {"manifestUrl": url}


def main(versions, lock_file):
    """
    Takes in a dict of the existing version lock, and the output file
    Fetches the version manifest and fetches any missing/changed versions
    Writes the new version lock to the output file
    """

    manifest = parse_manifest()

    try:
        for version, url in manifest.items():
            if (
                not (v := versions.get(version, None))
                or v.get("manifestUrl", None) != url
            ):  # Fetch if version isn't locked or if manifest url changes
                if version in BLACKLIST:
                    continue
                elif (parsed := parse_version(url)) is not None:
                    versions[version] = parsed
                else:
                    print(f"{version} has no server, add to blacklist")
    except KeyboardInterrupt:
        print("Cancelled fetching. Writing and exiting")

    json.dump(versions, lock_file, indent=2)
    lock_file.write("\n")


if __name__ == "__main__":
    lock_path = Path(__file__).parent / "versions.json"
    lock_path.touch()

    versions = (
        {} if lock_path.stat().st_size == 0 else json.loads(lock_path.read_text())
    )

    with lock_path.open("w") as lock_file:
        main(versions, lock_file)
