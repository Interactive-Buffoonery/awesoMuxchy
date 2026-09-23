#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
swift_bin="$repo_root/.build/toolchains/swift/usr/bin/swift"
zig_bin="$repo_root/.build/toolchains/zig/zig"
package_root="$repo_root/swift-gtk"
profile_root="$repo_root/.build/dev-profile"
compat_lib="$repo_root/.build/toolchains/compat/usr/lib/x86_64-linux-gnu"
if [[ -d "$compat_lib" ]]; then
  export LD_LIBRARY_PATH="$compat_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

[[ -x "$swift_bin" ]] || {
  echo "Verified Swift 6.3.3 is missing at $swift_bin. See docs/development.md." >&2
  exit 1
}
[[ -x "$zig_bin" ]] || {
  echo "Verified Zig 0.16.0 is missing at $zig_bin. See docs/development.md." >&2
  exit 1
}
"$swift_bin" --version | grep -q 'Swift version 6.3.3' || {
  echo "The repo-local Swift toolchain must be 6.3.3." >&2
  exit 1
}
[[ "$("$zig_bin" version)" == "0.16.0" ]] || {
  echo "The repo-local Zig toolchain must be 0.16.0." >&2
  exit 1
}
pkg-config --exists gtk4 atk || {
  echo "GTK4 and ATK development metadata are required (pkg-config gtk4 atk)." >&2
  exit 1
}
[[ -f /usr/share/gir-1.0/Atk-1.0.gir ]] || {
  echo "The ATK GIR is missing at /usr/share/gir-1.0/Atk-1.0.gir." >&2
  exit 1
}

mkdir -p "$profile_root/state" "$profile_root/config"
export XDG_STATE_HOME="$profile_root/state"
export XDG_CONFIG_HOME="$profile_root/config"
export AWESOMUX_DEVELOPMENT=1
export AWESOMUX_BUILD_JOBS="${AWESOMUX_BUILD_JOBS:-2}"
export PATH="$repo_root/.build/toolchains/swift/usr/bin:$repo_root/.build/toolchains/zig:$PATH"

# The existing build wrapper patches the resolved gir2swift checkout. Resolve
# the lockfile first when that checkout is absent; SwiftPM may need network on
# this first run, but no system packages are installed.
if [[ ! -d "$package_root/.build/checkouts/gir2swift/.git" ]]; then
  "$swift_bin" package --package-path "$package_root" resolve --force-resolved-versions
fi

exec "$repo_root/script/run-swift-gtk.sh" "$@"
