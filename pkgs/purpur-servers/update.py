#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests  python3Packages.progressbar

import json
import requests
import hashlib
from pathlib import Path
from requests.adapters import HTTPAdapter, Retry
import time
import progressbar


ENDPOINT = "https://api.purpurmc.org/v2/purpur"

def load_lock(path):
    print("Loading lock file")
    if not path.exists():
        print("└ Creating one from scratch")
        return {}
    with open(path, "r+") as f:
        data = json.load(f)
    return data

def save_lock(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)



def get_versions():
    print("Fetching Versions")
    versions = requests.get(ENDPOINT).json()["versions"]
    print(f"└ Total of {len(versions)} versions")
    return versions

def get_builds(version):
    print(f"Fetching {version} version builds")
    builds = requests.get(f"{ENDPOINT}/{version}").json()["builds"]["all"]
    print(f"└ Total of {len(builds)} builds")
    return builds

def get_build_info(version, build):
    print(f" └ Fetching {build} build info")
    info = requests.get(f"{ENDPOINT}/{version}/{build}").json()
    return info

def get_build_sha256(build_url):
    print(f"    └ Generating SHA256")
    sha256 = hashlib.sha256()
    with requests.get(build_url, stream=True) as response:
        response.raise_for_status()
        for chunk in response.iter_content(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def main(lock_path, bad_path):
    lock_data = load_lock(lock_path)
    bad_data = load_lock(bad_path)
    versions = get_versions();
    for version in versions:

        # When version doesn't exist in lock file
        if version not in lock_data:
            lock_data[version] = {}
            bad_data[version] = []
        builds = get_builds(version)
        updated = 0
        for build in builds:
            if build in lock_data[version]:
                continue
            if build in bad_data[version]:
                continue

            build_info = get_build_info(version, build)


            if build_info["result"] == "FAILURE":
                print(f"   └ Failed to get build info of {build}")
                bad_data[version].append(build)                    
                continue

            build_download = f"{ENDPOINT}/{version}/{build}/download"
            build_sha256 = get_build_sha256(build_download)

            updated += 1
            lock_data[version][build] = {
                "sha256": build_sha256
            }


    save_lock(bad_path, bad_data)
    save_lock(lock_path, lock_data)
    print(f"-> Updated {updated} builds of version {version}")


            
        

if __name__ == "__main__":
    start = time.process_time()
    folder = Path(__file__).parent
    lock_path = Path(folder / "lock.json")
    # Saving builds not found
    bad_path = Path(folder / "bad.json")
    main(lock_path, bad_path)
    end = time.process_time() - start
    print(f"Finished {round(end, 2)}s")


