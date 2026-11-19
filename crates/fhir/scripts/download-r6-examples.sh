#!/usr/bin/env bash
#
# download-r6-examples.sh
#
# Replaces the checked-in R6 example corpus under crates/fhir/tests/data/{json,xml}/R6
# with the current examples from the HL7 build server (build.fhir.org).
#
# build.fhir.org is a rolling build, so refresh these together with the R6 spec
# definitions (see RELEASING.md). Mixing builds shows up as test_r6_json_examples
# failures.
#
# Usage:
#   ./crates/fhir/scripts/download-r6-examples.sh
#
# Requires curl and unzip.

set -euo pipefail

FHIR_CRATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON_DIR="$FHIR_CRATE_DIR/tests/data/json/R6"
XML_DIR="$FHIR_CRATE_DIR/tests/data/xml/R6"

JSON_URL="https://build.fhir.org/examples-json.zip"
XML_URL="https://build.fhir.org/examples.zip"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fetch() {
    local url="$1" out="$2"
    echo "Downloading $url"
    curl --fail --location --progress-bar --retry 3 --retry-delay 5 \
        --max-time 600 --output "$out" "$url"
    # build.fhir.org answers some failures with an HTML page and HTTP 200.
    if ! unzip -tq "$out" >/dev/null; then
        echo "error: $url did not return a valid zip archive" >&2
        exit 1
    fi
}

replace_corpus() {
    local zip="$1" dir="$2"
    echo "Replacing $dir"
    rm -rf "$dir"
    mkdir -p "$dir"
    unzip -q "$zip" -d "$dir"
}

# Fetch and validate both archives before touching the tree, so a failed
# download never leaves JSON and XML from different builds.
fetch "$JSON_URL" "$WORK_DIR/examples-json.zip"
fetch "$XML_URL" "$WORK_DIR/examples-xml.zip"

replace_corpus "$WORK_DIR/examples-json.zip" "$JSON_DIR"
replace_corpus "$WORK_DIR/examples-xml.zip" "$XML_DIR"

echo "R6 examples refreshed. Review with: git status -- $JSON_DIR $XML_DIR"
