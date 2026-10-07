#!/usr/bin/env bash
set -euo pipefail
npm run test:publish
bash tests/gate_controls.sh
bash tests/test.sh
