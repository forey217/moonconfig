import { spawnSync } from 'node:child_process';
import { copyFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const build = spawnSync('moon', ['build', '--target', 'js', '--release', '--deny-warn'], {cwd: root, stdio: 'inherit'});
if (build.error) { console.error('Install the official MoonBit toolchain and add moon to PATH.'); process.exit(1); }
if (build.status !== 0) process.exit(build.status ?? 1);
await mkdir(new URL('../demo/', import.meta.url), {recursive: true});
await copyFile(new URL('../_build/js/release/build/cmd/engine/engine.js', import.meta.url), new URL('../demo/engine.js', import.meta.url));
console.log('Built MoonBit engine for the CLI and browser demo.');
