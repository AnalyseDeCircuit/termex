#!/usr/bin/env node
/**
 * i18n-diff — Tauri 嵌套 i18n → Flutter ARB 扁平差异检测
 *
 * v0.67.0 Part A 前置脚本。
 *
 * 用法：
 *   pnpm dlx tsx scripts/i18n-diff.ts            # 默认 zh + en 双语
 *   pnpm dlx tsx scripts/i18n-diff.ts --lang=zh  # 仅 zh
 *   pnpm dlx tsx scripts/i18n-diff.ts --emit     # 输出缺失 keys 到 stdout 的 ARB 片段
 *   pnpm dlx tsx scripts/i18n-diff.ts --csv      # CSV 形式
 *
 * 退出码：0 = 完全覆盖，1 = 存在缺失，2 = 文件不存在
 *
 * 不引入新依赖：用 TS 源码原文本解析（locales 文件是纯数据 export default）。
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(__dirname, "..");

const TAURI = {
  zh: resolve(REPO, "src/i18n/locales/zh-CN.ts"),
  en: resolve(REPO, "src/i18n/locales/en-US.ts"),
};
const ARB = {
  zh: resolve(REPO, "app/lib/l10n/app_zh.arb"),
  en: resolve(REPO, "app/lib/l10n/app_en.arb"),
};

type Flat = Map<string, string>;

function loadTauriLocale(file: string): Flat {
  if (!existsSync(file)) {
    console.error(`[i18n-diff] missing ${file}`);
    process.exit(2);
  }
  const src = readFileSync(file, "utf-8");
  // Strip "export default" + trailing ";" to get a bare object literal.
  const objLit = src
    .replace(/^export\s+default\s+/m, "")
    .replace(/;?\s*$/, "");
  // Evaluate in an isolated scope. Locale files are pure data — no imports,
  // no function calls. eval is OK here because the input is repo-controlled.
  // eslint-disable-next-line @typescript-eslint/no-implied-eval
  const obj = new Function(`return (${objLit});`)();
  const flat: Flat = new Map();
  flatten(obj, "", flat);
  return flat;
}

function flatten(node: unknown, prefix: string, out: Flat) {
  if (typeof node === "string") {
    out.set(prefix, node);
    return;
  }
  if (typeof node === "number" || typeof node === "boolean") {
    out.set(prefix, String(node));
    return;
  }
  if (node && typeof node === "object" && !Array.isArray(node)) {
    for (const [k, v] of Object.entries(node)) {
      flatten(v, prefix ? `${prefix}.${k}` : k, out);
    }
  }
}

function loadArb(file: string): Flat {
  if (!existsSync(file)) {
    console.error(`[i18n-diff] missing ${file}`);
    process.exit(2);
  }
  const json = JSON.parse(readFileSync(file, "utf-8"));
  const flat: Flat = new Map();
  for (const [k, v] of Object.entries(json)) {
    if (k.startsWith("@") || typeof v !== "string") continue;
    flat.set(k, v);
  }
  return flat;
}

/**
 * Convert a dotted Tauri key like "sidebar.newConnection" into a flat
 * camelCase ARB key like "sidebarNewConnection". Matches the convention
 * already in app_en.arb (e.g. commonConfirm, commonCancel).
 */
function toArbKey(dotted: string): string {
  return dotted
    .split(".")
    .map((seg, i) =>
      i === 0
        ? seg
        : seg.charAt(0).toUpperCase() + seg.slice(1).replace(/_/g, "")
    )
    .join("")
    .replace(/[^A-Za-z0-9_]/g, "");
}

function diff(tauri: Flat, arb: Flat) {
  const arbKeys = new Set(arb.keys());
  const missing: Array<{ tauriKey: string; arbKey: string; sample: string }> =
    [];
  const orphan: string[] = [];
  for (const [k, v] of tauri.entries()) {
    const arbKey = toArbKey(k);
    if (!arbKeys.has(arbKey)) {
      missing.push({ tauriKey: k, arbKey, sample: v });
    }
  }
  // Flat ARB keys not derivable from any Tauri key are "orphans".
  const tauriArbKeys = new Set(
    Array.from(tauri.keys()).map((k) => toArbKey(k))
  );
  for (const k of arb.keys()) {
    if (!tauriArbKeys.has(k)) orphan.push(k);
  }
  return { missing, orphan };
}

function fmtCoverage(arb: Flat, tauri: Flat) {
  const total = tauri.size;
  const have = Array.from(tauri.keys()).filter((k) =>
    arb.has(toArbKey(k))
  ).length;
  const pct = total === 0 ? 0 : (have / total) * 100;
  return { have, total, pct };
}

const args = process.argv.slice(2);
const wantLang = args.find((a) => a.startsWith("--lang="))?.split("=")[1];
const emitMode = args.includes("--emit");
const csvMode = args.includes("--csv");

const langs = wantLang ? [wantLang] : ["zh", "en"];
let exitCode = 0;

for (const lang of langs) {
  const tauriFile = TAURI[lang as keyof typeof TAURI];
  const arbFile = ARB[lang as keyof typeof ARB];
  if (!tauriFile || !arbFile) {
    console.error(`[i18n-diff] unknown lang: ${lang}`);
    process.exit(2);
  }
  const tauri = loadTauriLocale(tauriFile);
  const arb = loadArb(arbFile);
  const { missing, orphan } = diff(tauri, arb);
  const cov = fmtCoverage(arb, tauri);

  if (csvMode) {
    console.log(`lang,tauriKey,arbKey,sample`);
    for (const m of missing) {
      const sample = m.sample.replace(/"/g, '""').replace(/\n/g, " ");
      console.log(`${lang},${m.tauriKey},${m.arbKey},"${sample}"`);
    }
    continue;
  }

  if (emitMode) {
    console.log(`// ===== ${lang.toUpperCase()} missing keys (${missing.length}) =====`);
    for (const m of missing) {
      const v = m.sample.replace(/"/g, '\\"').replace(/\n/g, "\\n");
      console.log(`  "${m.arbKey}": "${v}",`);
    }
    continue;
  }

  console.log(
    `\n[${lang}] coverage ${cov.have}/${cov.total} = ${cov.pct.toFixed(1)}% ` +
      `(missing ${missing.length}, orphan ${orphan.length})`
  );
  if (missing.length > 0) {
    exitCode = 1;
    console.log(`  first 5 missing:`);
    for (const m of missing.slice(0, 5)) {
      console.log(`    ${m.tauriKey} → ${m.arbKey}  ::  ${m.sample}`);
    }
  }
  if (orphan.length > 0) {
    console.log(`  orphan ARB keys (no Tauri origin): ${orphan.slice(0, 10).join(", ")}${orphan.length > 10 ? " …" : ""}`);
  }
}

process.exit(exitCode);
