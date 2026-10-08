import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { parse } from 'yaml';

export const actionRef = '699727af05ff8da8f6816cc5c14a16b2b9470219';
const fixtures = new URL('../tests/fixtures/gdam-actions/699727af05ff8da8f6816cc5c14a16b2b9470219/', import.meta.url);
const hashes = {
  'install/action.yml': '29a9f5cbfbc572e0827a4d1347a06c369a9686c47c36f752ed70830e1913250c',
  'publish/action.yml': '7e7cc2cb3412950c3c5a8f9cfb5f146922a6040da58229ed86f45605700066a5',
  'publish/publish.sh': 'c51ed57c134491f2945eaafc321faa65a72b6267a73a2a56e18cca72c175a486',
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
      const match = /^aviorstudio\/gdam-actions\/(install|publish)@(.+)$/.exec(step.uses);
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
      if (action === 'install') assert.equal(step.with?.version, 'v0.0.8', 'pin tested CLI version');
      if (action === 'publish') {
        assert.equal(step.with.tag, '${{ needs.prepare.outputs.tag }}', 'publish exact release tag');
        assert.equal(step.with.asset, '@aviorstudio_gd-supabase.zip', 'select exact tested ZIP among release assets');
      }
      found.add(action);
    }
  }
  assert.deepEqual([...found].sort(), ['install', 'publish'], 'both action contracts must be reachable');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  checkContract(readFileSync(process.argv[2] ?? new URL('../.github/workflows/release.yml', import.meta.url), 'utf8'));
  console.log('PUBLISH_WORKFLOW_CONTRACT_OK');
}
