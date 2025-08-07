#!/bin/bash

APP_NAME="RallyTripMeter"
OUTPUT_FILE="bin/${APP_NAME}.prg"
KEY_FILE="developer_key.der"
MANIFEST="manifest.xml"
JUNGLES="monkey.jungle"

echo "Building Garmin app..."

monkeyc \
  --output $OUTPUT_FILE \
  --private-key $KEY_FILE \
  --jungles $JUNGLES

if [ $? -eq 0 ]; then
  echo "Build successful: $OUTPUT_FILE"
else
  echo "Build failed."
fi
