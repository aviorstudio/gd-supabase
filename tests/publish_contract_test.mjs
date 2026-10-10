import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { parse, stringify } from 'yaml';
import { checkContract } from '../scripts/check_publish_contract.mjs';

const text = readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8');
test('release preparation refuses an existing computed tag; absent tag succeeds', () => {
  const dir = mkdtempSync(join(tmpdir(), 'supabase-release-tag-'));
  try {
    mkdirSync(join(dir, 'addon'));
    writeFileSync(join(dir, 'addon/plugin.cfg'), 'version="0.0.3"\n');
    writeFileSync(join(dir, 'git'), `#!/bin/bash
set -euo pipefail
case "$1" in
  fetch) exit 0 ;;
  tag) echo v0.0.2 ;;
  rev-parse) test "$TAG_EXISTS" = true ;;
  *) exit 90 ;;
esac
`, { mode: 0o755 });
    const script = parse(text).jobs.prepare.steps.find(s => s.id === 'release').run;
    for (const exists of [true, false]) {
      const output = join(dir, `output-${exists}`);
      const result = spawnSync('bash', ['-c', script], {
        cwd: dir, encoding: 'utf8', timeout: 5000,
        env: { PATH: `${dir}:/usr/bin:/bin`, TAG_EXISTS: String(exists),
          GITHUB_REF: 'refs/heads/main', BUMP: 'patch', GITHUB_OUTPUT: output },
      });
      assert.ifError(result.error);
      if (exists) {
        assert.equal(result.status, 1);
        assert.match(result.stderr, /Release tag already exists: v0.0.3/);
        assert.throws(() => readFileSync(output), /ENOENT/);
      } else {
        assert.equal(result.status, 0, result.stderr);
        assert.equal(readFileSync(output, 'utf8'), 'version=0.0.3\ntag=v0.0.3\n');
      }
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
function mutated(action, input) {
  const workflow = parse(text);
  const step = workflow.jobs.publish.steps.find(s => s.uses?.includes(`gdam-actions/${action}@`));
  step.with[input] = 'invalid';
  return stringify(workflow);
}

test('workflow rejects unsupported publish.version and typo; restored publish contract passes', () => {
  checkContract(text);
  assert.throws(() => checkContract(mutated('publish', 'version')), /publish: undeclared input version/);
  assert.throws(() => checkContract(mutated('publish', 'assset')), /publish: undeclared input assset/);
  assert.throws(() => checkContract(mutated('publish', 'secret-key')), /publish: undeclared input secret-key/);
  checkContract(text);
});

for (const key of ['gdam_sk_retired', 'ak_bad-header\n']) {
  test('immutable publish script rejects malformed and legacy keys before GitHub', () => {
    const dir = mkdtempSync(join(tmpdir(), 'gdam-contract-'));
    try {
      writeFileSync(join(dir, 'gh'), '#!/bin/sh\necho unexpectedly-called >&2\nexit 90\n', { mode: 0o755 });
      const result = spawnSync('python3', [new URL('./fixtures/gdam-actions/6677226d9353df1d410f3e7f5075e13b3b7d5308/publish/publish.py', import.meta.url).pathname], {
        timeout: 5000, encoding: 'utf8',
        env: { PATH: `${dir}:/usr/bin:/bin`, GH_TOKEN: 'disposable-github', GDAM_API_KEY: key,
          GITHUB_REPOSITORY: 'aviorstudio/gd-supabase', GDAM_PUBLISH_TAG: 'v0.0.3' },
      });
      assert.ifError(result.error);
      assert.equal(result.status, 1);
      assert.match(result.stderr, /api-key must be a Clerk publishing key/);
      assert.ok(!`${result.stdout}${result.stderr}`.includes(key));
      assert.ok(!result.stderr.includes('unexpectedly-called'));
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });
}
