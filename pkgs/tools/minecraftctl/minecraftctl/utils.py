import sys, subprocess
from typing import Any, List, Never


def printerr(*values: object):
    print(*values, file=sys.stderr)


def warn(*values: object):
    printerr("[WARNING] minecraftctl:", *values)


def fatal(*values: object, exit_code: int = 1) -> Never:
    printerr("[FATAL] minecrafctl:", *values)
    sys.exit(exit_code)


# this doesn't capture stdout/stderr
def exec(cmd: List[str], stdin: str | None = None, env: dict[str, str] | None = None):
    result = subprocess.run(cmd, text=True, input=stdin, env=env)
    if result.returncode != 0:
        err = ChildProcessError(result.stderr)
        err.errno = result.returncode
        raise err


# this captures stdout/stderr
def run(cmd: List[str], stdin: str | None = None) -> str:
    result = subprocess.run(cmd, text=True, input=stdin, capture_output=True)
    if result.returncode != 0:
        err = ChildProcessError(result.stderr)
        err.errno = result.returncode
        raise err
    return result.stdout


def pretty_table(headers: List[str], body: List[List[Any]]) -> str:
    out = ""
    # calculate good-looking length
    max_lens: List[int] = []
    for col_i in range(len(headers)):
        max_len = len(headers[col_i])
        for row_i in range(len(body)):
            max_len = max(max_len, len(str(body[row_i][col_i])))
        max_lens.append(max_len)

    # print header
    for col_i in range(len(headers)):
        width = max_lens[col_i] + 2
        out += f"{headers[col_i]:<{width}}"
    out += "\n"

    # print separator
    out += "-" * (sum(max_lens) + 2 * (len(headers) - 1)) + "\n"

    # print body
    for data in body:
        row = ""
        for col_i in range(len(headers)):
            width = max_lens[col_i] + 2
            cell = str(data[col_i])
            if data[col_i] == None:
                cell = "-"
            row += f"{cell:<{width}}"
        out += row + "\n"
    return out


def get_service_status(serviceName: str) -> str:
    try:
        status = run(["systemctl", "is-active", serviceName])
        return status.replace("\n", "")
    except ChildProcessError as e:
        if e.errno == 3:  # systemctl exits with code 3 if the service is inactive
            return "inactive"
        if len(e.args) == 0 or e.args[0] == "":
            return "Failed to get status"
        else:
            return str(e.args[0])
