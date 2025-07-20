# YouTube Subtitle Summarizer

A tool to download YouTube subtitles and generate AI-powered summaries.

## Features

- Download automatic subtitles from YouTube videos
- Generate high-quality summaries using AI
- Handle long videos with automatic chunking
- Flexible configuration via environment variables
- Colorful logging with debug mode support

## Dependencies

- `yt-dlp` - YouTube video/subtitle downloader
- `xmllint` - XML parsing utility (part of libxml2-utils)
- `aichat` - AI-powered summarization tool

## Installation

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install libxml2-utils
pip install yt-dlp

# Install aichat (see official documentation for details)
# https://github.com/sigoden/aichat

# Clone and setup the script
git clone https://github.com/Kohei-Wada/yt-summary.git
cd yt-summary
chmod +x yt-summary.sh
```

## Usage

### Basic Usage

```bash
./yt-summary.sh "https://youtube.com/watch?v=VIDEO_ID"
```

### With Options

```bash
./yt-summary.sh "URL" "LANGUAGE" "FORMAT" "PROMPT"

# Example: Japanese subtitles
./yt-summary.sh "https://youtube.com/watch?v=VIDEO_ID" "ja"

# Example: Custom prompt
./yt-summary.sh "https://youtube.com/watch?v=VIDEO_ID" "en" "ttml" "List the main technical points"
```

### Using Environment Variables

```bash
# Set default language to Japanese
export YT_SUMMARY_LANG=ja

# Run in debug mode
YT_SUMMARY_LOG_LEVEL=debug ./yt-summary.sh "URL"

# Customize chunk sizes
export YT_SUMMARY_MAX_CHUNK_SIZE=20000
export YT_SUMMARY_CHUNK_SIZE=12000
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `YT_SUMMARY_LANG` | Default subtitle language | `en-orig` |
| `YT_SUMMARY_FORMAT` | Subtitle format | `ttml` |
| `YT_SUMMARY_PROMPT` | AI summarization prompt | `Summarize the subtitles in Japanese.` |
| `YT_SUMMARY_MAX_CHUNK_SIZE` | Max text size before chunking | `15000` |
| `YT_SUMMARY_CHUNK_SIZE` | Size of each chunk when splitting | `10000` |
| `YT_SUMMARY_LOG_LEVEL` | Log level (error/info/debug) | `info` |

## Help

```bash
./yt-summary.sh --help
```

## Troubleshooting

### Subtitles Not Found

```bash
# Check available subtitles in debug mode
YT_SUMMARY_LOG_LEVEL=debug ./yt-summary.sh "URL"
```

### View Only Errors

```bash
# Show only error messages
YT_SUMMARY_LOG_LEVEL=error ./yt-summary.sh "URL"
```

## License

MIT License