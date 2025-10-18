#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.packaging python3Packages.requests python3Packages.requests-cache

import argparse
import base64
import concurrent.futures
import json
import re
import subprocess
import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, NotRequired, TypedDict

import requests
import requests_cache
from packaging.version import InvalidVersion, Version
from requests.adapters import HTTPAdapter, Retry

# Versions before 20.5 do not always support the "fat jar" feature. As such,
# they always try to download server mappings, and there's no way to bypass it.
MIN_SUPPORTED_VERSION = Version("20.4.240")

MINECRAFT_MANIFEST = "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json"
NEOFORGE_API = (
    "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge"
)
NEOFORGE_MAVEN = "https://maven.neoforged.net/releases/net/neoforged/neoforge"

TIMEOUT = 5
RETRIES = 5
THREADS = 8


class FetchUrl(TypedDict):
    name: NotRequired[str]
    url: str
    hash: str


class GameVersionLock(TypedDict):
    mappings: FetchUrl


class LoaderLock(TypedDict):
    src: FetchUrl
    libraries: List[str]


# game version -> build version -> version details
LoaderLocks = Dict[str, Dict[str, LoaderLock]]


class TimeoutHTTPAdapter(HTTPAdapter):
    def __init__(self, *args, **kwargs):
        self.timeout = TIMEOUT
        if "timeout" in kwargs:
            self.timeout = kwargs["timeout"]
            del kwargs["timeout"]
        super().__init__(*args, **kwargs)

    def send(self, request, **kwargs):
        timeout = kwargs.get("timeout")
        if timeout is None:
            kwargs["timeout"] = self.timeout
        return super().send(request, **kwargs)


def make_client() -> requests_cache.CachedSession:
    # configure a cache for faster local development
    # mostly for ".sha256" files that should never change
    client = requests_cache.CachedSession(backend="filesystem", cache_control=True)
    retries = Retry(
        total=RETRIES, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504]
    )
    client.mount("https://", TimeoutHTTPAdapter(max_retries=retries))
    return client


def sri_hash(alg: str, hex: str):
    return f"{alg}-{base64.b64encode(bytes.fromhex(hex)).decode('utf-8')}"


def fetch_game_versions(client: requests_cache.CachedSession) -> Dict[str, str]:
    print("Fetching game versions")
    response = client.get(MINECRAFT_MANIFEST, expire_after=requests_cache.DO_NOT_CACHE)
    response.raise_for_status()
    data = response.json()
    return {v["id"]: v["url"] for v in data["versions"]}


def fetch_mappings_hash(client: requests_cache.CachedSession, url: str):
    print(f"Fetching manifest: {url}")
    response = client.get(url)
    response.raise_for_status()
    data = response.json()
    server_mappings = data["downloads"]["server_mappings"]
    return GameVersionLock(
        mappings=FetchUrl(
            name=f"{data['id']}-server-mappings.txt",
            url=str(server_mappings["url"]),
            hash=sri_hash("sha1", server_mappings["sha1"]),
        ),
    )


def fetch_installer_hash(client: requests.Session, version: str):
    url = f"{NEOFORGE_MAVEN}/{version}/neoforge-{version}-installer.jar"
    hash_url = f"{url}.sha256"
    response = client.get(hash_url)
    response.raise_for_status()
    return FetchUrl(
        url=url,
        hash=sri_hash("sha256", response.text),
    )


