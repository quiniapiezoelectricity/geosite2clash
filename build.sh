#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <geosite> [output_prefix] [-o output_prefix] [-r repo_path]

Options:
  [output_prefix]   (deprecated positional form, same as -o)
  -o, --output      Specify custom output file prefix (default: same as geosite)
  -r, --repo        Specify local path to domain-list-community clone
                    (default: ./domain-list-community)
  -h, --help        Show this help message and exit

Examples:
  $0 geolocation-cn
  $0 geolocation-cn cn
  $0 geolocation-cn -o cn
  $0 apple -r ../domain-list-community
EOF
  exit 0
}

if [ $# -lt 1 ]; then
  usage
fi

GEOSITE="$1"
shift

OUTPREFIX=""
REPO_PATH="domain-list-community"

# --- Backward compatibility ---
# If the next argument exists and doesn't start with a dash, treat it as output prefix.
if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
  OUTPREFIX="$1"
  shift
  echo "[Compat] Using positional output prefix: $OUTPREFIX"
fi

# --- Parse remaining flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      if [ $# -lt 2 ]; then
        echo "Error: $1 requires an argument." >&2
        usage
      fi
      OUTPREFIX="$2"
      shift 2
      ;;
    -r|--repo)
      if [ $# -lt 2 ]; then
        echo "Error: $1 requires an argument." >&2
        usage
      fi
      REPO_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

OUTPREFIX="${OUTPREFIX:-$GEOSITE}"

echo "Building geosite: $GEOSITE"
echo "Output prefix: $OUTPREFIX"
echo "Using repo path: $REPO_PATH"

# --- Clone or update repo ---
if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Cloning domain-list-community into $REPO_PATH..."
  git clone --depth=1 https://github.com/v2fly/domain-list-community.git "$REPO_PATH"
else
  echo "Using cached repo at $REPO_PATH (updating...)"
  (cd "$REPO_PATH" && git fetch origin master --depth=1 && git reset --hard origin/master)
fi

WORKFILE="tmp.txt"
rm -f "$WORKFILE"
touch "$WORKFILE"

fetchList() {
  local name="$1"
  local file="${REPO_PATH}/data/${name}"
  if [[ -f "$file" ]]; then
    echo "Fetching list: ${name}"
    cat "$file" >> "$WORKFILE"
  else
    echo "[WARN] List not found: ${name}" >&2
  fi
}
export -f fetchList

# --- Fetch primary list ---
fetchList "$GEOSITE"
sed -i -- 's/#.*//g' "$WORKFILE"

# --- Resolve includes recursively ---
while grep -q "^include:" "$WORKFILE"; do
  echo "Resolving include directives..."
  includeList=$(grep "^include:" "$WORKFILE" \
    | sed 's/^include://;s/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed '/^$/d')
  sed -i -- '/^include:/d' "$WORKFILE"
  for inc in $includeList; do
    fetchList "$inc"
  done
  sed -i -- 's/#.*//g' "$WORKFILE"
done

echo "Normalizing domain formats..."
# --- Clean and normalize ---
sed -i -- '/^include:/d' "$WORKFILE"
sed -i -- '/^keyword:/d' "$WORKFILE"
sed -i -- 's/#.*//g;/^$/d' "$WORKFILE"
sed -i -- 's/^domain://g' "$WORKFILE"
sed -i -- 's/^full:/-full:/g' "$WORKFILE"
sed -i -- 's/^regexp:/-regexp:/g' "$WORKFILE"
sed -i -- 's/^[^-]/+.&/g' "$WORKFILE"
sed -i -- 's/\r$//g' "$WORKFILE"
sed -i -- 's/[[:space:]]\+$//g' "$WORKFILE"
sed -i -- '/^+\.[[:space:]]*$/d' "$WORKFILE"
sed -i -- 's/^-full://g' "$WORKFILE"
sed -i -- 's/^-regexp:/regexp:/g' "$WORKFILE"
sed -i -- 's/@.*$//g' "$WORKFILE"
sed -i -- '/^$/d' "$WORKFILE"
sed -i -- 's/[[:space:]]//g' "$WORKFILE"
sort -u "$WORKFILE" -o "$WORKFILE"

# --- Output files ---
DOMAIN_FILE="${OUTPREFIX}-domain.txt"
REGEX_FILE="${OUTPREFIX}-regex.txt"
rm -f "$DOMAIN_FILE" "$REGEX_FILE"

grep '^regexp:' "$WORKFILE" | sed 's/^regexp://g' > .rx.tmp || true
if [ -s .rx.tmp ]; then
  sed -i -- 's/@.*$//g; s/[[:space:]]//g; /^$/d' .rx.tmp
  sed -i -- 's/^/DOMAIN-REGEX,/' .rx.tmp
  sort -u .rx.tmp -o "$REGEX_FILE"
fi
rm -f .rx.tmp

grep -v '^regexp:' "$WORKFILE" > "$DOMAIN_FILE"
sed -i -- 's/@.*$//g; s/#.*//g; /^$/d; s/[[:space:]]//g' "$DOMAIN_FILE"
sort -u "$DOMAIN_FILE" -o "$DOMAIN_FILE"

echo
echo "✅ Build complete!"
echo "  • Domain list: $DOMAIN_FILE"
echo "  • Regex list : $REGEX_FILE"
