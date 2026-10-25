// Nachgebautes Home Assistant mit der Integration „Briefankündigung“ – für die Tests (Plasma und macOS).
// Aufruf: node test/ha-mock.mjs [port]   Token: test-token (HA_MOCK_TOKEN)
// Dazu eine nachgebaute GitHub-Release-Liste unter /github/releases (für den Updater, ohne Anmeldung).
import http from 'node:http';
import fs from 'node:fs';
import zlib from 'node:zlib';

const TOKEN = process.env.HA_MOCK_TOKEN || 'test-token';
const PORT = Number(process.argv[2] || 8123);
const LOG = process.env.HA_MOCK_LOG || '/tmp/brief-mock.log';
const log = (z) => { try { fs.appendFileSync(LOG, z + '\n'); } catch { /* egal */ } };

/** Briefumschlag als PNG (ohne Bibliothek): Papier, dunkler Kopf, Adresszeilen, Marke */
function umschlagPNG(b = 480, h = 300, n = 0) {
  const zeilen = [];
  for (let y = 0; y < h; y++) {
    const z = [0];
    for (let x = 0; x < b; x++) {
      let p = [246, 244, 238];
      if (y < 34) p = n % 2 ? [20, 60, 120] : [34, 34, 34];
      else if (y > 150 && y < 160 && x > 54 && x < 260 + n * 20) p = [60, 60, 60];
      else if ((y > 176 && y < 184 || y > 198 && y < 206) && x > 54 && x < 300) p = [100, 100, 100];
      else if (x > 370 && x < 436 && y > 56 && y < 122) p = n % 2 ? [40, 140, 70] : [200, 40, 40];
      z.push(...p);
    }
    zeilen.push(Buffer.from(z));
  }
  const tab = []; for (let k = 0; k < 256; k++) { let c = k; for (let j = 0; j < 8; j++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; tab[k] = c >>> 0; }
  const crc = (buf) => { let r = 0xffffffff; for (const x of buf) r = tab[(r ^ x) & 255] ^ (r >>> 8); return (r ^ 0xffffffff) >>> 0; };
  const block = (art, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const ad = Buffer.concat([Buffer.from(art), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(ad)); return Buffer.concat([l, ad, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(b, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), block('IHDR', ihdr), block('IDAT', zlib.deflateSync(Buffer.concat(zeilen))), block('IEND', Buffer.alloc(0))]);
}

const jetzt = Date.now();
const heute = new Date(); heute.setHours(7, 40, 0, 0);
const POST = {
  erledigt: new Set(), stand: jetzt - 2 * 3600e3, abrufe: 0,
  briefe: [
    { id: 'a'.repeat(20), datum: Math.min(jetzt - 60e3, heute.getTime()), absender: 'Finanzamt Hamburg-Nord', art: 'brief', bild: true, wichtig: true, konto: 'e1', konto_name: 'Christian' },
    { id: 'b'.repeat(20), datum: Math.min(jetzt - 120e3, heute.getTime() - 600e3), absender: 'AOK Nordwest', art: 'brief', bild: true, konto: 'e1', konto_name: 'Christian' },
    { id: 'f'.repeat(20), datum: Math.min(jetzt - 180e3, heute.getTime() - 900e3), absender: 'Sparkasse Holstein', art: 'brief', bild: true, konto: 'e2', konto_name: 'Johanna' },
    { id: 'c'.repeat(20), datum: jetzt - 26 * 3600e3, absender: 'Thalia Bücher GmbH', art: 'paket', bild: false, sendung: '00340434161094015902', stand: 'heute', konto: 'e1', konto_name: 'Christian',
      verlauf: [{ stand: 'unterwegs', datum: jetzt - 50 * 3600e3 }, { stand: 'heute', datum: jetzt - 26 * 3600e3 }] },
    { id: 'd'.repeat(20), datum: jetzt - 50 * 3600e3, absender: 'Stadtwerke Hamburg', art: 'brief', bild: false, konto: 'e1', konto_name: 'Christian' },
    { id: 'e'.repeat(20), datum: jetzt - 74 * 3600e3, absender: 'Zalando SE', art: 'paket', bild: false, sendung: '1234567890123', stand: 'zugestellt', konto: 'e1', konto_name: 'Christian' },
  ],
};
const KONTEN = [
  { id: 'e1', name: 'Christian', fehler: '', zeiten: ['02:00', '05:00'] },
  { id: 'e2', name: 'Johanna', fehler: '', zeiten: ['02:00', '05:00'] },
];
function naechster() {
  const k = [];
  for (const tag of [0, 1]) for (const h of [2, 5]) { const d = new Date(); d.setDate(d.getDate() + tag); d.setHours(h, 0, 0, 0); if (d > new Date()) k.push(d.getTime()); }
  return Math.min(...k);
}

const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    log(`${req.method} ${req.url} ${body.slice(0, 200)}`);
    const json = (o, code = 200) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(o)); };
    if (req.url.startsWith('/github/releases')) {
      return json([
        { tag_name: 'v9.9.9', name: '9.9.9', draft: false, prerelease: false, html_url: 'https://github.com/Teyro/Briefankuendigung-Desktop/releases/tag/v9.9.9',
          body: '**Neu**\n\n- Testversion für den Updater', assets: [
            { name: 'briefankuendigung.plasmoid', browser_download_url: 'https://github.com/Teyro/Briefankuendigung-Desktop/releases/download/v9.9.9/briefankuendigung.plasmoid' },
            { name: 'Briefankuendigung-macOS-9.9.9.zip', browser_download_url: 'https://github.com/Teyro/Briefankuendigung-Desktop/releases/download/v9.9.9/Briefankuendigung-macOS-9.9.9.zip' }] },
        { tag_name: 'v1.0.0', name: '1.0.0', draft: false, prerelease: false, body: 'Erste Version', assets: [] }]);
    }
    if (req.headers.authorization !== 'Bearer ' + TOKEN) { res.writeHead(401); res.end('401: Unauthorized'); return; }
    const url = new URL(req.url, 'http://x');
    if (url.pathname === '/api/') return json({ message: 'API running.' });
    if (url.pathname === '/api/config') return json({ location_name: 'Zuhause', version: '2026.10.0' });
    if (!url.pathname.startsWith('/api/briefankuendigung/')) { res.writeHead(404); res.end('404: Not Found'); return; }
    const p = url.pathname.slice(23);
    const k = (url.searchParams.get('konto') || '').toLowerCase();
    const passt = (b) => !k || b.konto === k || b.konto_name.toLowerCase() === k;
    if (p === 'briefe') {
      return json({ version: 2, stand: POST.stand, fehler: '',
        konten: KONTEN.filter((x) => !k || x.id === k || x.name.toLowerCase() === k).map((x) => ({ ...x, stand: POST.stand, naechster_abruf: naechster(), laeuft: false })),
        briefe: POST.briefe.filter(passt).map((b) => ({ ...b, erledigt: POST.erledigt.has(b.id) || b.stand === 'zugestellt' })) });
    }
    if (p.startsWith('bild/')) {
      const i = POST.briefe.findIndex((b) => b.id === p.slice(5) && b.bild);
      if (i < 0) { res.writeHead(404); return res.end(); }
      res.writeHead(200, { 'Content-Type': 'image/png' });
      return res.end(umschlagPNG(480, 300, i));
    }
    if (p === 'erledigt' && req.method === 'POST') {
      const d = JSON.parse(body || '{}');
      if (!POST.briefe.some((b) => b.id === d.id)) return json({ message: 'Brief nicht gefunden' }, 404);
      if (d.erledigt) POST.erledigt.add(d.id); else POST.erledigt.delete(d.id);
      return json(d);
    }
    if (p === 'abrufen' && req.method === 'POST') { POST.abrufe++; POST.stand = Date.now(); return json({ gestartet: 1 }, 202); }
    res.writeHead(404); res.end('404');
  });
});
server.listen(PORT, '127.0.0.1', () => console.log('Briefankündigung-Nachbau auf', PORT));
