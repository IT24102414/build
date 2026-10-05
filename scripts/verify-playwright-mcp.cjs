// Verify the actual Playwright MCP protocol without changing editor state.
const { spawn } = require('node:child_process');
const server = spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', 'npx.cmd --yes @playwright/mcp@latest --browser msedge --headless'], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
let buffer = '';
let completed = false;
const pending = new Map();
let requestId = 0;
function send(message) { server.stdin.write(JSON.stringify(message) + '\n'); }
function request(method, params = {}) {
  const id = ++requestId;
  return new Promise((resolve, reject) => { pending.set(id, { resolve, reject }); send({ jsonrpc: '2.0', id, method, params }); });
}
server.stdout.on('data', chunk => {
  buffer += chunk.toString();
  let end;
  while ((end = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
    let message; try { message = JSON.parse(line); } catch { continue; }
    const handler = pending.get(message.id);
    if (handler) { pending.delete(message.id); message.error ? handler.reject(new Error(message.error.message)) : handler.resolve(message.result); }
  }
});
server.stderr.on('data', () => {});
server.on('error', error => { console.error(error.message); process.exitCode = 1; });
server.on('exit', code => {
  if (!completed) { for (const handler of pending.values()) handler.reject(new Error('MCP server exited before verification: ' + code)); }
});
const timeout = setTimeout(() => { console.error('MCP verification timed out.'); server.stdin.end(); process.exitCode = 1; }, 45000);
(async () => {
  const initialized = await request('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'buildwise-mcp-verifier', version: '1.0.0' } });
  send({ jsonrpc: '2.0', method: 'notifications/initialized' });
  const result = await request('tools/list');
  const tools = result.tools.map(tool => tool.name);
  if (!tools.includes('browser_navigate') || !tools.includes('browser_snapshot')) throw new Error('Required browser tools are missing.');
  const navigation = await request('tools/call', { name: 'browser_navigate', arguments: { url: 'about:blank' } });
  if (navigation.isError) throw new Error('Browser launch failed: ' + JSON.stringify(navigation.content));
  console.log(JSON.stringify({ server: initialized.serverInfo, protocol: initialized.protocolVersion, toolCount: tools.length, browserTools: tools, browserLaunch: 'passed (Microsoft Edge, headless)' }, null, 2));
  await request('tools/call', { name: 'browser_close', arguments: {} });
  completed = true;
})().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => { clearTimeout(timeout); server.stdin.end(); });
