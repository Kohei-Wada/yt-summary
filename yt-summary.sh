#!/bin/bash
set -euo pipefail

# Configuration with environment variable support
SCRIPT_NAME="$(basename "$0")"
DEFAULT_LANG="${YT_SUMMARY_LANG:-en-orig}"
DEFAULT_FORMAT="${YT_SUMMARY_FORMAT:-ttml}"
DEFAULT_PROMPT="${YT_SUMMARY_PROMPT:-以下の字幕を日本語で要約してください。見出しと段落を使って読みやすく整形してください。}"
MAX_CHUNK_SIZE="${YT_SUMMARY_MAX_CHUNK_SIZE:-15000}"
CHUNK_SIZE="${YT_SUMMARY_CHUNK_SIZE:-10000}"
LOG_LEVEL="${YT_SUMMARY_LOG_LEVEL:-info}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_error() {
    if [[ "$LOG_LEVEL" != "quiet" ]]; then
        echo -e "${RED}[ERROR]${NC} $*" >&2
    fi
}

log_info() {
    if [[ "$LOG_LEVEL" != "error" ]] && [[ "$LOG_LEVEL" != "quiet" ]]; then
        echo -e "${GREEN}[INFO]${NC} $*"
    fi
}

log_debug() {
    if [[ "$LOG_LEVEL" == "debug" ]]; then
        echo -e "${YELLOW}[DEBUG]${NC} $*"
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME URL [LANG] [FORMAT] [PROMPT]

Download YouTube subtitles and generate AI-powered summary.

Arguments:
  URL      YouTube video URL (required)
  LANG     Subtitle language (default: $DEFAULT_LANG)
  FORMAT   Subtitle format (default: $DEFAULT_FORMAT)
  PROMPT   AI summarization prompt (default: "$DEFAULT_PROMPT")

Environment Variables:
  YT_SUMMARY_LANG          Default subtitle language
  YT_SUMMARY_FORMAT        Default subtitle format
  YT_SUMMARY_PROMPT        Default summarization prompt
  YT_SUMMARY_MAX_CHUNK_SIZE Maximum text size before chunking (default: 15000)
  YT_SUMMARY_CHUNK_SIZE    Size of each chunk when splitting (default: 10000)
  YT_SUMMARY_LOG_LEVEL     Log level: quiet, error, info, debug (default: info)

Examples:
  $SCRIPT_NAME "https://youtube.com/watch?v=VIDEO_ID"
  $SCRIPT_NAME "https://youtube.com/watch?v=VIDEO_ID" "ja"
  YT_SUMMARY_LOG_LEVEL=debug $SCRIPT_NAME "https://youtube.com/watch?v=VIDEO_ID"
  YT_SUMMARY_LOG_LEVEL=quiet $SCRIPT_NAME "https://youtube.com/watch?v=VIDEO_ID"
EOF
}

# Validate dependencies
check_dependencies() {
    local deps=("yt-dlp" "xmllint" "aichat")
    local missing=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install them before running this script."
        exit 1
    fi
}

# Get video title
get_video_title() {
    local url="$1"
    
    log_debug "Fetching video title"
    
    local title
    if ! title=$(yt-dlp -q --get-title "$url" 2>&1); then
        log_error "Failed to get video title: $title"
        return 1
    fi
    
    echo "$title"
}

# Check if subtitles are available
check_subtitles() {
    local url="$1"
    local lang="$2"
    
    log_info "Checking subtitles for $url"
    
    local subs
    if ! subs=$(yt-dlp -q --list-subs "$url" 2>&1); then
        log_error "Failed to check subtitles: $subs"
        return 1
    fi
    
    if [[ -z "$subs" ]]; then
        log_error "No subtitles found for $url"
        return 1
    fi
    
    if echo "$subs" | grep -q "$lang" > /dev/null; then
        log_info "Subtitles for '$lang' found"
        return 0
    else
        log_error "No subtitles for '$lang' found"
        log_debug "Available subtitles:\n$subs"
        return 1
    fi
}

