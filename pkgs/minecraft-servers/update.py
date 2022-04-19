#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests python3Packages.dataclasses-json

import json
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
from dataclasses_json import DataClassJsonMixin, LetterCase, config
from marshmallow import fields


@dataclass
class Download(DataClassJsonMixin):
    sha1: str
    size: int
    url: str


@dataclass
class Version(DataClassJsonMixin):
    id: str
    type: str
    url: str
    time: datetime = field(
        metadata=config(
            encoder=datetime.isoformat,
            decoder=datetime.fromisoformat,
            mm_field=fields.DateTime(format="iso"),
        )
    )
    release_time: datetime = field(
        metadata=config(
            encoder=datetime.isoformat,
            decoder=datetime.fromisoformat,
            mm_field=fields.DateTime(format="iso"),
            letter_case=LetterCase.CAMEL,
        )
    )

    def get_manifest(self) -> Any:
        """Return the version's manifest."""
        response = requests.get(self.url)
        response.raise_for_status()
        return response.json()

    def get_downloads(self) -> Dict[str, Download]:
        """
        Return all downloadable files from the version's manifest, in Download
        objects.
        """
        return {
            download_name: Download.from_dict(download_info)
            for download_name, download_info in self.get_manifest()["downloads"].items()
        }

    def get_java_version(self) -> Any:
        """
        Return the java version specified in a version's manifest, if it is
        present. Versions <= 1.6 do not specify this.
        """
        return self.get_manifest().get("javaVersion", {}).get("majorVersion", None)

    def get_server(self) -> Optional[Download]:
        """
        If the version has a server download available, return the Download
        object for the server download. If the version does not have a server
        download avilable, return None.
        """
        downloads = self.get_downloads()
        if "server" in downloads:
            return downloads["server"]
        return None


def get_versions() -> List[Version]:
    """Return a list of Version objects for all available versions."""
    response = requests.get(
        "https://launchermeta.mojang.com/mc/game/version_manifest.json"
    )
    response.raise_for_status()
    data = response.json()
    return [Version.from_dict(version) for version in data["versions"]]


def generate() -> Dict[str, Dict[str, str]]:
    """
    Return a dictionary containing the latest url, sha1 and version for each major
    release.
    """
    versions = {v.id: v for v in get_versions()}

    servers = {
        version: Download.schema().dump(download_info)  # Download -> dict
        for version, download_info in {
            version: value.get_server() for version, value in versions.items()
        }.items()
        if download_info is not None  # versions < 1.2 do not have a server
    }
    for server in servers.values():
        del server["size"]  # don't need it

    for version, server in servers.items():
        server["version"] = versions[version].id
        server["javaVersion"] = versions[version].get_java_version()
    return servers


if __name__ == "__main__":
    with open(Path(__file__).parent / "versions.json", "w") as file:
        json.dump(generate(), file, indent=2)
        file.write("\n")
