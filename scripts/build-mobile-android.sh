#!/usr/bin/env bash
# Build with JDK 17 without changing Flutter's global Android Studio/JDK choice.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
jdk_home="${NOISENET_JAVA17_HOME:-}"

if [[ -z "$jdk_home" && -x /usr/libexec/java_home ]]; then
  jdk_home="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
fi
if [[ -z "$jdk_home" && -x /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java ]]; then
  jdk_home=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
fi
if [[ ! -x "$jdk_home/bin/java" ]] || ! "$jdk_home/bin/java" -version 2>&1 | head -1 | grep -Eq 'version "17[.]'; then
  echo 'JDK 17 is required. Set NOISENET_JAVA17_HOME to its home directory.' >&2
  exit 1
fi

export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.java.home=$jdk_home"
cd "$project_root/mobile"
exec flutter build apk --debug "$@"
