#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="$script_dir/source-pdfs"
mkdir -p "$output_dir"

download() {
  local filename="$1"
  local url="$2"
  local temporary="$output_dir/$filename.tmp"

  if [[ -f "$output_dir/$filename" ]] && pdfinfo "$output_dir/$filename" >/dev/null 2>&1; then
    printf 'Using existing valid PDF: %s\n' "$filename"
    return
  fi

  rm -f "$temporary"
  curl \
    --fail \
    --http1.1 \
    --location \
    --retry 5 \
    --retry-all-errors \
    --output "$temporary" \
    "$url"
  mv "$temporary" "$output_dir/$filename"
}

download \
  "cambridge-yle-word-list-2025.pdf" \
  "https://www.cambridgeenglish.org/Images/739104-starters-movers-flyers-word-list-2025.pdf"
download \
  "cambridge-a2-key-vocabulary-list-2025.pdf" \
  "https://www.cambridgeenglish.org/images/506886-a2-key-2020-vocabulary-list.pdf"
download \
  "cambridge-b1-preliminary-vocabulary-list-2025.pdf" \
  "https://www.cambridgeenglish.org/Images/506887-b1-preliminary-vocabulary-list.pdf"
download \
  "cambridge-b2-first-information-for-candidates.pdf" \
  "https://www.cambridgeenglish.org/Images/608126-b2-first-information-for-candidates-booklet.pdf"
download \
  "vocabulary-in-use-elementary-frontmatter.pdf" \
  "https://assets.cambridge.org/97813166/31522/frontmatter/9781316631522_frontmatter.pdf"
download \
  "vocabulary-in-use-elementary-index.pdf" \
  "https://assets.cambridge.org/97813166/31522/index/9781316631522_index.pdf"
download \
  "vocabulary-in-use-pre-intermediate-frontmatter.pdf" \
  "https://assets.cambridge.org/97813166/28317/frontmatter/9781316628317_frontmatter.pdf"
download \
  "vocabulary-in-use-pre-intermediate-index.pdf" \
  "https://assets.cambridge.org/97813166/28317/index/9781316628317_index.pdf"
download \
  "vocabulary-in-use-upper-intermediate-frontmatter.pdf" \
  "https://assets.cambridge.org/97813166/31744/frontmatter/9781316631744_frontmatter.pdf"
download \
  "vocabulary-in-use-upper-intermediate-index.pdf" \
  "https://assets.cambridge.org/97813166/31744/index/9781316631744_index.pdf"
download \
  "vocabulary-in-use-advanced-frontmatter.pdf" \
  "https://assets.cambridge.org/97813166/30068/frontmatter/9781316630068_frontmatter.pdf"
download \
  "vocabulary-in-use-advanced-index.pdf" \
  "https://assets.cambridge.org/97813166/30068/index/9781316630068_index.pdf"

(
  cd "$output_dir"
  sha256sum ./*.pdf > SHA256SUMS
  for pdf in ./*.pdf; do
    printf '===== %s =====\n' "${pdf#./}"
    pdfinfo "$pdf" | grep -E '^(Title|Author|Creator|Producer|CreationDate|ModDate|Pages|File size|PDF version):'
    printf '\n'
  done > pdfinfo.txt
)

printf 'Downloaded and verified Cambridge sources in %s\n' "$output_dir"
