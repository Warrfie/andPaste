#!/bin/sh
set -eu

APP_DIR="$(sh scripts/build-app.sh)"
open "$APP_DIR"