# Download subtitles
download_subtitles() {
    local url="$1"
    local lang="$2"
    local format="$3"
    
    log_info "Downloading subtitles ($lang) in $format format"
    
    if ! yt-dlp -q "$url" \
        --skip-download \
        --write-auto-subs \
        --sub-langs "$lang" \
        --sub-format "$format" 2>&1; then
        log_error "Failed to download subtitles"
        return 1
    fi
    
    return 0
}

# Extract text from subtitles
extract_subtitle_text() {
    local format="$1"
    
    log_info "Extracting text from subtitles"
    
    local sub_file
    sub_file=$(ls *."${format}" 2>/dev/null | head -n 1)
    
    if [[ -z "$sub_file" ]]; then
        log_error "No subtitle file found with format: $format"
        return 1
    fi
    
    log_debug "Processing subtitle file: $sub_file"
    
    local text
    if ! text=$(xmllint --xpath "//*[local-name()='p']/text()" "$sub_file" 2>/dev/null | tr -d '\n'); then
        log_error "Failed to extract text from subtitle file"
        return 1
    fi
    
    echo "$text"
}

# Summarize text using AI
summarize_text() {
    local text="$1"
    local prompt="$2"
    
    local char_count=${#text}
    log_info "Text length: $char_count characters"
    
    if [[ $char_count -gt $MAX_CHUNK_SIZE ]]; then
        summarize_chunked_text "$text" "$prompt"
    else
        log_info "Summarizing with AI"
        echo "$text" | aichat "$prompt"
    fi
}

# Summarize long text in chunks
summarize_chunked_text() {
    local text="$1"
    local prompt="$2"
    
    local char_count=${#text}
    local total_chunks=$(((char_count + CHUNK_SIZE - 1) / CHUNK_SIZE))
    
    log_info "Text too long, creating staged summary with $total_chunks chunks"
    
    local summaries=""
    local chunk_prompt="この部分の内容を簡潔に要約してください。箇条書きや短い段落を使ってください。"
    
    for i in $(seq 0 $((total_chunks - 1))); do
        local start=$((i * CHUNK_SIZE))
        local chunk="${text:$start:$CHUNK_SIZE}"
        
        log_info "Processing chunk $((i + 1))/$total_chunks"
        
        local chunk_summary
        if ! chunk_summary=$(echo "$chunk" | aichat "$chunk_prompt"); then
            log_error "Failed to summarize chunk $((i + 1))"
            return 1
        fi
        
        summaries="$summaries\n\nChunk $((i + 1)): $chunk_summary"
    done
    
    log_info "Creating final summary from chunks"
    echo -e "$summaries" | aichat "$prompt これらの部分要約を統合して、見出しと段落を使った読みやすい全体要約を作成してください。重要なポイントは箇条書きにしてください。"
}

# Main function
main() {
    # Parse arguments
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    local url="$1"
    local lang="${2:-$DEFAULT_LANG}"
    local format="${3:-$DEFAULT_FORMAT}"
    local prompt="${4:-$DEFAULT_PROMPT}"
    
    # Validate URL
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Invalid URL: $url"
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Create temporary directory
    local tmpdir
    tmpdir=$(mktemp -d -t yt-summary-XXXXXX)
    
    log_debug "Working directory: $tmpdir"
    cd "$tmpdir"
    
    # Get and display video title
    local video_title
    if video_title=$(get_video_title "$url"); then
        echo -e "\n${GREEN}Video Title:${NC} $video_title\n"
    fi
    
    # Check if subtitles are available
    if ! check_subtitles "$url" "$lang"; then
        exit 1
    fi
    
    # Download subtitles
    if ! download_subtitles "$url" "$lang" "$format"; then
        exit 1
    fi
    
    # Extract text
    local subtitle_text
    if ! subtitle_text=$(extract_subtitle_text "$format"); then
        exit 1
    fi
    
    # Summarize
    if ! summarize_text "$subtitle_text" "$prompt"; then
        log_error "Failed to generate summary"
        exit 1
    fi
}

# Run main function
main "$@"

