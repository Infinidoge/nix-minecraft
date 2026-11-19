#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests python3Packages.aiohttp python3Packages.packaging

import xml
import json
import requests
import hashlib
import asyncio
import aiohttp
from packaging.version import Version
from xml.etree import ElementTree
from pathlib import Path
from requests.adapters import HTTPAdapter, Retry

# I don't recall a good way to retrieve the dependencies of the modloader.
# Either way, the modloader does a good job to vendor its dependencies by itself.
# As it stands, Forge will be installed at runtime. The user will not perciece a difference.
ENDPOINT = "https://maven.minecraftforge.net/releases/net/minecraftforge/forge/maven-metadata.xml"
# https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json

TIMEOUT = 5
RETRIES = 5
output = {}

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

def get_loaders(client):
    print("Fetching loader versions")
    response = client.get(ENDPOINT)
    data = ElementTree.fromstring(response.content)

    return data

async def parseVer(version, session):
    global output
    KV = version.text.split("-")

    out = {
        'url': f"https://maven.minecraftforge.net/net/minecraftforge/forge/{version.text}/forge-{version.text}-installer.jar",
        'sha256': ""
    }

    async with session.get(out['url']) as response:
        out['sha256'] = hashlib.sha256(await response.read()).hexdigest()

    output.setdefault(KV[0], {})
    output[KV[0]][KV[1]] = out

async def main(lock, client):
    print("Starting fetch")

    # I am reusing a lot of code. I couldn't be arsed to support versions lower than 1.5.2
    # Good luck if you want to improve onto this. I only care for 1.7.10+.
    versions_raw = list(get_loaders(client).iter('version'))
    versions = list(filter(lambda version: (Version(version.text.split("-")[0]) >= Version("1.5.2")), versions_raw))

    async with aiohttp.ClientSession() as session:
        await asyncio.gather(*(parseVer(version, session) for version in versions))

    json.dump(output, lock, indent=2)
    lock.write("\n")
    print("Lockfile written")


if __name__ == "__main__":
    folder = Path(__file__).parent
    lock_path = folder / "lock.json"
    asyncio.run(main(open(lock_path, "w"), make_client()))
