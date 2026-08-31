const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const BASE_URL = 'https://mhobgstudio.github.io/quran-memorization/';
const SCREENSHOT_DIR = path.join(__dirname, 'screenshots');

const EDGE_VIEWPORTS = {
  'iphone-se': { width: 375, height: 667, label: 'iPhone SE (small phone)' },
  'iphone-14-pro-max': { width: 430, height: 932, label: 'iPhone 14 Pro Max (large phone)' },
  'ipad-mini': { width: 768, height: 1024, label: 'iPad Mini' },
  'ipad-pro': { width: 1024, height: 1366, label: 'iPad Pro (large tablet)' },
  'desktop-hd': { width: 1920, height: 1080, label: 'Desktop Full HD' },
  'desktop-4k': { width: 2560, height: 1440, label: 'Desktop 4K' },
  'ultra-narrow': { width: 320, height: 568, label: 'Ultra-narrow (old iPhone)' },
  'landscape-tablet': { width: 1180, height: 820, label: 'Landscape Tablet' },
};

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

function log(msg) { console.log(`[${new Date().toLocaleTimeString()}] ${msg}`); }
function fail(vp, test, detail) { return { viewport: vp, test, detail, passed: false }; }
function pass(vp, test) { return { viewport: vp, test, detail: '', passed: true }; }

const results = [];
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function runTests() {
  const browser = await chromium.launch({ headless: true });

  for (const [vpKey, vp] of Object.entries(EDGE_VIEWPORTS)) {
    log(`\n${'─'.repeat(50)}`);
    log(`Edge case: ${vp.label} (${vp.width}x${vp.height})`);
    log('─'.repeat(50));

    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      deviceScaleFactor: 2,
    });
    const page = await context.newPage();

    const errors = [];
    page.on('pageerror', err => errors.push(err.message));
    page.on('console', msg => {
      if (msg.type() === 'error' && !msg.text().includes('favicon')) {
        errors.push(msg.text());
      }
    });

    try {
      await page.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 60000 });
      await sleep(4000);

      // Test: No horizontal overflow
      const overflow = await page.evaluate(() =>
        document.documentElement.scrollWidth > document.documentElement.clientWidth
      );
      if (overflow) {
        results.push(fail(vpKey, 'No horizontal overflow', 'Horizontal scrollbar'));
        log('  ❌ Horizontal overflow');
      } else {
        results.push(pass(vpKey, 'No horizontal overflow'));
        log('  ✅ No horizontal overflow');
      }

      // Test: No vertical overflow on initial load
      const docHeight = await page.evaluate(() => document.documentElement.scrollHeight);
      if (docHeight > vp.height + 200) {
        results.push(fail(vpKey, 'No excessive vertical overflow', `Height: ${docHeight}px`));
        log(`  ⚠️  Excessive height: ${docHeight}px`);
      } else {
        results.push(pass(vpKey, 'No excessive vertical overflow'));
        log(`  ✅ Height: ${docHeight}px (within ${vp.height}px viewport)`);
      }

      // Test: Canvas exists
      const hasCanvas = await page.evaluate(() =>
        !!document.querySelector('canvas') || !!document.querySelector('flt-glass-pane')
      );
      results.push(hasCanvas ? pass(vpKey, 'Canvas renders') : fail(vpKey, 'Canvas renders', 'No canvas'));
      log(`  ${hasCanvas ? '✅' : '❌'} Canvas: ${hasCanvas}`);

      // Test: No console errors
      if (errors.length > 0) {
        results.push(fail(vpKey, 'No errors', errors.join('; ')));
        log(`  ❌ ${errors.length} errors`);
      } else {
        results.push(pass(vpKey, 'No errors'));
        log('  ✅ No JS errors');
      }

      // Test: Scroll and interact
      await page.mouse.wheel(0, 200);
      await sleep(500);
      await page.mouse.wheel(0, -200);
      await sleep(500);

      // Test: Tap various positions
      const tapPoints = [
        [vp.width * 0.1, vp.height * 0.05],  // Top-left (hamburger menu)
        [vp.width * 0.9, vp.height * 0.05],  // Top-right (actions)
        [vp.width * 0.5, vp.height * 0.3],   // Center area
        [vp.width * 0.5, vp.height * 0.7],   // Lower area
      ];
      for (const [x, y] of tapPoints) {
        await page.mouse.click(x, y);
        await sleep(300);
      }

      // Final check: No errors after interaction
      if (errors.length > 0) {
        results.push(fail(vpKey, 'No post-interaction errors', errors.join('; ')));
        log(`  ❌ Post-interaction errors: ${errors.length}`);
      } else {
        results.push(pass(vpKey, 'No post-interaction errors'));
        log('  ✅ No post-interaction errors');
      }

      // Screenshot
      await page.screenshot({
        path: path.join(SCREENSHOT_DIR, `edge-${vpKey}.png`),
        fullPage: true,
      });

    } catch (err) {
      results.push(fail(vpKey, 'Unexpected error', err.message));
      log(`  ❌ Error: ${err.message}`);
    }

    await context.close();
  }

  await browser.close();

  // Print results
  console.log('\n' + '═'.repeat(70));
  console.log('EDGE CASE TEST RESULTS');
  console.log('═'.repeat(70));

  const passed = results.filter(r => r.passed);
  const failed = results.filter(r => !r.passed);

  console.log(`\n✅ Passed: ${passed.length}`);
  console.log(`❌ Failed: ${failed.length}`);
  console.log(`📊 Total:  ${results.length}`);

  if (failed.length > 0) {
    console.log('\nFAILURES:');
    for (const f of failed) {
      console.log(`  ❌ [${f.viewport}] ${f.test}: ${f.detail}`);
    }
  }

  console.log('\nBY VIEWPORT:');
  for (const vpKey of Object.keys(EDGE_VIEWPORTS)) {
    const vpR = results.filter(r => r.viewport === vpKey);
    const vpP = vpR.filter(r => r.passed).length;
    const vpF = vpR.filter(r => !r.passed).length;
    console.log(`  ${EDGE_VIEWPORTS[vpKey].label}: ${vpP} passed, ${vpF} failed`);
  }

  if (failed.length > 0) process.exit(1);
}

runTests().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
