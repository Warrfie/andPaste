#!/bin/sh
set -eu

APP_DIR="$(sh scripts/build-app.sh)"
open -n "$APP_DIR"
