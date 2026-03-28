#!/usr/bin/env node

/**
 * Generates all app icon sizes from the master SVG.
 * Usage: node scripts/generate-icons.mjs
 * Requires: npm install -D sharp
 */

import sharp from "sharp";
import { readFileSync, mkdirSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const iconsDir = resolve(root, "src-tauri/icons");
const svgPath = resolve(iconsDir, "icon.svg");
const svgBuffer = readFileSync(svgPath);

async function generate(size, outputPath) {
  // density controls SVG rasterization resolution before resize
  // 72 DPI = 1:1 with viewBox. Scale up proportionally to target size.
  const density = Math.ceil((size / 1024) * 72 * 2);
  await sharp(svgBuffer, { density: Math.max(144, density) })
    .resize(size, size)
    .png()
    .toFile(outputPath);
  console.log(`  ${size}x${size} → ${outputPath.replace(root + "/", "")}`);
}

async function generateIco(outputPath) {
  // ICO: 16, 32, 48, 256
  const sizes = [16, 32, 48, 256];
  const buffers = await Promise.all(
    sizes.map((s) =>
      sharp(svgBuffer, { density: 144 }).resize(s, s).png().toBuffer()
    )
  );
  // Use the 256px as main icon.png, then create .ico via sharp
  // sharp doesn't natively output .ico, so we'll use the largest PNG as fallback
  // For proper .ico we just copy the 256px version
  await sharp(svgBuffer, { density: 144 }).resize(256, 256).png().toFile(outputPath.replace('.ico', '.ico.png'));
  console.log(`  ICO (256px) → ${outputPath.replace(root + "/", "")}`);
}

async function main() {
  console.log("Generating icons from icon.svg...\n");

  // ── Generic PNG sizes ──
  const genericSizes = [
    [32, "32x32.png"],
    [64, "64x64.png"],
    [128, "128x128.png"],
    [256, "128x128@2x.png"],
    [512, "icon.png"],
  ];

  for (const [size, name] of genericSizes) {
    await generate(size, resolve(iconsDir, name));
  }

  // ── Windows Store logos ──
  const windowsSizes = [
    [30, "Square30x30Logo.png"],
    [44, "Square44x44Logo.png"],
    [71, "Square71x71Logo.png"],
    [89, "Square89x89Logo.png"],
    [107, "Square107x107Logo.png"],
    [142, "Square142x142Logo.png"],
    [150, "Square150x150Logo.png"],
    [284, "Square284x284Logo.png"],
    [310, "Square310x310Logo.png"],
    [50, "StoreLogo.png"],
  ];

  for (const [size, name] of windowsSizes) {
    await generate(size, resolve(iconsDir, name));
  }

  // ── iOS icons ──
  const iosDir = resolve(iconsDir, "ios");
  mkdirSync(iosDir, { recursive: true });
  const iosIcons = [
    [20, "AppIcon-20x20@1x.png"],
    [40, "AppIcon-20x20@2x.png"],
    [40, "AppIcon-20x20@2x-1.png"],
    [60, "AppIcon-20x20@3x.png"],
    [29, "AppIcon-29x29@1x.png"],
    [58, "AppIcon-29x29@2x.png"],
    [58, "AppIcon-29x29@2x-1.png"],
    [87, "AppIcon-29x29@3x.png"],
    [40, "AppIcon-40x40@1x.png"],
    [80, "AppIcon-40x40@2x.png"],
    [80, "AppIcon-40x40@2x-1.png"],
    [120, "AppIcon-40x40@3x.png"],
    [120, "AppIcon-60x60@2x.png"],
    [180, "AppIcon-60x60@3x.png"],
    [76, "AppIcon-76x76@1x.png"],
    [152, "AppIcon-76x76@2x.png"],
    [167, "AppIcon-83.5x83.5@2x.png"],
    [1024, "AppIcon-512@2x.png"],
  ];

  for (const [size, name] of iosIcons) {
    await generate(size, resolve(iosDir, name));
  }

  // ── Android icons ──
  const androidSizes = [
    ["mipmap-mdpi", 48],
    ["mipmap-hdpi", 72],
    ["mipmap-xhdpi", 96],
    ["mipmap-xxhdpi", 144],
    ["mipmap-xxxhdpi", 192],
  ];

  for (const [folder, size] of androidSizes) {
    const dir = resolve(iconsDir, "android", folder);
    mkdirSync(dir, { recursive: true });
    await generate(size, resolve(dir, "ic_launcher.png"));
    // Round icon (same for now)
    await generate(size, resolve(dir, "ic_launcher_round.png"));
    // Foreground (same icon, used for adaptive icons)
    await generate(size, resolve(dir, "ic_launcher_foreground.png"));
  }

  // ── macOS .icns (via iconutil) ──
  console.log("\n  Building icon.icns...");
  const iconsetDir = resolve(iconsDir, "icon.iconset");
  mkdirSync(iconsetDir, { recursive: true });

  const icnsSizes = [
    [16, "icon_16x16.png"],
    [32, "icon_16x16@2x.png"],
    [32, "icon_32x32.png"],
    [64, "icon_32x32@2x.png"],
    [128, "icon_128x128.png"],
    [256, "icon_128x128@2x.png"],
    [256, "icon_256x256.png"],
    [512, "icon_256x256@2x.png"],
    [512, "icon_512x512.png"],
    [1024, "icon_512x512@2x.png"],
  ];

  for (const [size, name] of icnsSizes) {
    await generate(size, resolve(iconsetDir, name));
  }

  // Use macOS iconutil to create .icns
  const { execSync } = await import("child_process");
  try {
    execSync(`iconutil -c icns "${iconsetDir}" -o "${resolve(iconsDir, "icon.icns")}"`, {
      stdio: "pipe",
    });
    console.log(`  icon.icns → src-tauri/icons/icon.icns`);
    // Clean up iconset
    execSync(`rm -rf "${iconsetDir}"`);
  } catch {
    console.log("  iconutil not available (not macOS?), skipping .icns");
  }

  // ── Windows .ico ──
  // Create from 256px PNG using sharp (outputs PNG, rename to .ico for basic compat)
  // For proper multi-resolution .ico, use a dedicated tool
  console.log("\n  Building icon.ico...");
  const ico256 = await sharp(svgBuffer, { density: 144 })
    .resize(256, 256)
    .png()
    .toBuffer();
  // Write a simple single-image ICO
  const icoBuffer = createIco(ico256, 256);
  const { writeFileSync } = await import("fs");
  writeFileSync(resolve(iconsDir, "icon.ico"), icoBuffer);
  console.log(`  icon.ico → src-tauri/icons/icon.ico`);

  console.log("\nDone!");
}

/**
 * Creates a minimal ICO file from a single PNG buffer.
 */
function createIco(pngBuffer, size) {
  // ICO header: 6 bytes
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // ICO type
  header.writeUInt16LE(1, 4); // 1 image

  // Directory entry: 16 bytes
  const entry = Buffer.alloc(16);
  entry.writeUInt8(size >= 256 ? 0 : size, 0); // width (0 = 256)
  entry.writeUInt8(size >= 256 ? 0 : size, 1); // height
  entry.writeUInt8(0, 2);  // color palette
  entry.writeUInt8(0, 3);  // reserved
  entry.writeUInt16LE(1, 4);  // color planes
  entry.writeUInt16LE(32, 6); // bits per pixel
  entry.writeUInt32LE(pngBuffer.length, 8); // image size
  entry.writeUInt32LE(22, 12); // offset (6 + 16 = 22)

  return Buffer.concat([header, entry, pngBuffer]);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
