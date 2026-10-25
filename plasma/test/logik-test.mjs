// Prüft die gemeinsame Logik (logik.js) ohne Plasma: node plasma/test/logik-test.mjs
import fs from 'node:fs'; import vm from 'node:vm'; import assert from 'node:assert/strict';
const code = fs.readFileSync(new URL('../package/contents/ui/logik.js', import.meta.url), 'utf8').replace('.pragma library', '');
const L = {}; vm.createContext(L); vm.runInContext(code, L);
// Listen aus dem vm-Kontext haben einen anderen Prototyp – darum als JSON vergleichen
const eq = (a, b, m) => assert.equal(JSON.stringify(a), JSON.stringify(b), m);

const jetzt = new Date(2026, 9, 21, 9, 0).getTime();
const briefe = [
  { id: 'a', datum: jetzt - 3600e3, absender: 'AOK', art: 'brief', konto: 'e1', konto_name: 'Christian' },
  { id: 'b', datum: jetzt - 7200e3, absender: 'Finanzamt', art: 'brief', wichtig: true, konto: 'e1', konto_name: 'Christian' },
  { id: 'c', datum: jetzt - 86400e3, absender: 'Thalia', art: 'paket', stand: 'heute', konto: 'e1', konto_name: 'Christian' },
  { id: 'd', datum: jetzt - 2 * 86400e3, absender: 'Zalando', art: 'paket', stand: 'zugestellt', konto: 'e2', konto_name: 'Johanna' },
  { id: 'e', datum: jetzt - 3 * 86400e3, absender: '', art: 'brief', erledigt: true, konto: 'e2', konto_name: 'Johanna' },
];
const g = L.gruppen(briefe, jetzt);
eq(g.heute.map((b) => b.id), ['b', 'a'], 'heute: wichtige zuerst');
eq(g.unterwegs.map((b) => b.id), ['c']);
eq(g.angekommen.map((b) => b.id), ['d', 'e']);
eq(g.offen.map((b) => b.id), ['b', 'a', 'c']);
assert.equal(L.anzahl(g.offen), '2 Briefe, 1 Paket');
assert.equal(L.titel(g.offen), '2 Briefe, 1 Paket unterwegs');
assert.equal(L.titel([]), 'Nichts unterwegs');
assert.equal(L.datum(jetzt - 86400e3, jetzt), 'gestern');
assert.equal(L.datum(jetzt - 2 * 86400e3, jetzt), 'Mo 19.10.');
assert.equal(L.datum(jetzt - 9 * 86400e3, jetzt), '12.10.');
assert.equal(L.unterzeile(briefe[2], jetzt, true), 'kommt heute · Christian');
assert.equal(L.unterzeile(briefe[4], jetzt, false), 'angekündigt So 18.10. · angekommen');
assert.equal(L.absender(briefe[4]), 'Absender unbekannt');
eq(L.nurKonto(briefe, 'johanna').map((b) => b.id), ['d', 'e']);
eq(L.nurKonto(briefe, 'E1').map((b) => b.id), ['a', 'b', 'c']);
assert.equal(L.nurKonto(briefe, '').length, 5);
assert.equal(L.paketStufe(briefe[2]), 2);
assert.equal(L.blaettern(0, -1, 3), 2);
assert.equal(L.blaettern(2, 1, 3), 0);
assert.equal(L.naechsterAbruf([{ naechster_abruf: 5 }, { naechster_abruf: 3 }, {}]), 3);
assert.equal(L.vor(jetzt - 3 * 3600e3, jetzt), 'vor 3 h');
assert.equal(L.adresse(' homeassistant.local:8123/ '), 'https://homeassistant.local:8123');
assert.equal(L.bildAdresse(new Uint8Array([0xff, 0xd8, 0xff])), 'data:image/jpeg;base64,/9j/');
assert.equal(L.bildAdresse(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d])), 'data:image/png;base64,' + Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d]).toString('base64'));
const tb = L.toolboxZugang(JSON.stringify([{ id: 'i1', adresse: 'http://a:8123', token: 'x' }, { id: 'i2', adresse: 'b', token: 'y', favorit: true }]));
assert.equal(tb.adresse, 'https://b'); assert.equal(tb.token, 'y');
assert.equal(L.toolboxZugang('kaputt'), null);
// Updates: nur Downloads aus diesem Projekt
const rel = [{ tag_name: 'v1.2.0', name: '1.2.0', body: 'x', html_url: 'https://github.com/Teyro/Briefankuendigung-Desktop/releases/tag/v1.2.0',
  assets: [{ name: 'briefankuendigung.plasmoid', browser_download_url: 'https://github.com/Teyro/Briefankuendigung-Desktop/releases/download/v1.2.0/briefankuendigung.plasmoid' }] },
  { tag_name: 'v1.1.0', assets: [] }, { tag_name: 'v2.0.0', draft: true, assets: [] }];
const u = L.updateAusReleases(rel, '1.0.0', 'briefankuendigung.plasmoid');
assert.equal(u.version, '1.2.0'); assert.equal(u.notizen.length, 2); assert.ok(u.url.endsWith('/v1.2.0/briefankuendigung.plasmoid'));
rel[0].assets[0].browser_download_url = 'https://boese.example/x.plasmoid';
assert.equal(L.updateAusReleases(rel, '1.0.0', 'briefankuendigung.plasmoid').url, '');
assert.equal(L.updateAusReleases(rel, '1.2.0', 'briefankuendigung.plasmoid'), null);
console.log('logik.js: alle Prüfungen bestanden');
