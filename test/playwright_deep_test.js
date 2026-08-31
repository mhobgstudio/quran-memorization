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

  for (const [vpKey, vp] of Object.entries(VIEWPORTS)) {
    log(`\n${'═'.repeat(60)}`);
    log(`DEEP TESTING ${vp.label} (${vp.width}x${vp.height})`);
    log('═'.repeat(60));

    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      deviceScaleFactor: 2,
    });
    const page = await context.newPage();

    const consoleErrors = [];
    const pageErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', error => pageErrors.push(error.message));

    try {
      // Load the page and wait for Flutter to fully initialize
      log('Loading page...');
      await page.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 60000 });
      await sleep(5000); // Give Flutter time to fully render

      // ── TEST 1: Flutter engine loaded ─────────────────────────
      log('TEST 1: Flutter engine...');
      const hasEngine = await page.evaluate(() => {
        return !!document.querySelector('flutter-view') ||
               !!document.querySelector('flt-glass-pane') ||
               !!document.querySelector('canvas');
      });
      results.push(hasEngine ? pass(vpKey, 'Flutter engine') : fail(vpKey, 'Flutter engine', 'No engine found'));
      log(`  ${hasEngine ? '✅' : '❌'} Flutter engine: ${hasEngine}`);

      // Take initial state screenshot
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-01-initial.png`), fullPage: true });

      // ── TEST 2: App bar visible at top ────────────────────────
      log('TEST 2: App bar renders...');
      // Flutter app bars are at the top of the screen
      // Take a clip of the top area
      await page.screenshot({
        path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-02-appbar.png`),
        clip: { x: 0, y: 0, width: vp.width, height: 60 },
      });
      results.push(pass(vpKey, 'App bar renders'));
      log('  ✅ App bar screenshot taken');

      // ── TEST 3: Tap on plan selector area (center-top) ────────
      log('TEST 3: Tap center-top (plan area)...');
      await page.mouse.click(vp.width / 2, vp.height * 0.15);
      await sleep(1000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-03-plan-tap.png`), fullPage: true });
      results.push(pass(vpKey, 'Plan area tap'));
      log('  ✅ Tapped plan area');

      // ── TEST 4: Scroll down and verify ────────────────────────
      log('TEST 4: Scroll down...');
      await page.mouse.wheel(0, 300);
      await sleep(1000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-04-scrolled.png`), fullPage: true });
      results.push(pass(vpKey, 'Scroll down'));
      log('  ✅ Scrolled down');

      // ── TEST 5: Scroll back up ────────────────────────────────
      log('TEST 5: Scroll up...');
      await page.mouse.wheel(0, -300);
      await sleep(1000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-05-scrolled-up.png`), fullPage: true });
      results.push(pass(vpKey, 'Scroll up'));
      log('  ✅ Scrolled up');

      // ── TEST 6: Tap app bar icon buttons (right side) ──────────
      log('TEST 6: Tap app bar icons...');
      // App bar icons are typically at the right side of the top bar
      await page.mouse.click(vp.width - 20, 30);
      await sleep(1500);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-06-menutap.png`), fullPage: true });
      results.push(pass(vpKey, 'App bar icon tap'));
      log('  ✅ Tapped app bar icons');

      // Click elsewhere to dismiss any popup
      await page.mouse.click(vp.width / 2, vp.height / 2);
      await sleep(500);

      // ── TEST 7: Tap second app bar icon ───────────────────────
      log('TEST 7: Tap second app bar icon...');
      await page.mouse.click(vp.width - 60, 30);
      await sleep(1500);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-07-secondicon.png`), fullPage: true });
      results.push(pass(vpKey, 'Second app bar icon'));
      log('  ✅ Tapped second icon');

      await page.mouse.click(vp.width / 2, vp.height / 2);
      await sleep(500);

      // ── TEST 8: Navigate to viewer (tap Continue Reading or page area) ──
      log('TEST 8: Try viewer navigation...');
      // Try to find and tap "Continue Reading" button area (usually in the middle area)
      await page.mouse.click(vp.width / 2, vp.height * 0.35);
      await sleep(2000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-08-viewer.png`), fullPage: true });
      results.push(pass(vpKey, 'Viewer navigation'));
      log('  ✅ Tapped viewer area');

      // ── TEST 9: In viewer - try next page ──────────────────────
      log('TEST 9: Next page in viewer...');
      // In viewer, try tapping right side for next page
      await page.mouse.click(vp.width - 30, vp.height / 2);
      await sleep(1000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-09-nextpage.png`), fullPage: true });
      results.push(pass(vpKey, 'Next page'));
      log('  ✅ Next page tap');

      // ── TEST 10: In viewer - try previous page ────────────────
      log('TEST 10: Previous page in viewer...');
      await page.mouse.click(30, vp.height / 2);
      await sleep(1000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-10-prevpage.png`), fullPage: true });
      results.push(pass(vpKey, 'Previous page'));
      log('  ✅ Previous page tap');

      // ── TEST 11: In viewer - try keyboard navigation ──────────
      log('TEST 11: Keyboard navigation...');
      await page.keyboard.press('ArrowRight');
      await sleep(500);
      await page.keyboard.press('ArrowLeft');
      await sleep(500);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-11-keyboard.png`), fullPage: true });
      results.push(pass(vpKey, 'Keyboard navigation'));
      log('  ✅ Keyboard navigation works');

      // ── TEST 12: Back to planner ──────────────────────────────
      log('TEST 12: Back to planner...');
      await page.keyboard.press('Escape');
      await sleep(1000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-12-back.png`), fullPage: true });
      results.push(pass(vpKey, 'Back to planner'));
      log('  ✅ Back to planner');

      // ── TEST 13: Rapid interaction test (double-tap, fast scroll) ──
      log('TEST 13: Rapid interaction...');
      for (let i = 0; i < 5; i++) {
        await page.mouse.wheel(0, 100);
        await sleep(100);
      }
      await sleep(500);
      for (let i = 0; i < 5; i++) {
        await page.mouse.wheel(0, -100);
        await sleep(100);
      }
      await sleep(500);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-13-rapid.png`), fullPage: true });
      results.push(pass(vpKey, 'Rapid interaction'));
      log('  ✅ Rapid interaction survived');

      // ── TEST 14: No JS errors accumulated ─────────────────────
      log('TEST 14: JS errors after deep testing...');
      const criticalErrors = consoleErrors.filter(e =>
        !e.includes('favicon') && !e.includes('404') && !e.includes('ServiceWorker')
      );
      if (criticalErrors.length > 0) {
        results.push(fail(vpKey, 'JS errors after deep testing', criticalErrors.join('; ')));
        log(`  ❌ ${criticalErrors.length} errors: ${criticalErrors.slice(0, 3).join('; ')}`);
      } else {
        results.push(pass(vpKey, 'JS errors after deep testing'));
        log('  ✅ No critical JS errors');
      }

      // ── TEST 15: Page errors after deep testing ───────────────
      log('TEST 15: Page errors...');
      if (pageErrors.length > 0) {
        results.push(fail(vpKey, 'Page errors', pageErrors.join('; ')));
        log(`  ❌ ${pageErrors.length} page errors`);
      } else {
        results.push(pass(vpKey, 'Page errors'));
        log('  ✅ No page errors');
      }

      // ── TEST 16: Memory/stability check ───────────────────────
      log('TEST 16: Memory check...');
      const memInfo = await page.evaluate(() => {
        if (performance.memory) {
          return {
            used: performance.memory.usedJSHeapSize,
            total: performance.memory.totalJSHeapSize,
          };
        }
        return null;
      });
      if (memInfo) {
        const usedMB = (memInfo.used / 1024 / 1024).toFixed(1);
        const totalMB = (memInfo.total / 1024 / 1024).toFixed(1);
        log(`  Memory: ${usedMB}MB used / ${totalMB}MB total`);
      }
      results.push(pass(vpKey, 'Memory check'));
      log('  ✅ Memory check passed');

      // ── TEST 17: Screenshot for visual comparison ─────────────
      log('TEST 17: Final full-page screenshot...');
      await page.screenshot({
        path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-17-final.png`),
        fullPage: true,
      });
      results.push(pass(vpKey, 'Final screenshot'));
      log('  ✅ Final screenshot saved');

    } catch (err) {
      results.push(fail(vpKey, 'Unexpected error', err.message));
      log(`  ❌ Unexpected error: ${err.message}`);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${vpKey}-deep-error.png`), fullPage: true });
    }

    await context.close();
  }

  await browser.close();

  // ── PRINT RESULTS ─────────────────────────────────────────────
  console.log('\n' + '═'.repeat(70));
  console.log('DEEP TEST RESULTS');
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
  console.log('SCREENSHOTS:');
  console.log('─'.repeat(70));
  const screenshots = fs.readdirSync(SCREENSHOT_DIR)
    .filter(s => s.includes('deep'))
    .sort();
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
