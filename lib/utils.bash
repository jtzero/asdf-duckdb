#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/duckdb/duckdb"
TOOL_NAME="duckdb"
TOOL_TEST="duckdb --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if duckdb is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  local -r tags_block="$(list_github_tags)"
  tags=()
  while IFS= read -r tag; do
    printf "%s\n" "${tag}-cli"
  done <<<"${tags_block}"
}

get_download_file() {
  local version filename url
  version="$1"
  filename="$2"
  echo "::::::::${version}-${filename}"
  exit 0
}

get_operating_system_name() {
  uname -s
}

get_hardware_name() {
  uname -m
}

get_install_type() {
  local operating_system_name="$(get_operating_system_name | tr '[:upper:]' '[:lower:]')"
  local hardware_name="$(get_hardware_name)"
  if [ "${operating_system_name}" = "darwin" ]; then
    operating_system_name="osx"
    hardware_name="universal"
  elif [ "${hardware_name}" = "x86_64" ]; then
    hardware_name="i386"
  fi
  printf "%s" "${operating_system_name}-${hardware_name}"
}

download_release() {
  local version filename url
  version_and_type="$1"
  filename="$2"

  local version="${version_and_type}"
  local type=""
  if grep -q -e "-cli" <<<"${version_and_type}"; then
    version="$(cut -d'-' -f1 <<<"${version_and_type}")"
    type="$(cut -d'-' -f2 <<<"${version_and_type}")"
  fi

  if [ "${type}" != "cli" ]; then
    fail "install type=${type} is not currently supported"
  fi

  local -r install_type="$(get_install_type)"

  url="$GH_REPO/releases/download/v${version}/duckdb_${type}-${install_type}.zip"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="${3%/bin}/bin"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    # TODO: Assert duckdb executable exists.
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
