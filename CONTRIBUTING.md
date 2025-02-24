# Contributing Documentation

## Commit Message Format

```
[scope]: [message]

[body]
```

There is no hard limit on commit message length, because the scope can make commit messages longer.

### Scope

Scope is what the commit modifies.
Scopes should be all-lowercase, except when a part of the scope is explicitly not all lowercase (like `tools/fetchPackwizModpack`).

For packages, the scopes are:

- `build-support` (Unless the change is primarily for one of the later scopes)
- `tools/{toolname}`
- `vanilla-servers`
- `fabric-servers`
- `quilt-servers`
- `legacy-fabric-servers`
- `textile-servers` (Affects all of the 3 previous scopes)
- `paper-servers`
- `velocity-servers`

For modules, the scopes are either:

- `module` (Changes to the main `minecraft-servers` module)
- `modules/{modulename}` (Changes to modules that are either subparts of or separate from `minecraft-servers`)

For tests, the scopes are:

- `tests` (Changes to all tests)
- `tests/{testname}` (Changes to a specific test)

Otherwise:

- `flake` (Applies to either `flake.nix` or the flake as a whole)
- `meta` (Changes to documentation about the repository itself, or repository configuration files like `.gitignore`. Notably, the readme, todo, and contributing file. Changelog changes should be included in the commit that introduces the relevant change)
- `bump` (Bumps the version of something)

### Message

Do not capitalize the first letter of commit messages.
If you are adding in a new package, tool, test, etc, the message should be `init`.
Packages should have an update script called `update.py`, which hooks into the existing auto-update automation.
Otherwise, the message should be short, descriptive, and in the present tense.

### Body

There are no particular rules for the body. If something deserves an explanation, then explain it in-depth here.

## Formatting

All files should be formatted with `nixfmt-rfc-style`.
This is linted by a PR check.

## Checks

Please run `nix flake check` before submitting a PR.
This will run some basic package tests, as well as check formatting.

## PR Ettique/Policies

### Including Upstream Changes

Please rebase on top of master to include upstream changes, instead of merging in upstream changes.
This helps keep the commit history of your PR clean.

## Meta files

### Changelog

The changelog should be updated for any major and breaking changes to the repository. Namely, when things are deprecated and when things are removed.

### TODO

Things that should get done in the future. If you feel like something needs work, feel free to include changes to TODO in your PR.
