import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

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
