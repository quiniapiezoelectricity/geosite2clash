#!/bin/bash
# Build a flattened V2Fly domain list and split into:
#   - <prefix>-domain.txt  (wildcards: +. * ?)
#   - <prefix>-regex.txt   (DOMAIN-REGEX,<pattern> — kept exactly as upstream)
# $1 = geosite name (required)
# $2 = output prefix (optional; defaults to geosite name)
# Uses sed -i -- (GNU sed). For macOS, replace -i -- with -i ''.

set -euo pipefail

REPO_URL="https://github.com/v2fly/domain-list-community.git"
REPO_DIR="domain-list-community"
DATA_DIR="$REPO_DIR/data"

geosite="${1:?usage: $0 <geosite> [output-prefix]}"
prefix="${2:-$geosite}"

OUT="tmp.txt"
DOM_OUT="${prefix}-domain.txt"
RX_OUT="${prefix}-regex.txt"

echo "Cloning $REPO_URL..."
git clone --depth=1 "$REPO_URL" >/dev/null 2>&1

fetchList() {
  local name="$1"
  local file="${DATA_DIR}/${name}"
  if [[ -f "$file" ]]; then
    echo "Adding ${name}"
    cat "$file" >> "$OUT"
  else
    echo "[WARN] missing: $name" >&2
  fi
}
export -f fetchList

rm -f "$OUT" "$DOM_OUT" "$RX_OUT"
touch "$OUT"

# seed with primary list
fetchList "$geosite"
sed -i -- 's/#.*//g' "$OUT"

# resolve includes recursively
while grep -q "^include:" "$OUT"; do
  echo "***************************************"
  includeList=$(grep "^include:" "$OUT" \
    | sed 's/^include://;s/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed '/^$/d')
  sed -i -- '/^include:/d' "$OUT"
  for inc in $includeList; do fetchList "$inc"; done
  sed -i -- 's/#.*//g' "$OUT"
done

# normalize formats (+. for normal domains; keep full:/regexp:)
echo "Normalizing $OUT..."
sed -i -- '/^include:/d' "$OUT"
sed -i -- '/^keyword:/d' "$OUT"
sed -i -- 's/#.*//g;/^$/d' "$OUT"
sed -i -- 's/^domain://g' "$OUT"

# protect full:/regexp:
sed -i -- 's/^full:/-full:/g' "$OUT"
sed -i -- 's/^regexp:/-regexp:/g' "$OUT"

# add '+.' to everything not starting with '-'
sed -i -- 's/^[^-]/+.&/g' "$OUT"

# handle stray carriage returns / whitespace / phantom "+." lines
sed -i -- 's/\r$//g' "$OUT"                  # remove CR from CRLF
sed -i -- 's/[[:space:]]\+$//g' "$OUT"       # remove trailing spaces
sed -i -- '/^+\.[[:space:]]*$/d' "$OUT"      # remove lone "+." lines

# restore markers
sed -i -- 's/^-full://g' "$OUT"
sed -i -- 's/^-regexp:/regexp:/g' "$OUT"

# cleanup tags/spaces
sed -i -- 's/@.*$//g' "$OUT"
sed -i -- '/^$/d' "$OUT"
sed -i -- 's/[[:space:]]//g' "$OUT"
sort -u "$OUT" -o "$OUT"

# split into Stash-friendly files
: > "$DOM_OUT"
: > "$RX_OUT"

# regex.txt: keep native regex (no anchors), prefix DOMAIN-REGEX,
grep '^regexp:' "$OUT" | sed 's/^regexp://g' > .rx.tmp || true
if [ -s .rx.tmp ]; then
  sed -i -- 's/@.*$//g; s/[[:space:]]//g; /^$/d' .rx.tmp
  sed -i -- 's/^/DOMAIN-REGEX,/' .rx.tmp
  sort -u .rx.tmp -o "$RX_OUT"
fi
rm -f .rx.tmp

# domains.txt: everything else (wildcards +. * ?)
grep -v '^regexp:' "$OUT" > "$DOM_OUT"
sed -i -- 's/@.*$//g; s/#.*//g; /^$/d; s/[[:space:]]//g' "$DOM_OUT"
sort -u "$DOM_OUT" -o "$DOM_OUT"

echo "Generated:"
echo "  - $DOM_OUT  (domain wildcards)"
echo "  - $RX_OUT   (DOMAIN-REGEX rules)"

rm -rf "$REPO_DIR"
echo "Done."
