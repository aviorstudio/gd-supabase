import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { parse } from 'yaml';

export const actionRef = '6677226d9353df1d410f3e7f5075e13b3b7d5308';
const fixtures = new URL('../tests/fixtures/gdam-actions/6677226d9353df1d410f3e7f5075e13b3b7d5308/', import.meta.url);
const hashes = {
  'publish/action.yml': '9b9de814668665eb77e34afab9929e9585b1f0047f9c31a8b05706447d27bd10',
  'publish/publish.py': '038d6dff405bfd797ef44e661c41c6546725dadd15bc146b2388da49efc44540',
};

export function checkContract(text) {
  for (const [file, digest] of Object.entries(hashes)) {
    assert.equal(createHash('sha256').update(readFileSync(new URL(file, fixtures))).digest('hex'), digest, `immutable fixture ${file}`);
  }
  const workflow = parse(text, { uniqueKeys: true });
  const found = new Set();
  for (const job of Object.values(workflow.jobs)) {
    for (const step of job.steps ?? []) {
      if (!step.uses?.startsWith('aviorstudio/gdam-actions/')) continue;
      const match = /^aviorstudio\/gdam-actions\/(publish)@(.+)$/.exec(step.uses);
      assert.ok(match, `unknown GDAM action: ${step.uses}`);
      const [, action, ref] = match;
      assert.equal(ref, actionRef, 'action contract must match immutable metadata');
      const metadata = parse(readFileSync(new URL(`${action}/action.yml`, fixtures), 'utf8'));
      for (const input of Object.keys(step.with ?? {})) {
        assert.ok(Object.hasOwn(metadata.inputs, input), `${action}: undeclared input ${input}`);
      }
      for (const [input, contract] of Object.entries(metadata.inputs)) {
        if (contract.required) assert.ok(step.with?.[input], `${action}: missing ${input}`);
      }
      if (action === 'publish') {
        assert.equal(step.with['api-key'], '${{ secrets.GDAM_API_KEY }}', 'use the rotated Clerk credential');
        assert.equal(step.with.tag, '${{ needs.prepare.outputs.tag }}', 'publish exact release tag');
        assert.equal(step.with.asset, '@aviorstudio_gd-supabase.zip', 'select exact tested ZIP among release assets');
      }
      found.add(action);
    }
  }
  assert.deepEqual([...found].sort(), ['publish'], 'the verified publish contract must be reachable');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  checkContract(readFileSync(process.argv[2] ?? new URL('../.github/workflows/release.yml', import.meta.url), 'utf8'));
  console.log('PUBLISH_WORKFLOW_CONTRACT_OK');
}
