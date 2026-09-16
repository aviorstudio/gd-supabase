import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { parse, stringify } from 'yaml';
import { checkContract } from '../scripts/check_publish_contract.mjs';

const text = readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8');
function mutated(action, input) {
  const workflow = parse(text);
  const step = workflow.jobs.publish.steps.find(s => s.uses?.includes(`gdam-actions/${action}@`));
  step.with[input] = 'invalid';
  return stringify(workflow);
}

test('workflow rejects unsupported publish.version and typo; restored install.version passes', () => {
  checkContract(text);
  assert.throws(() => checkContract(mutated('publish', 'version')), /publish: undeclared input version/);
  assert.throws(() => checkContract(mutated('publish', 'assset')), /publish: undeclared input assset/);
  assert.throws(() => checkContract(mutated('install', 'verison')), /install: undeclared input verison/);
  checkContract(text);
});

for (const shape of ['exact', 'legacy', 'unknown']) {
  test(`immutable publish script: ${shape} CLI (no network or production credentials)`, () => {
    const dir = mkdtempSync(join(tmpdir(), 'gdam-contract-'));
    try {
      writeFileSync(join(dir, 'gdam'), `#!/bin/bash
set -euo pipefail
if [ "$#" = 1 ]; then
  test -z "\${GDAM_SECRET_KEY+x}" || exit 90
  case "$STUB_SHAPE" in
    exact) echo 'usage: gdam publish @username/addon TAG [ASSET_NAME]' ;;
    legacy) echo 'usage: gdam publish @username/addon VERSION RELEASE_TAG [ASSET_NAME]' ;;
    *) echo 'unknown usage' ;;
  esac
  exit 2
fi
printf '%s\\n' "$@" > "$STUB_ARGS"
test "$GDAM_SECRET_KEY" = disposable-not-a-credential
`, { mode: 0o755 });
      const result = spawnSync('bash', [new URL('./fixtures/gdam-actions/publish/publish.sh', import.meta.url).pathname], {
        timeout: 5000, encoding: 'utf8',
        env: { PATH: `${dir}:/usr/bin:/bin`, STUB_SHAPE: shape, STUB_ARGS: join(dir, 'args'),
          GDAM_SECRET_KEY: 'disposable-not-a-credential', GITHUB_REPOSITORY: 'aviorstudio/gd-supabase',
          GDAM_PUBLISH_TAG: 'v0.0.3', GDAM_PUBLISH_ASSET: '@aviorstudio_gd-supabase.zip' },
      });
      assert.ifError(result.error);
      assert.ok(!`${result.stdout}${result.stderr}`.includes('disposable-not-a-credential'));
      if (shape === 'exact') {
        assert.equal(result.status, 0, result.stderr);
        assert.equal(readFileSync(join(dir, 'args'), 'utf8'), 'publish\n@aviorstudio/gd-supabase\nv0.0.3\n@aviorstudio_gd-supabase.zip\n');
      } else {
        assert.equal(result.status, 1);
        assert.match(result.stderr, /publish contract|unsupported publish command contract/);
        assert.throws(() => readFileSync(join(dir, 'args')), /ENOENT/);
      }
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });
}
