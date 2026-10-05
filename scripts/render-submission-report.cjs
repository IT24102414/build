// npm exec --package=playwright --package=pdf-lib -- node scripts/render-submission-report.cjs
const fs = require('node:fs');
const path = require('node:path');
function dependency(name) {
  for (const dir of process.env.PATH.split(path.delimiter)) {
    try { return require(path.resolve(dir, '..', name)); } catch {}
  }
  throw new Error(`Run through npm exec --package=${name}.`);
}
const { chromium } = dependency('playwright');
const { PDFDocument } = dependency('pdf-lib');
const root = path.resolve(__dirname, '..');
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const inline = text => escape(text).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>').replace(/`([^`]+)`/g, '<code>$1</code>');
function markdown(source) {
  const result = []; let code = false, table = false;
  for (const line of source.split(/\r?\n/)) {
    if (line.startsWith('```')) { result.push(code ? '</pre>' : '<pre>'); code = !code; continue; }
    if (code) { result.push(escape(line) + '\n'); continue; }
    if (line.startsWith('|')) {
      if (!table) { result.push('<table>'); table = true; }
      if (/^\|[\s:|\-]+$/.test(line)) continue;
      result.push('<tr>' + line.split('|').slice(1, -1).map(cell => `<td>${inline(cell.trim())}</td>`).join('') + '</tr>');
      continue;
    }
    if (table) { result.push('</table>'); table = false; }
    const heading = line.match(/^(#{1,6}) (.*)$/);
    if (heading) result.push(`<h${heading[1].length}>${inline(heading[2])}</h${heading[1].length}>`);
    else if (line.trim()) result.push(`<p>${inline(line)}</p>`);
  }
  if (table) result.push('</table>');
  return result.join('\n');
}
(async () => {
  let source = fs.readFileSync(path.join(root, 'docs/submission-report.md'), 'utf8');
  source += '\n\n' + fs.readFileSync(path.join(root, 'docs/submission-completion-guide.md'), 'utf8');
  source += '\n\n' + fs.readFileSync(path.join(root, 'docs/four-student-contribution-review.md'), 'utf8');
  const individualLogs = [
    ['Student 1: Peiris DPSS', 'IT24XXXXX-Peiris-ai-usage-log.md'],
    ['Student 2: Theebika', 'IT24102414-ai-usage-log.md'],
    ['Student 3: Ramya', 'IT24102513-Ramya-ai-usage-log.md'],
    ['Student 4: Anoja', 'IT24XXXXX-Anoja-ai-usage-log.md'],
  ];
  for (const [student, file] of individualLogs) {
    source += `\n\n# ${student}: historical AI log appendix\n\nHistorical student log reproduced for review. Personal authorship, chronology, reflections and signatures must be verified by the student before submission; reproduction is not certification.\n\n`;
    source += fs.readFileSync(path.join(root, 'docs/reports', file), 'utf8');
  }
  source += '\n\n# Actual Codex maintenance disclosure\n\n' + fs.readFileSync(path.join(root, 'docs/reports/2026-10-05-codex-maintenance-log.md'), 'utf8');
  for (const file of fs.readdirSync(path.join(root, 'docs/adr')).filter(file => file.endsWith('.md')).sort()) {
    source += `\n\n# ADR appendix: ${file}\n\n` + fs.readFileSync(path.join(root, 'docs/adr', file), 'utf8');
  }
  const performance = path.join(root, 'docs/performance-results-2026-10-05.json');
  if (fs.existsSync(performance)) source += '\n\n# Measured performance appendix\n\n```json\n' + fs.readFileSync(performance, 'utf8') + '\n```\n';
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  let bytes;
  try {
    const page = await browser.newPage();
    await page.setContent(`<html><head><meta charset="utf-8"><style>
      body { font: 10.5pt Arial, sans-serif; color:#142747; line-height:1.45; }
      h1 { font-size:23pt; color:#0055c8; break-before:page; } h1:first-child { break-before:auto; }
      h2 { font-size:18pt; } h3 { font-size:13pt; } h1,h2,h3 { break-after:avoid; }
      table { width:100%; border-collapse:collapse; margin:12px 0; font-size:9pt; }
      td { border:1px solid #dbe3ee; padding:6px; vertical-align:top; overflow-wrap:anywhere; }
      tr:first-child { font-weight:bold; background:#edf5ff; } tr { break-inside:avoid; }
      p { margin:8px 0; } pre { white-space:pre-wrap; overflow-wrap:anywhere; background:#f7f9fc; padding:10px; font-size:8pt; }
      code { font-family:monospace; }
    </style></head><body>${markdown(source)}</body></html>`);
    bytes = await page.pdf({ format:'A4', printBackground:true, displayHeaderFooter:true,
      margin:{top:'20mm',bottom:'20mm',left:'18mm',right:'18mm'},
      headerTemplate:'<div style="font:8px Arial;width:100%;text-align:center;color:#64748b">BuildWise SE3090 - Technical draft; student review and signatures required</div>',
      footerTemplate:'<div style="font:8px Arial;width:100%;text-align:center;color:#64748b"><span class="pageNumber"></span> / <span class="totalPages"></span></div>' });
  } finally { await browser.close(); }
  const report = await PDFDocument.load(bytes);
  const infographicPath = path.join(root, 'docs/BuildWise_Architecture_Workflow_Colour.png');
  if (fs.existsSync(infographicPath)) {
    const infographic = await report.embedPng(fs.readFileSync(infographicPath));
    const page = report.addPage([841.89, 595.28]);
    const size = infographic.scaleToFit(805.89, 559.28);
    page.drawImage(infographic, {
      x: (841.89 - size.width) / 2,
      y: (595.28 - size.height) / 2,
      width: size.width,
      height: size.height,
    });
  }
  for (const name of ['BuildWise_ERD.pdf', 'BuildWise_Scenario.pdf']) {
    const diagram = await PDFDocument.load(fs.readFileSync(path.join(root, 'docs', name)));
    for (const page of await report.copyPages(diagram, diagram.getPageIndices())) report.addPage(page);
  }
  report.setTitle('BuildWise SE3090 consolidated report draft');
  report.setSubject('Technical evidence, ADRs, diagrams; unsigned individual sections');
  const output = path.join(root, 'docs/SE3090_G07_Consolidated_Report_Draft.pdf');
  fs.writeFileSync(output, await report.save());
  console.log(JSON.stringify({ output:path.relative(root, output), pages:report.getPageCount(), status:'Unsigned draft' }));
})().catch(error => { console.error(error.message); process.exitCode = 1; });
