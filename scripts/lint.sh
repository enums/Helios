#!/usr/bin/env bash

set -euo pipefail

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: swiftlint is not installed. Install SwiftLint and retry." >&2
  exit 127
fi

swiftlint "$@"
