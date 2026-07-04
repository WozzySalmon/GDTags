# CI: Windows Native Builds

The repo uses GitHub Actions to build and package Windows GDExtension binaries from the Linux-managed source tree.

Workflow file:

```text
.github/workflows/windows-native.yml
```

## What the workflow does

On `push`, `pull_request`, or manual `workflow_dispatch`, the `windows-native` job runs on `windows-latest` and:

1. Checks out the repo.
2. Installs Python + SCons.
3. Clones `godot-cpp` at the verified compatibility baseline:

   ```text
   godot-4.5-stable
   ```

   This baseline is used because it has been verified to produce binaries that load in both Godot 4.6.3 and Godot 4.7.

4. Downloads Godot Windows executables for:
   - Godot 4.6.3
   - Godot 4.7
5. Builds the Windows debug DLL.
6. Runs smoke tests in Godot 4.6.3.
7. Runs smoke tests in Godot 4.7.
8. Builds the Windows release DLL.
9. Creates addon zip packages:
   - `gameplay_tags-<version>-windows-native.zip`
   - `gameplay_tags-<version>-gdscript.zip`
10. Uploads the zips as the `gameplay-tags-windows-packages` workflow artifact.

## Run it manually

From the repo on the Linux environment, after committing and pushing the workflow:

```bash
gh workflow run windows-native.yml
```

Watch the run:

```bash
gh run watch
```

List recent runs:

```bash
gh run list --workflow windows-native.yml
```

Download artifacts from the latest completed run:

```bash
gh run download --name gameplay-tags-windows-packages --dir dist-ci
```

Or download a specific run:

```bash
gh run download <run-id> --name gameplay-tags-windows-packages --dir dist-ci
```

## Local versus CI responsibilities

Linux local environment:

```bash
tools/linux/dev_native.sh
tools/linux/test_all_godot_versions.sh
```

Windows CI:

```text
builds Windows .dll files
runs Windows Godot smoke tests
creates release zips
```

Use Windows CI artifacts for Windows native releases rather than trying to cross-compile Windows DLLs from Linux.
