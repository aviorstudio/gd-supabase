#!/usr/bin/env bash
set -euo pipefail
bash tests/package_controls.sh dist/@aviorstudio_gd-supabase.zip
npm run test:web
