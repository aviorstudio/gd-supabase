#!/usr/bin/env bash
set -euo pipefail
python3 scripts/package_addon.py build dist/@aviorstudio_gd-supabase.zip
python3 scripts/package_addon.py verify dist/@aviorstudio_gd-supabase.zip
