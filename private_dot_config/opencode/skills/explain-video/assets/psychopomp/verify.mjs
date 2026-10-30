// Verify the delivered film and player: 1080p60 h264 + AAC, exact reel duration,
// full decode, and the browser player (chapter seeks, transcript, no autoplay,
// no console errors, no horizontal overflow at desktop/tablet/phone widths).
//
// Playwright resolution order: $PLAYWRIGHT_MODULE, a global `playwright`, then a
// shared install at ~/.tmp/opencode/explain-video-tools (created on first use).
// Chrome: $CHROME_PATH, Playwright's own Chromium, or the installed Google Chrome.
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { access, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const output = dirname(root);
const slug = output.split('/').at(-1);
const tools = join(process.env.HOME, '.tmp/opencode/explain-video-tools');

async function loadPlaywright() {
  if (process.env.PLAYWRIGHT_MODULE) return import(process.env.PLAYWRIGHT_MODULE);
  try { return await import('playwright'); } catch {}
  const shared = join(tools, 'node_modules/playwright/index.mjs');
  try { await access(shared); } catch {
    console.log(`Installing playwright into ${tools}`);
    execFileSync('npm', ['install', '--prefix', tools, '--no-audit', '--no-fund', 'playwright'], { stdio: 'inherit' });
  }
  return import(pathToFileURL(shared).href);
}
const { chromium } = await loadPlaywright();
let executablePath = process.env.CHROME_PATH;
if (!executablePath) {
  try { await access(chromium.executablePath()); }
  catch { executablePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'; }
}

const reel = JSON.parse(await readFile(join(root, 'film.reel.json')));
const duration = reel.segments.reduce((end, segment) => end - segment.transitionNanos + segment.plan.durationNanos, 0) / 1e9;
const media = join(output, `${slug}-psychopomp.mp4`);
const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', media], { encoding: 'utf8' }));
const video = probe.streams.find(stream => stream.codec_type === 'video');
const audio = probe.streams.find(stream => stream.codec_type === 'audio');
assert.equal(video.codec_name, 'h264');
assert.equal(video.width, 1920);
assert.equal(video.height, 1080);
assert.equal(video.avg_frame_rate, '60/1');
assert.equal(audio.codec_name, 'aac');
assert.ok(Math.abs(Number(probe.format.duration) - duration) < 1 / 60, `MP4 is ${probe.format.duration}s, reel is ${duration}s`);
execFileSync('ffmpeg', ['-v', 'error', '-i', media, '-f', 'null', '-'], { stdio: 'pipe' });
const loudness = spawnSync('ffmpeg', ['-hide_banner', '-nostats', '-i', media, '-af', 'loudnorm=print_format=json', '-f', 'null', '-'], { encoding: 'utf8' }).stderr.match(/\{[\s\S]*?\}/)?.[0];
const lufs = loudness ? Number(JSON.parse(loudness).input_i) : NaN;
assert.ok(lufs > -20 && lufs < -12, `Integrated loudness ${lufs} LUFS is outside -20..-12`);

const chapters = reel.segments.length;
const browser = await chromium.launch({ headless: true, executablePath });
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1080 } });
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto(pathToFileURL(join(output, 'index.html')).href);
  await page.waitForFunction(() => document.querySelector('video').readyState >= 1);
  assert.equal(await page.locator('#chapters button').count(), chapters);
  assert.equal(await page.locator('#transcript h2').count(), chapters);
  assert.ok(await page.evaluate(() => document.querySelector('video').paused), 'No autoplay');
  for (let i = 0; i < chapters; i++) {
    await page.locator('#chapters button').nth(i).click();
    await page.waitForFunction(index => document.querySelectorAll('#chapters button')[index].getAttribute('aria-current') === 'step', i);
    const times = await page.evaluate(() => ({ actual: document.querySelector('video').currentTime, chapters: globalThis.PSYCHOPOMP_CHAPTERS }));
    assert.ok(Math.abs(times.actual - (times.chapters[i].start + 0.7)) < 0.05, `Chapter ${i + 1} seek`);
  }
  const middle = duration / 2;
  await page.evaluate(async t => { const v = document.querySelector('video'); v.currentTime = t; v.muted = true; await v.play(); }, middle);
  await page.waitForFunction(t => document.querySelector('video').currentTime > t + 0.5, middle);
  await page.evaluate(() => document.querySelector('video').pause());
  await page.locator('summary').click();
  assert.ok(await page.locator('#transcript').isVisible());
  for (const width of [1440, 768, 390]) {
    await page.setViewportSize({ width, height: 900 });
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `No overflow at ${width}px`);
  }
  assert.deepEqual(errors, []);
  assert.equal(await page.evaluate(() => document.querySelector('video').error), null);
  console.log(`Passed: ${chapters} chapter seeks, transcript, paused load, desktop/tablet/mobile layout, native MP4 playback, 1080p60/AAC, exact duration (${duration.toFixed(2)}s), full decode, ${lufs.toFixed(1)} LUFS.`);
} finally {
  await browser.close();
}
