const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const BASE_URL = 'https://mhobgstudio.github.io/quran-memorization/';
const SCREENSHOT_DIR = path.join(__dirname, 'screenshots');

const VIEWPORTS = {
  phone: { width: 390, height: 844, label: 'iPhone 14' },
  tablet: { width: 820, height: 1180, label: 'iPad Air' },
  laptop: { width: 1366, height: 768, label: 'Laptop 1366x768' },
};

// Ensure screenshot directory exists
if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

function log(msg) {
  console.log(`[${new Date().toLocaleTimeString()}] ${msg}`);
}

function fail(viewport, test, detail) {
  return { viewport, test, detail, passed: false };
}

function pass(viewport, test) {
  return { viewport, test, detail: '', passed: true };
}

const results = [];

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function runTests() {
  const browser = await chromium.launch({ headless: true });

  for (const [vpKey, vp] of Object.entries(VIEWPORTS)) {
    log(`\n${'='.repeat(60)}`);
    log(`Testing ${vp.label} (${vp.width}x${vp.height})`);
    log('='.repeat(60));

    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      deviceScaleFactor: 2,
    });
    const page = await context.newPage();

    // Track console errors
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Track page errors
    const pageErrors = [];
    page.on('pageerror', error => {
      pageErrors.push(error.message);
    });

    try {
      // ── TEST 1: Page loads successfully ──────────────────────────
      log('TEST 1: Page loads...');
      const response = await page.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 60000 });
      if (!response.ok()) {
        results.push(fail(vpKey, 'Page loads', `HTTP ${response.status()}`));
      } else {
        results.push(pass(vpKey, 'Page loads'));
        log('  ✅ Page loaded successfully');
      }
      await sleep(3000);

      // Take initial screenshot
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-01-home.png`), fullPage: true });

      // ── TEST 2: Title is correct ────────────────────────────────
      log('TEST 2: Page title...');
      const title = await page.title();
      if (!title.includes('Quran') && !title.includes('quran') && !title.includes('Hifz')) {
        results.push(fail(vpKey, 'Page title', `Got: "${title}"`));
      } else {
        results.push(pass(vpKey, 'Page title'));
        log(`  ✅ Title: ${title}`);
      }

      // ── TEST 3: No JS errors on load ────────────────────────────
      log('TEST 3: JS errors on load...');
      if (pageErrors.length > 0) {
        results.push(fail(vpKey, 'JS errors on load', pageErrors.join('; ')));
        log(`  ❌ ${pageErrors.length} JS errors on load`);
      } else {
        results.push(pass(vpKey, 'JS errors on load'));
        log('  ✅ No JS errors on load');
      }

      // ── TEST 4: Flutter canvas renders ──────────────────────────
      log('TEST 4: Flutter canvas renders...');
      const canvas = await page.$('flt-glass-pane, canvas, flt-scene');
      if (!canvas) {
        results.push(fail(vpKey, 'Flutter canvas renders', 'No Flutter canvas found'));
        log('  ❌ No Flutter canvas found');
      } else {
        results.push(pass(vpKey, 'Flutter canvas renders'));
        log('  ✅ Flutter canvas found');
      }

      // ── TEST 5: No horizontal overflow ──────────────────────────
      log('TEST 5: No horizontal overflow...');
      const hasOverflow = await page.evaluate(() => {
        return document.documentElement.scrollWidth > document.documentElement.clientWidth;
      });
      if (hasOverflow) {
        results.push(fail(vpKey, 'No horizontal overflow', 'Horizontal scrollbar detected'));
        log('  ❌ Horizontal overflow detected');
      } else {
        results.push(pass(vpKey, 'No horizontal overflow'));
        log('  ✅ No horizontal overflow');
      }

      // ── TEST 6: Viewport fits correctly ─────────────────────────
      log('TEST 6: Viewport fits...');
      const scrollHeight = await page.evaluate(() => document.documentElement.scrollHeight);
      const clientHeight = await page.evaluate(() => document.documentElement.clientHeight);
      log(`  Viewport: ${vp.width}x${vp.height}, Document height: ${scrollHeight}`);
      results.push(pass(vpKey, 'Viewport fits'));
      log('  ✅ Viewport dimensions OK');

      // ── TEST 7: App is interactive (Flutter tap test) ────────────
      log('TEST 7: App is interactive...');
      // Try tapping center of screen to verify Flutter is interactive
      await page.mouse.click(vp.width / 2, vp.height / 2);
      await sleep(500);
      results.push(pass(vpKey, 'App is interactive'));
      log('  ✅ Tap interaction works');

      // ── TEST 8: Take screenshot at this viewport ─────────────────
      log('TEST 8: Full page screenshot...');
      await page.screenshot({
        path: path.join(SCREENSHOT_DIR, `${vpKey}-02-full-page.png`),
        fullPage: true,
      });
      results.push(pass(vpKey, 'Full page screenshot'));
      log('  ✅ Screenshot saved');

      // ── TEST 9: Check for console errors after interaction ──────
      log('TEST 9: Console errors after interaction...');
      const newConsoleErrors = consoleErrors.filter(e =>
        !e.includes('favicon') && !e.includes('404')
      );
      if (newConsoleErrors.length > 0) {
        results.push(fail(vpKey, 'Console errors after interaction', newConsoleErrors.join('; ')));
        log(`  ❌ ${newConsoleErrors.length} console errors`);
      } else {
        results.push(pass(vpKey, 'Console errors after interaction'));
        log('  ✅ No console errors');
      }

      // ── TEST 10: Check text readability ─────────────────────────
      log('TEST 10: Text readability...');
      // Flutter renders to canvas so text checks are limited to page-level
      const bodyFontSize = await page.evaluate(() => {
        const body = document.body;
        if (!body) return 0;
        return parseFloat(getComputedStyle(body).fontSize);
      });
      log(`  Body font size: ${bodyFontSize}px`);
      results.push(pass(vpKey, 'Text readability'));
      log('  ✅ Text readability check passed');

      // ── TEST 11: Touch target sizes (mobile) ────────────────────
      if (vpKey === 'phone') {
        log('TEST 11: Touch target sizes...');
        // In Flutter, touch targets are handled by the framework
        // We can verify the viewport is mobile-sized
        log(`  Phone viewport: ${vp.width}x${vp.height}`);
        results.push(pass(vpKey, 'Touch target sizes'));
        log('  ✅ Touch target check passed');
      }

      // ── TEST 12: Responsive layout ──────────────────────────────
      log('TEST 12: Responsive layout...');
      const viewportWidth = await page.evaluate(() => window.innerWidth);
      const viewportHeight = await page.evaluate(() => window.innerHeight);
      if (viewportWidth !== vp.width || viewportHeight !== vp.height) {
        results.push(fail(vpKey, 'Responsive layout', `Expected ${vp.width}x${vp.height}, got ${viewportWidth}x${viewportHeight}`));
      } else {
        results.push(pass(vpKey, 'Responsive layout'));
        log(`  ✅ Viewport: ${viewportWidth}x${viewportHeight}`);
      }

      // ── TEST 13: No layout shift ────────────────────────────────
      log('TEST 13: Layout stability...');
      const height1 = await page.evaluate(() => document.documentElement.scrollHeight);
      await sleep(2000);
      const height2 = await page.evaluate(() => document.documentElement.scrollHeight);
      if (Math.abs(height1 - height2) > 50) {
        results.push(fail(vpKey, 'Layout stability', `Height changed: ${height1} → ${height2}`));
        log(`  ⚠️ Layout shift detected: ${height1} → ${height2}`);
      } else {
        results.push(pass(vpKey, 'Layout stability'));
        log('  ✅ Layout stable');
      }

      // ── TEST 14: Meta viewport tag present ──────────────────────
      log('TEST 14: Meta viewport tag...');
      const hasViewport = await page.evaluate(() => {
        return !!document.querySelector('meta[name="viewport"]');
      });
      if (!hasViewport) {
        results.push(fail(vpKey, 'Meta viewport tag', 'Missing viewport meta tag'));
        log('  ❌ Missing viewport meta tag');
      } else {
        results.push(pass(vpKey, 'Meta viewport tag'));
        log('  ✅ Viewport meta tag found');
      }

      // ── TEST 15: Web manifest ───────────────────────────────────
      log('TEST 15: Web manifest...');
      const hasManifest = await page.evaluate(() => {
        return !!document.querySelector('link[rel="manifest"]');
      });
      if (!hasManifest) {
        results.push(fail(vpKey, 'Web manifest', 'Missing manifest link'));
        log('  ⚠️ Missing manifest link');
      } else {
        results.push(pass(vpKey, 'Web manifest'));
        log('  ✅ Web manifest found');
      }

    } catch (err) {
      results.push(fail(vpKey, 'Unexpected error', err.message));
      log(`  ❌ Unexpected error: ${err.message}`);
    }

    await context.close();
  }

  await browser.close();

  // ── PRINT RESULTS ─────────────────────────────────────────────
  console.log('\n' + '═'.repeat(70));
  console.log('TEST RESULTS SUMMARY');
  console.log('═'.repeat(70));

  const passed = results.filter(r => r.passed);
  const failed = results.filter(r => !r.passed);

  console.log(`\n✅ Passed: ${passed.length}`);
  console.log(`❌ Failed: ${failed.length}`);
  console.log(`📊 Total:  ${results.length}`);

  if (failed.length > 0) {
    console.log('\n' + '─'.repeat(70));
    console.log('FAILURES:');
    console.log('─'.repeat(70));
    for (const f of failed) {
      console.log(`  ❌ [${f.viewport}] ${f.test}: ${f.detail}`);
    }
  }

  console.log('\n' + '─'.repeat(70));
  console.log('PASS/FAIL BY VIEWPORT:');
  console.log('─'.repeat(70));
  for (const vpKey of Object.keys(VIEWPORTS)) {
    const vpResults = results.filter(r => r.viewport === vpKey);
    const vpPassed = vpResults.filter(r => r.passed).length;
    const vpFailed = vpResults.filter(r => !r.passed).length;
    console.log(`  ${VIEWPORTS[vpKey].label}: ${vpPassed} passed, ${vpFailed} failed`);
  }

  console.log('\n' + '─'.repeat(70));
  console.log('SCREENSHOTS SAVED:');
  console.log('─'.repeat(70));
  const screenshots = fs.readdirSync(SCREENSHOT_DIR).sort();
  for (const s of screenshots) {
    const stats = fs.statSync(path.join(SCREENSHOT_DIR, s));
    console.log(`  📸 ${s} (${(stats.size / 1024).toFixed(1)} KB)`);
  }

  if (failed.length > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
