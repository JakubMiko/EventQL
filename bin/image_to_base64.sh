#!/bin/bash
#
# Helper script to convert image files to base64 data URI format
# for use with GraphQL mutations in GraphiQL
#
# Usage:
#   ./bin/image_to_base64.sh path/to/image.png
#

if [ -z "$1" ]; then
  echo "Usage: $0 <image_file>"
  echo "Example: $0 ~/Downloads/test.png"
  exit 1
fi

IMAGE_FILE="$1"

if [ ! -f "$IMAGE_FILE" ]; then
  echo "Error: File '$IMAGE_FILE' not found"
  exit 1
fi

# Detect content type
CONTENT_TYPE=$(file --mime-type -b "$IMAGE_FILE")

# Convert to base64 (remove newlines)
BASE64_DATA=$(base64 -i "$IMAGE_FILE" | tr -d '\n')

# Output as data URI
echo "data:${CONTENT_TYPE};base64,${BASE64_DATA}"

echo ""
echo "✓ Conversion complete!"
echo "  File: $IMAGE_FILE"
echo "  Content-Type: $CONTENT_TYPE"
echo "  Size: $(wc -c < "$IMAGE_FILE" | tr -d ' ') bytes"
echo "  Base64 Size: ${#BASE64_DATA} characters"
echo ""
echo "Copy the data URI above and use it in GraphiQL as imageData"
