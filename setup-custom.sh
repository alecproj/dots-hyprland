#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run() {
  echo
  echo "==> $1"
  bash "$ROOT/custom/modules/$1"
}

WITH_PERSONAL=false

for arg in "$@"; do
  case "$arg" in
    --personal)
      WITH_PERSONAL=true
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: ./setup-custom.sh [--personal]"
      exit 1
      ;;
  esac
done

run 00-packages-custom.sh
run 10-hypr-custom.sh
run 20-user-dirs.sh
run 21-greetd-regreet.sh

if [[ "$WITH_PERSONAL" == true ]]; then
  run 01-packages-personal.sh
fi

echo
echo "Custom setup finished."
