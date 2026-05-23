#!/usr/bin/env node
/**
 * i18n-merge — Tauri 嵌套 locale → Flutter ARB 全量合并
 *
 * v0.67.0 Part A 一次性补齐脚本。读取 Tauri `src/i18n/locales/{en-US,zh-CN}.ts`
 * 的嵌套字典，扁平化为 `nestedDot → camelCaseArb` 风格 key，并写入
 * `app/lib/l10n/app_{en,zh}.arb`，保留原有 ARB key + 元数据。
 *
 * 不引入 ts/tsx 依赖：locale 文件是纯数据 `export default {...}`，可用
 * `new Function('return (...)')` 计算。
 *
 * 用法：node scripts/i18n-merge.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const SOURCES = {
  en: { tauri: 'src/i18n/locales/en-US.ts', arb: 'app/lib/l10n/app_en.arb' },
  zh: { tauri: 'src/i18n/locales/zh-CN.ts', arb: 'app/lib/l10n/app_zh.arb' },
};

function loadTauri(file) {
  const src = readFileSync(file, 'utf-8');
  const objLit = src.replace(/^export\s+default\s+/m, '').replace(/;?\s*$/, '');
  return new Function(`return (${objLit});`)();
}

function flatten(obj, prefix, out) {
  if (typeof obj === 'string') {
    out.set(prefix, obj);
    return;
  }
  if (typeof obj === 'number' || typeof obj === 'boolean') {
    out.set(prefix, String(obj));
    return;
  }
  if (obj && typeof obj === 'object' && !Array.isArray(obj)) {
    for (const [k, v] of Object.entries(obj)) {
      flatten(v, prefix ? `${prefix}.${k}` : k, out);
    }
  }
}

function toArbKey(dotted) {
  return dotted
    .split('.')
    .map((seg, i) =>
      i === 0 ? seg : seg.charAt(0).toUpperCase() + seg.slice(1).replace(/_/g, '')
    )
    .join('')
    .replace(/[^A-Za-z0-9_]/g, '');
}

/**
 * Tauri uses `{count}` style placeholders (vue-i18n). ARB shares the same
 * `{name}` syntax, so the values copy across verbatim. But we still need
 * to emit @-metadata for keys with placeholders so the Flutter generator
 * produces typed Dart parameters. We detect any `{xxx}` substring.
 */
function detectPlaceholders(value) {
  const names = new Set();
  for (const m of value.matchAll(/\{([A-Za-z0-9_]+)\}/g)) {
    names.add(m[1]);
  }
  return [...names];
}

for (const [lang, { tauri, arb }] of Object.entries(SOURCES)) {
  const tauriFile = resolve(REPO, tauri);
  const arbFile = resolve(REPO, arb);

  // 1. Load existing ARB to preserve orphan keys + metadata.
  const existing = JSON.parse(readFileSync(arbFile, 'utf-8'));

  // 2. Flatten Tauri tree → flat ARB keys.
  const tauriObj = loadTauri(tauriFile);
  const flat = new Map();
  flatten(tauriObj, '', flat);

  // 3. Merge — never overwrite an existing translation; only add new ones.
  let added = 0;
  let skippedDuplicates = 0;
  for (const [dotted, value] of flat) {
    const key = toArbKey(dotted);
    if (key in existing) {
      skippedDuplicates += 1;
      continue;
    }
    existing[key] = value;
    const phs = detectPlaceholders(value);
    if (phs.length > 0) {
      existing[`@${key}`] = {
        description: `Auto-imported from Tauri ${dotted}`,
        placeholders: Object.fromEntries(
          phs.map((p) => [p, { type: 'String' }])
        ),
      };
    }
    added += 1;
  }

  // 4. Refresh `@@last_modified`.
  existing['@@last_modified'] = new Date().toISOString().slice(0, 10);

  // 5. Write back with stable key ordering — @@meta first, then non-@ keys
  // in insertion order, then @-prefixed metadata interleaved next to their
  // owning key for readability.
  const out = {};
  for (const k of Object.keys(existing).filter((k) => k.startsWith('@@'))) {
    out[k] = existing[k];
  }
  const written = new Set(Object.keys(out));
  for (const k of Object.keys(existing).filter(
    (k) => !k.startsWith('@@') && !k.startsWith('@')
  )) {
    out[k] = existing[k];
    written.add(k);
    const meta = `@${k}`;
    if (meta in existing) {
      out[meta] = existing[meta];
      written.add(meta);
    }
  }
  // Any leftover orphan @-keys (metadata whose owning key was renamed).
  for (const k of Object.keys(existing)) {
    if (!written.has(k)) out[k] = existing[k];
  }

  writeFileSync(arbFile, JSON.stringify(out, null, 2) + '\n', 'utf-8');
  console.log(
    `[${lang}] ${arbFile}: +${added} keys (skipped ${skippedDuplicates} duplicates), total ${Object.keys(out).filter((k) => !k.startsWith('@')).length}`
  );
}
