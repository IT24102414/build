// Run: npm exec --yes --package=playwright -- node scripts/ui-browser-review.cjs
// Screenshots contain demo data; credentials and tokens are never exported.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
let playwright;
for (const dir of process.env.PATH.split(path.delimiter)) {
  try { playwright = require(path.resolve(dir, '..', 'playwright')); break; } catch {}
}
if (!playwright) throw new Error('Run this script through npm exec --package=playwright.');
const root = path.resolve(__dirname, '..');
const navigationForRoles = new Function(fs.readFileSync(path.join(root, 'web/buildwise-web/src/auth/accessControl.js'), 'utf8').replace(/\bexport\s+/g, '') + '\nreturn navigationForRoles;')();
const output = path.join(root, process.argv.includes('--fixtures') ? 'artifacts/ui-review' : 'artifacts/ui-review-live');
fs.mkdirSync(output, { recursive: true });
const fixtures = process.argv.includes('--fixtures');
const existingFlutter = process.argv.includes('--existing-flutter');
const ordersOnly = process.argv.includes('--purchase-orders-only');
const flutterUrl = process.env.FLUTTER_REVIEW_URL || 'http://127.0.0.1:8081';
const report = { tool: 'Local Playwright (MCP unavailable)', dataMode: fixtures ? 'Controlled browser fixtures; not live backend verification' : 'Live API', checks: [], errors: [] };
const roles = [
  ['SiteEngineer', 'site.engineer'], ['SiteOfficer', 'site.officer'],
  ['QualityInspector', 'quality.inspector'], ['SiteManager', 'site.manager'],
  ['ProcurementOfficer', 'procurement.officer'], ['ProcurementManager', 'procurement.manager'], ['Administrator', 'admin'],
];
const routes = ['/dashboard', '/material-requests', '/suppliers', '/quotations', '/rfqs', '/agent-workflows', '/purchase-orders', '/deliveries', '/quality-inspections', '/non-conformances', '/admin'];
function fixtureSession(role) { return { token: 'ui-review-fixture', expiresAtUtc: '2099-01-01T00:00:00Z', user: { id: 1, fullName: 'Review User', email: 'review@buildwise.demo', roles: [role] } }; }
async function mockApi(context, role) {
  await context.route('**/api/**', async route => {
    const pathname = new URL(route.request().url()).pathname.replace('/api', '');
    let payload = [];
    if (pathname === '/auth/login') payload = fixtureSession(role);
    else if (pathname === '/dashboard') payload = { primaryRole: role, metrics: [], tasks: [{ title: 'Material requests', description: 'Review material requests', route: '/material-requests' }], alerts: [], activity: [] };
    else if (pathname === '/suppliers') payload = { items: [{ id: 1, name: 'Riverside Building Materials', contactPerson: 'Review Supplier', email: 'supplier@example.com', phone: '0771234567', status: 'Active' }], total: 1, page: 1, pageSize: 100 };
    else if (pathname === '/purchase-orders' || pathname === '/agent-workflows') payload = { items: [], total: 0, page: 1, pageSize: 20 };
    else if (pathname === '/admin/health') payload = { status: 'healthy', database: true, agents: {} };
    else if (pathname === '/projects') payload = [{ id: 1, name: 'Riverside Apartments' }];
    else if (pathname === '/materials') payload = [{ id: 1, name: 'OPC Cement', unit: 'Bags' }];
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(payload) });
  });
}
const mime = { '.js': 'application/javascript', '.json': 'application/json', '.html': 'text/html', '.css': 'text/css', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml' };
const flutterRoot = path.join(root, 'mobile/buildwise_mobile/build/web');
const server = http.createServer((req, res) => {
  const target = path.resolve(flutterRoot, '.' + decodeURIComponent(req.url.split('?')[0] === '/' ? '/index.html' : req.url.split('?')[0]));
  if (!target.startsWith(flutterRoot + path.sep)) { res.writeHead(403); res.end(); return; }
  fs.readFile(target, (error, data) => {
    if (error) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', mime[path.extname(target)] || 'application/octet-stream');
    res.end(data);
  });
});
async function capture(page, name) {
  await page.screenshot({ path: path.join(output, name + '.png'), fullPage: true, timeout: 15000 });
}
async function webCheck(page, role, route, width) {
  await page.setViewportSize({ width, height: 900 });
  await page.goto('http://127.0.0.1:5173' + route);
  await page.waitForTimeout(650);
  const result = await page.evaluate(() => ({
    horizontalOverflow: document.documentElement.scrollWidth > innerWidth + 1,
    title: document.querySelector('h1')?.textContent,
    errors: [...document.querySelectorAll('[role="alert"], .error-state')].map(e => e.textContent),
  }));
  report.checks.push({ target: 'React', role, route, width, ...result });
  await capture(page, `web-${role}-${route.slice(1)}-${width}`);
}
(async () => {
  if (!existingFlutter) await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(8081, '127.0.0.1', resolve);
  });
  const browser = await playwright.chromium.launch({ channel: 'msedge', headless: true });
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    page.on('pageerror', error => report.errors.push({ target: 'React', message: error.message }));
    page.on('response', response => { if (response.status() >= 400 && response.url().includes('/api/')) report.errors.push({ target: 'React', status: response.status(), url: response.url() }); });
    await webCheck(page, 'anonymous', '/login', 1440);
    await webCheck(page, 'anonymous', '/login', 390);
    for (const [role, user] of roles) {
      let session;
      if (fixtures) {
        await context.unrouteAll();
        await mockApi(context, role);
        session = fixtureSession(role);
      } else {
        const response = await context.request.post('http://127.0.0.1:5078/api/auth/login', { data: { email: user + '@buildwise.demo', password: 'Passw0rd!' } });
        if (!response.ok()) { report.errors.push({ target: 'Live authentication', role, status: response.status() }); continue; }
        session = await response.json();
      }
      await page.evaluate(session => localStorage.setItem('buildwise.auth', JSON.stringify(session)), session);
      await webCheck(page, role, '/dashboard', 1440);
      await webCheck(page, role, '/dashboard', 390);
      for (const item of navigationForRoles([role]).filter(item => item.path !== '/dashboard' && (!ordersOnly || item.path === '/purchase-orders'))) {
        await webCheck(page, role, item.path, 1440);
        await webCheck(page, role, item.path, 390);
      }
    }
    await context.close();
    for (const [role, user] of roles) {
    const mobile = await browser.newContext({ viewport: { width: 390, height: 844 } });
    if (fixtures) await mockApi(mobile, role);
    const phone = await mobile.newPage();
    phone.on('pageerror', error => report.errors.push({ target: 'Flutter web', message: error.message }));
    phone.on('console', message => { if (/overflowed|EXCEPTION CAUGHT/i.test(message.text())) report.errors.push({ target: 'Flutter web', message: message.text() }); });
    await phone.goto(flutterUrl);
    await phone.locator('flutter-view').waitFor({ timeout: 30000 });
    await phone.waitForTimeout(1500);
    if (role === 'SiteEngineer') await capture(phone, 'flutter-login-390');
    const placeholder = phone.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.evaluate(element => element.click());
    await phone.waitForTimeout(500);
    const demo = phone.getByRole('button', { name: new RegExp(user.replaceAll('.', '\\.') + '@buildwise\\.demo', 'i') });
    if (await demo.count()) {
      await demo.first().scrollIntoViewIfNeeded();
      await demo.first().click();
      await phone.waitForTimeout(1800);
      await capture(phone, `flutter-${role}-dashboard-390`);
      report.checks.push({ target: 'Flutter web', role, route: 'dashboard', width: 390, semantics: await phone.locator('flt-semantics').allTextContents() });
      const expectedMenu = navigationForRoles([role]);
      const allowedLabels = new Set(expectedMenu.map(item => item.label));
      for (const item of navigationForRoles(roles.map(([name]) => name))) {
        if (!allowedLabels.has(item.label) && await phone.getByRole('button', { name: item.label, exact: true }).count()) {
          report.errors.push({ target: 'Flutter navigation parity', role, screen: item.label, message: 'Flutter exposes a workspace React does not allow for this role' });
        }
      }
      for (const item of expectedMenu.filter(item => item.path !== '/dashboard' && (!ordersOnly || item.path === '/purchase-orders'))) {
        const screen = item.label;
        const destination = phone.getByRole('button', { name: screen, exact: true });
        if (!await destination.count()) {
          report.errors.push({ target: 'Flutter navigation parity', role, screen, message: 'React workspace missing in Flutter menu' });
          continue;
        }
        await destination.first().scrollIntoViewIfNeeded();
        await destination.first().click();
        await phone.waitForTimeout(850);
        await capture(phone, `flutter-${role}-${screen}-390`);
        report.checks.push({ target: 'Flutter web', role, route: item.path, width: 390 });
        if (screen === 'Quotations') {
          const analysis = phone.getByRole('button', { name: 'Comparison & AI Recommendation', exact: true });
          if (await analysis.count()) {
            await analysis.click();
            await phone.waitForTimeout(850);
            await capture(phone, `flutter-${role}-recommendation-390`);
            report.checks.push({ target: 'Flutter web', role, route: 'Comparison & AI Recommendation', width: 390 });
            if (role === 'ProcurementManager' && await phone.getByRole('button', { name: /^(Re-run|Run) AI Analysis$/ }).count()) {
              report.errors.push({ target: 'Flutter permissions', role, message: 'Manager sees officer AI execution control' });
            }
          }
        }
      }
    } else {
      report.checks.push({ target: 'Flutter web', role, route: 'login', width: 390, note: 'Login captured; demo button semantics not found', semantics: await phone.locator('flt-semantics').allTextContents() });
    }
    await mobile.close();
    }
  } finally {
    fs.writeFileSync(path.join(output, 'browser-report.json'), JSON.stringify(report, null, 2));
    await browser.close();
    server.close();
  }
  console.log(JSON.stringify({ checks: report.checks.length, overflow: report.checks.filter(c => c.horizontalOverflow), errors: report.errors }, null, 2));
})().catch(error => { server.close(); console.error(error.message); process.exitCode = 1; });
