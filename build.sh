#!/usr/bin/env bash
# Renders training/*.md to HTML. Needs pandoc 3.8+. Re-run after editing any training page.
set -euo pipefail

cd "$(dirname "$0")/training"

for md in *.md; do
  page="${md%.md}"
  pandoc "$md" \
    --from gfm --to html5 --standalone \
    --template build/template.html \
    --lua-filter build/filter.lua \
    --syntax-highlighting=none \
    --variable "page-$page=true" \
    --output "$page.html"
  echo "training/$page.html"
done
