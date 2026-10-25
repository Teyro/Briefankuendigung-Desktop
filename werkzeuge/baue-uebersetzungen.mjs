// Erzeugt aus i18n/en.json:
//  - Plasma: plasma/package/contents/locale/en/LC_MESSAGES/plasma_applet_<id>.mo (gettext)
//  - Mac: macos/ressourcen/i18n/en.json und macos/ressourcen/sprachen/<de|en>.lproj/Localizable.strings
// Aufruf: node werkzeuge/baue-uebersetzungen.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const wurzel = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const id = JSON.parse(fs.readFileSync(path.join(wurzel, 'plasma/package/metadata.json'), 'utf8')).KPlugin.Id;

// gettext .mo (little endian, ohne Hash-Tabelle)
function mo(eintraege) {
  const liste = [['', 'Content-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n'], ...Object.entries(eintraege).filter(([, v]) => v)]
    .map(([k, v]) => [Buffer.from(k, 'utf8'), Buffer.from(v, 'utf8')])
    .sort((a, b) => Buffer.compare(a[0], b[0]));
  const n = liste.length, kopf = 28, tabO = kopf, tabT = kopf + n * 8;
  let daten = tabT + n * 8;
  const teile = [], o = Buffer.alloc(n * 8), t = Buffer.alloc(n * 8);
  liste.forEach(([k], i) => { o.writeUInt32LE(k.length, i * 8); o.writeUInt32LE(daten, i * 8 + 4); teile.push(k, Buffer.from([0])); daten += k.length + 1; });
  liste.forEach(([, v], i) => { t.writeUInt32LE(v.length, i * 8); t.writeUInt32LE(daten, i * 8 + 4); teile.push(v, Buffer.from([0])); daten += v.length + 1; });
  const h = Buffer.alloc(kopf);
  h.writeUInt32LE(0x950412de, 0); h.writeUInt32LE(0, 4); h.writeUInt32LE(n, 8); h.writeUInt32LE(tabO, 12); h.writeUInt32LE(tabT, 16); h.writeUInt32LE(0, 20); h.writeUInt32LE(daten, 24);
  return Buffer.concat([h, o, t, ...teile]);
}
const esc = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
const strings = (tab) => Object.entries(tab).filter(([, v]) => v).map(([k, v]) => `"${esc(k)}" = "${esc(v)}";`).join('\n') + '\n';

const en = JSON.parse(fs.readFileSync(path.join(wurzel, 'i18n/en.json'), 'utf8'));
fs.rmSync(path.join(wurzel, 'plasma/package/contents/locale'), { recursive: true, force: true });
const ordner = path.join(wurzel, 'plasma/package/contents/locale/en/LC_MESSAGES');
fs.mkdirSync(ordner, { recursive: true });
fs.writeFileSync(path.join(ordner, `plasma_applet_${id}.mo`), mo(en));
for (const [lproj, tab] of [['de', Object.fromEntries(Object.keys(en).map((k) => [k, k]))], ['en', en]]) {
  fs.mkdirSync(path.join(wurzel, 'macos/ressourcen/sprachen', lproj + '.lproj'), { recursive: true });
  fs.writeFileSync(path.join(wurzel, 'macos/ressourcen/sprachen', lproj + '.lproj', 'Localizable.strings'), strings(tab));
}
fs.mkdirSync(path.join(wurzel, 'macos/ressourcen/i18n'), { recursive: true });
fs.copyFileSync(path.join(wurzel, 'i18n/en.json'), path.join(wurzel, 'macos/ressourcen/i18n/en.json'));
console.log('Übersetzungen gebaut: en');
