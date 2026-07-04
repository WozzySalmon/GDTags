#!/usr/bin/env python

import os
import sys

libname = "gameplay_tags"
addondir = os.path.join("addons", "gameplay_tags")

local_env = Environment(tools=["default"], PLATFORM="")

# Optional local overrides, matching the godot-cpp-template workflow.
customs = ["custom.py"]
customs = [os.path.abspath(path) for path in customs]

opts = Variables(customs, ARGUMENTS)
opts.Update(local_env)
Help(opts.GenerateHelpText(local_env))

env = local_env.Clone()

if not (os.path.isdir("godot-cpp") and os.listdir("godot-cpp")):
    print(
        "godot-cpp is not available. Initialize the dependency first:\n\n"
        "    git clone https://github.com/godotengine/godot-cpp.git\n"
        "    git -C godot-cpp submodule update --init --recursive\n",
        file=sys.stderr,
    )
    sys.exit(1)

env = SConscript("godot-cpp/SConstruct", {"env": env, "customs": customs})

env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

# This mirrors godot-cpp-template behavior:
# - .dev does not require a separate .gdextension feature key.
# - .universal is compatible with all relevant architectures.
suffix = env["suffix"].replace(".dev", "").replace(".universal", "")
if env["platform"] == "windows":
    # MinGW cross-compilation on Linux keeps SCons' default "lib" prefix,
    # but Godot/GDExtension Windows feature paths use the MSVC-style name.
    env["SHLIBPREFIX"] = ""
lib_filename = "{}{}{}{}".format(env.subst("$SHLIBPREFIX"), libname, suffix, env.subst("$SHLIBSUFFIX"))

library = env.SharedLibrary(
    "bin/{}/{}".format(env["platform"], lib_filename),
    source=sources,
)

installed_library = env.Install(
    "{}/bin/{}/".format(addondir, env["platform"]),
    library,
)

Default(library, installed_library)
