#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests

import json
import requests
from pathlib import Path
from requests.adapters import HTTPAdapter, Retry

ENDPOINT = "https://fill.papermc.io/v3/projects/paper"

TIMEOUT = 5
RETRIES = 5

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


def make_client():
    http = requests.Session()
    retries = Retry(total=RETRIES, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
    http.mount('https://', TimeoutHTTPAdapter(max_retries=retries))
    return http


def get_game_versions(client):
    print("Fetching game versions")
    data = client.get(ENDPOINT).json()
    return [version for versions in reversed(data["versions"].values()) for version in reversed(versions)]


def get_builds(version, client):
    print(f"Fetching builds for {version}")
    data = client.get(f"{ENDPOINT}/versions/{version}/builds").json()
    return reversed(data)


def main(lock, client):
    output = {}
    print("Starting fetch")

    for version in get_game_versions(client):
        version_builds = {}
        for build in get_builds(version, client):
            build_number = build["id"]
            build_sha256 = build["downloads"]["server:default"]["checksums"]["sha256"]
            build_url = build["downloads"]["server:default"]["url"]
            version_builds[build_number] = {
                "url": build_url,
                "sha256": build_sha256,
            }
        if version_builds:
            output[version] = version_builds

    json.dump(output, lock, indent=2)
    lock.write("\n")


if __name__ == "__main__":
    folder = Path(__file__).parent
    lock_path = folder / "lock.json"
    main(open(lock_path, "w"), make_client())
