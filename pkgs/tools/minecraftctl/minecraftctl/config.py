import json
import os

from .models import ServersJson
from .utils import warn

SERVERS_JSON_DEFAULT_PATH = "/run/minecraft/servers.json"
serversJsonPath = (
    os.environ.get("NIX_MINECRAFT_MINECRAFTCTL_SERVERS_JSON")
    or SERVERS_JSON_DEFAULT_PATH
)


def load_servers_json() -> ServersJson:
    path = serversJsonPath
    if not os.path.exists(path):
        warn(f"Servers definition file does not exist at {path}")
        return ServersJson({})

    with open(path) as f:
        return ServersJson(json.loads(f.read()))
