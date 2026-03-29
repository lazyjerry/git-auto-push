---
name: bump-version
description: Bump version number in ai-global script and package.json
argument-hint: new version number (e.g., "1.1.0")
---

You are tasked with updating the version number across the project. The version must be kept in sync between two files.

## Files to update:

1. **`ai-global`** (line ~7): `VERSION="x.y.z"`
2. **`package.json`** (line ~3): `"version": "x.y.z"`

## Steps to follow:

1. Read the current version from `ai-global` (`VERSION="..."`)
2. Validate the new version follows [Semantic Versioning](https://semver.org/) format (`MAJOR.MINOR.PATCH`)
3. Update both files with the new version number
4. Confirm the changes by showing old → new version

## Versioning guidelines:

- **MAJOR** — incompatible changes (breaking CLI interface, removing commands)
- **MINOR** — new features (new commands, new tool support)
- **PATCH** — bug fixes, documentation, minor improvements

## Example:

```
Current: 1.0.0
New:     1.1.0

ai-global:    VERSION="1.0.0"  →  VERSION="1.1.0"
package.json: "version": "1.0.0"  →  "version": "1.1.0"
```