def fetch_library_hashes(src: FetchUrl) -> Dict[str, FetchUrl]:
    # the installer jar is used by the build derivation, so we might as well
    # use nix to fetch/cache it ahead of time
    proc = subprocess.run(
        ["nix-prefetch-url", src["url"], src["hash"], "--print-path"],
        check=True,
        encoding="UTF-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    store_path = proc.stdout.splitlines()[1]

    def library_src(library: Dict[str, Any]):
        artifact = library["downloads"]["artifact"]
        return FetchUrl(
            url=artifact["url"],
            hash=sri_hash("sha1", artifact["sha1"]),
        )

    with zipfile.ZipFile(store_path, "r") as zf:
        with zf.open("install_profile.json", "r") as f:
            profile_data = json.load(f)
            libraries = profile_data["libraries"]

        with zf.open("version.json", "r") as f:
            version_data = json.load(f)
            libraries += version_data["libraries"]

    return {str(lib["name"]): library_src(lib) for lib in libraries}


def fetch_loader_versions(
    client: requests_cache.CachedSession,
) -> Dict[str, List[str]]:  # game version -> build versions
    print("Fetching installer versions")
    response = client.get(NEOFORGE_API, expire_after=requests_cache.DO_NOT_CACHE)
    response.raise_for_status()

    versions = defaultdict(list)
    data = response.json()
    for version in data["versions"]:
        try:
            version = Version(version)
        except InvalidVersion:
            print(f"Skipping unparseable version: {version}")
            continue
        if version.is_prerelease:
            print(f"Skipping pre-release version: {version}")
            continue
        if MIN_SUPPORTED_VERSION > version:
            print(f"Skipping unsupported version: {version}")
            continue

        # first two digits == 1.x game version
        versions[f"1.{version.major}.{version.minor}".removesuffix(".0")].append(
            str(version)
        )
    return versions


def main(
    loader_versions: LoaderLocks,
    game_versions: Dict[str, GameVersionLock],
    library_versions: Dict[str, FetchUrl],
    version_regex,
    client,
):
    print("Starting fetch")

    game_manifest = fetch_game_versions(client)
    loader_manifest = fetch_loader_versions(client)

    to_fetch = []

    for game_version, build_versions in loader_manifest.items():
        if game_version not in game_versions:
            game_versions[game_version] = fetch_mappings_hash(
                client, game_manifest[game_version]
            )

        for build_version in build_versions:
            if re.match(version_regex, build_version) is None:
                print(f"Skip fetching {build_version}: does not match --version")
                continue
            if (
                game_version not in loader_versions
                or build_version not in loader_versions[game_version]
            ):
                to_fetch.append((game_version, build_version))

    print(f"Fetching {len(to_fetch)} loader versions...")

    def fetch_build(versions: tuple[str, str]):
        game_version, version = versions
        print(f"Fetching {version}")
        installer = fetch_installer_hash(client, version)
        return game_version, version, installer, fetch_library_hashes(installer)

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=THREADS) as p:
            for game_version, version, src, library_srcs in p.map(
                fetch_build, to_fetch
            ):
                if game_version not in loader_versions:
                    loader_versions[game_version] = {}
                loader_versions[game_version][version] = LoaderLock(
                    libraries=sorted(library_srcs.keys()),
                    src=src,
                )
                library_versions |= library_srcs
    except KeyboardInterrupt:
        print("Cancelled fetching. Writing and exiting")

    return (loader_versions, game_versions, library_versions)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", type=str, default=r".*", required=False)
    args = parser.parse_args()

    folder = Path(__file__).parent
    loader_path = folder / "loader_locks.json"
    game_path = folder / "game_locks.json"
    library_path = folder / "library_locks.json"
    with (
        open(loader_path, "r") as loader_locks,
        open(game_path, "r") as game_locks,
        open(library_path, "r") as library_locks,
    ):
        loader_versions = (
            {} if loader_path.stat().st_size == 0 else json.load(loader_locks)
        )
        game_versions = {} if game_path.stat().st_size == 0 else json.load(game_locks)
        library_versions = (
            {} if library_path.stat().st_size == 0 else json.load(library_locks)
        )

    (loader_versions, game_versions, library_versions) = main(
        loader_versions,
        game_versions,
        library_versions,
        args.version,
        make_client(),
    )

    with (
        open(loader_path, "w") as loader_locks,
        open(game_path, "w") as game_locks,
        open(library_path, "w") as library_locks,
    ):
        json.dump(
            loader_versions,
            loader_locks,
            indent=2,
            sort_keys=True,
        )
        json.dump(game_versions, game_locks, indent=2, sort_keys=True)
        json.dump(
            library_versions,
            library_locks,
            indent=2,
            sort_keys=True,
        )
