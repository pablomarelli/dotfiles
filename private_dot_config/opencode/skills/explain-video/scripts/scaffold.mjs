#!/usr/bin/env node
// Create a new explainer film directory from the skill's templates.
//
//   node scaffold.mjs <target-dir> --title "CPA caps (XML-34)" --org APPTNESS [--subtitle "..."] [--force]
//
// <target-dir> is the film directory, usually <repo>/docs/explainers/<slug>. Its
// last path segment becomes the slug (lowercase letters, digits, dashes), the
// MP4 name, and the reel id. Existing files are never overwritten unless --force.
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const assets = path.join(here, '..', 'assets');
const args = process.argv.slice(2);
const target = args.find(arg => !arg.startsWith('--'));
const flag = name => { const i = args.indexOf(name); return i === -1 ? undefined : args[i + 1]; };
const force = args.includes('--force');
if (!target || !flag('--title') || !flag('--org')) {
  console.error('usage: node scaffold.mjs <target-dir> --title "Film title" --org ORG [--subtitle "One line under the player"] [--force]');
  process.exit(2);
}
const dir = path.resolve(target);
const slug = path.basename(dir);
if (!/^[a-z0-9][a-z0-9-]*$/.test(slug)) throw new Error(`Directory name '${slug}' must be a slug: lowercase letters, digits, dashes`);
const values = {
  SLUG: slug,
  TITLE: flag('--title'),
  ORG: flag('--org'),
  SUBTITLE: flag('--subtitle') ?? 'One sentence on what the film shows. Example values are illustrative.',
  CRATE: `${slug}-film`,
};
const fill = text => text.replace(/\{\{(SLUG|TITLE|ORG|SUBTITLE|CRATE)\}\}/g, (_, key) => values[key]);
const textual = /\.(mjs|md|html|json|rs|toml|gitignore)$/;

const written = [];
const skipped = [];
function copy(from, to) {
  if (statSync(from).isDirectory()) {
    mkdirSync(to, { recursive: true });
    for (const entry of readdirSync(from)) copy(path.join(from, entry), path.join(to, entry));
    return;
  }
  if (existsSync(to) && !force) { skipped.push(to); return; }
  if (textual.test(from) || path.basename(from) === '.gitignore') writeFileSync(to, fill(readFileSync(from, 'utf8')));
  else cpSync(from, to);
  written.push(to);
}
copy(assets, dir);

console.log(`Scaffolded ${slug} in ${dir}`);
for (const file of written) console.log(`  + ${path.relative(dir, file)}`);
for (const file of skipped) console.log(`  = ${path.relative(dir, file)} (kept, use --force to overwrite)`);
console.log(`
Next:
  1. Write the story in ${path.join(dir, 'psychopomp/narration/script.json')} (clips with id, title, text).
  2. Replace the starter chapters in ${path.join(dir, 'psychopomp/src/main.rs')}; one fn per clip id.
  3. node ${path.join(dir, 'psychopomp/render.mjs')} --frame 5     # narrate + compile + one still
  4. node ${path.join(dir, 'psychopomp/render.mjs')}               # full film + player data
  5. node ${path.join(dir, 'psychopomp/verify.mjs')}
  6. Fill ${path.join(dir, 'README.md')} (chapters, source checks, review evidence).`);
