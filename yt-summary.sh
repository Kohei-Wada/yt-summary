#!/bin/bash
set -euo pipefail

URL="$1"
SUB_LANGS="${2:-en-orig}"
SUB_FORMAT="${3:-ttml}"
PROMPT="${4:-'Summarize the subtitles in Japanese.'}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

echo "[*] Checking subtitles for $URL"
subs=$(yt-dlp -q --list-subs "$URL")
if [[ -z "$subs" ]]; then
    echo "[!] No subtitles found for $URL"
    exit 1
fi

if echo "$subs" | grep -q "$SUB_LANGS"  > /dev/null; then
    echo "[*] Subtitles for $SUB_LANGS found for $URL"
else
    echo "[!] No subtitles for $SUB_LANGS found for $URL"
    exit 1
fi

echo "[*] Downloading subtitles $SUB_LANGS for $URL"
yt-dlp -q "$URL" --skip-download --write-auto-subs --sub-langs "$SUB_LANGS" --sub-format "$SUB_FORMAT"

echo "[*] Extracting subtitles and summarizing in Japanese..."
sub_file=$(ls *."${SUB_FORMAT}")

xmllint --xpath "//*[local-name()='p']/text()" "$sub_file" | tr -d \\n

echo "[*] Extracting subtitles..."
sub_file=$(ls *."${SUB_FORMAT}")
subtitle_text=$(xmllint --xpath "//*[local-name()='p']/text()" "$sub_file" | tr -d \\n)

char_count=${#subtitle_text}
echo "[*] Subtitle text length: $char_count characters"

if [ "$char_count" -gt 15000 ]; then
    echo "[*] Text too long, creating staged summary..."

    # テキストを複数の部分に分割
    chunk_size=10000
    total_chunks=$(((char_count + chunk_size - 1) / chunk_size))

    echo "[*] Processing $total_chunks chunks..."
    summaries=""

    for i in $(seq 0 $((total_chunks - 1))); do
        start=$((i * chunk_size))
        chunk="${subtitle_text:$start:$chunk_size}"

        echo "[*] Processing chunk $((i + 1))/$total_chunks..."
        chunk_summary=$(echo "$chunk" | aichat "この部分の内容を簡潔に要約して")
        summaries="$summaries\n\nChunk $((i + 1)): $chunk_summary"
    done

    echo "[*] Creating final summary..."
    echo -e "$summaries" | aichat "$PROMPT これらの部分要約を統合して全体の要約を作成して"
else
    echo "[*] Summarizing with aichat..."
    echo "$subtitle_text" | aichat "$PROMPT"
fi

