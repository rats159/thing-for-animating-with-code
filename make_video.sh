#!/bin/bash

# Set the input directory and output video file
INPUT_DIR="./out"
OUTPUT_VIDEO="output.mp4"
FRAME_RATE=30

# Check if the input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Directory $INPUT_DIR does not exist."
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg could not be found. Please install ffmpeg and retry."
    exit 1
fi

# Create the video using ffmpeg
# This example uses -pattern_type glob (for shells that support it) and assumes
# the images have the extension .png. If your images are different (e.g., .jpg), change the pattern.
ffmpeg -framerate $FRAME_RATE -pattern_type glob -i "$INPUT_DIR/*.png" \
    -c:v libx264 -pix_fmt yuv420p \
    "$OUTPUT_VIDEO"

echo "Video created: $OUTPUT_VIDEO"