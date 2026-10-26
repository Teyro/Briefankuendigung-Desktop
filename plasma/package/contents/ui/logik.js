.pragma library
// Reine Hilfsfunktionen ohne Qt-Abhängigkeiten – werden auch außerhalb von Plasma getestet (plasma/test).

// ------------------------------------------------------------------ Sprache
var _uebersetzen = function (s) { return s; };
function sprache(uebersetzen) { if (uebersetzen) _uebersetzen = uebersetzen; }
/** Text übersetzen; %1, %2 … durch Werte ersetzen */
function t(text) {
    var s = _uebersetzen(text) || text, werte = Array.prototype.slice.call(arguments, 1);
    for (var i = werte.length; i >= 1; i--) s = s.split("%" + i).join(String(werte[i - 1]));
    return s;
}

// ------------------------------------------------------------------ Briefe und Pakete
/** Erledigt: als angekommen markiert oder zugestelltes Paket. */
function erledigt(b) { return !!b.erledigt || (b.art === "paket" && b.stand === "zugestellt"); }
function gleicherTag(a, b) { var x = new Date(a), y = new Date(b); return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth() && x.getDate() === y.getDate(); }

/** Nur ein Postfach (Name oder ID, ohne Groß/klein); "" = alle */
function nurKonto(briefe, konto) {
    var k = String(konto || "").trim().toLowerCase();
    if (!k) return briefe || [];
    return (briefe || []).filter(function (b) { return b.konto === k || String(b.konto_name || "").toLowerCase() === k; });
}

/**
 * Gruppieren: heute angekündigt / noch unterwegs / angekommen.
 * Unterwegs: wichtige zuerst, sonst neueste zuerst.
 */
function gruppen(briefe, jetzt) {
    var g = { heute: [], unterwegs: [], angekommen: [] };
    var sortiert = (briefe || []).slice().sort(function (a, b) { return (!!b.wichtig - !!a.wichtig) || (b.datum - a.datum); });
    for (var i = 0; i < sortiert.length; i++) {
        var b = sortiert[i];
        if (erledigt(b)) g.angekommen.push(b);
        else if (gleicherTag(b.datum, jetzt)) g.heute.push(b);
        else g.unterwegs.push(b);
    }
    g.angekommen.sort(function (a, b) { return b.datum - a.datum; });
    g.offen = g.heute.concat(g.unterwegs);
    return g;
}

/** „2 Briefe, 1 Paket“ */
function anzahl(liste) {
    var p = 0;
    for (var i = 0; i < liste.length; i++) if (liste[i].art === "paket") p++;
    var b = liste.length - p, teile = [];
    if (b) teile.push(b === 1 ? t("1 Brief") : t("%1 Briefe", b));
    if (p) teile.push(p === 1 ? t("1 Paket") : t("%1 Pakete", p));
    return teile.join(", ");
}

/** Überschrift: „3 Briefe unterwegs“ bzw. „Nichts unterwegs“ */
function titel(offen) { return offen.length ? t("%1 unterwegs", anzahl(offen)) : t("Nichts unterwegs"); }

/** „heute“, „gestern“, „Mo 19.10.“ */
function datum(ms, jetzt) {
    var tag = function (x) { var d = new Date(x); return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(); };
    var diff = Math.round((tag(jetzt) - tag(ms)) / 86400000);
    if (diff === 0) return t("heute");
    if (diff === 1) return t("gestern");
    var d = new Date(ms);
    var wt = [t("So"), t("Mo"), t("Di"), t("Mi"), t("Do"), t("Fr"), t("Sa")][d.getDay()];
    return (diff > 1 && diff < 7 ? wt + " " : "") + d.getDate() + "." + (d.getMonth() + 1) + ".";
}

/** Zeile unter dem Absender: „angekündigt heute“, „kommt heute“, „zugestellt“ (+ Postfach) */
function unterzeile(b, jetzt, mitKonto) {
    if (b.art === "paket" && (b.dienst || b.erwartet || b.kundenkonto)) return paketZeile(b, jetzt, mitKonto);
    var teile = [];
    if (b.art === "paket" && b.stand === "zugestellt") teile.push(t("zugestellt"));
    else if (b.art === "paket" && b.stand === "heute") teile.push(t("kommt heute"));
    else teile.push(t("angekündigt %1", datum(b.datum, jetzt)));
    if (b.erledigt && b.art !== "paket") teile.push(t("angekommen"));
    if (mitKonto && b.konto_name) teile.push(b.konto_name);
    return teile.join(" · ");
}

function absender(b) { return b.absender || (b.art === "paket" ? t("Paket") : t("Absender unbekannt")); }

/** Stand eines Pakets als Stufe 1–3 (unterwegs, kommt heute, zugestellt) */
function paketStufe(b) { return b.stand === "zugestellt" ? 3 : b.stand === "heute" || b.stand === "abholbereit" ? 2 : 1; }

/** „vor 5 min“, „vor 3 h“ */
function vor(ms, jetzt) {
    if (!ms) return "";
    var min = Math.max(0, Math.round((jetzt - ms) / 60000));
    if (min < 1) return t("gerade eben");
    if (min < 60) return t("vor %1 min", min);
    var h = Math.floor(min / 60);
    if (h < 24) return t("vor %1 h", h);
    return t("vor %1 d", Math.floor(h / 24));
}

/** Nächster Abruf der Integration (frühester aller gezeigten Postfächer), 0 = unbekannt */
function naechsterAbruf(konten) {
    var n = 0;
    for (var i = 0; i < (konten || []).length; i++) {
        var x = konten[i].naechster_abruf || 0;
        if (x && (!n || x < n)) n = x;
    }
    return n;
}

/** Index beim Durchblättern (läuft im Kreis) */
function blaettern(index, schritt, anzahl) { return anzahl ? ((index + schritt) % anzahl + anzahl) % anzahl : 0; }

var _B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
/** Bytes (Uint8Array) als data:-Adresse für ein Image – die Bilder brauchen das Token, das kann Image nicht. */
function bildAdresse(bytes) {
    var typ = bytes[0] === 0x89 && bytes[1] === 0x50 ? "image/png" : bytes[0] === 0x47 && bytes[1] === 0x49 ? "image/gif"
            : bytes[0] === 0x52 && bytes[1] === 0x49 ? "image/webp" : "image/jpeg";
    var teile = [], n = bytes.length;
    for (var i = 0; i < n; i += 3) {
        var a = bytes[i], b = i + 1 < n ? bytes[i + 1] : 0, c = i + 2 < n ? bytes[i + 2] : 0;
        var x = (a << 16) | (b << 8) | c;
        teile.push(_B64.charAt((x >> 18) & 63) + _B64.charAt((x >> 12) & 63) + (i + 1 < n ? _B64.charAt((x >> 6) & 63) : "=") + (i + 2 < n ? _B64.charAt(x & 63) : "="));
    }
    return "data:" + typ + ";base64," + teile.join("");
}

/** DHL-Sendungsverfolgung */
function dhlAdresse(nummer) { return "https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=" + encodeURIComponent(nummer); }

/** Adresse aufräumen: ohne Schrägstrich am Ende, ohne Leerzeichen; ohne http(s):// → https:// */
function adresse(s) {
    var a = String(s || "").trim().replace(/\/+$/, "");
    if (a && !/^https?:\/\//i.test(a)) a = "https://" + a;
    return a;
}

/** Zugang aus Home Assistant ToolBox (~/.config/homeassistanttoolbox/instanzen.json): Favorit zuerst */
function toolboxZugang(text) {
    var liste;
    try { liste = JSON.parse(text); } catch (e) { return null; }
    if (!Array.isArray(liste)) return null;
    liste = liste.filter(function (i) { return i && i.adresse && i.token; });
    if (!liste.length) return null;
    var f = liste.filter(function (i) { return i.favorit; })[0] || liste[0];
    return { adresse: adresse(f.adresse), token: String(f.token), name: f.name || "" };
}

// ------------------------------------------------------------------ Updates
function versionNeuer(a, b) {
    var x = String(a).replace(/^v/, "").split(/[.-]/).map(function (n) { return parseInt(n, 10) || 0; });
    var y = String(b).replace(/^v/, "").split(/[.-]/).map(function (n) { return parseInt(n, 10) || 0; });
    for (var i = 0; i < Math.max(x.length, y.length); i++) {
        if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
    }
    return false;
}

var REPO = "https://github.com/Teyro/Briefankuendigung-Desktop/";

/** Aus der Release-Liste von GitHub: alle neueren Versionen mit Änderungen und die Download-Adresse */
function updateAusReleases(releases, aktuell, dateiname) {
    var neuer = (releases || []).filter(function (r) { return r && typeof r.tag_name === "string" && !r.draft && !r.prerelease && versionNeuer(r.tag_name, aktuell); });
    neuer.sort(function (a, b) { return versionNeuer(a.tag_name, b.tag_name) ? -1 : 1; });
    if (!neuer.length) return null;
    var asset = (neuer[0].assets || []).filter(function (a) { return a.name === dateiname; })[0];
    var url = asset ? String(asset.browser_download_url || "") : "";
    // nur Downloads aus diesem Projekt auf GitHub
    if (url && (url.indexOf(REPO + "releases/download/") !== 0 || url.indexOf("..") >= 0)) url = "";
    var seite = String(neuer[0].html_url || "");
    if (seite.indexOf(REPO) !== 0) seite = REPO + "releases";
    return {
        version: neuer[0].tag_name.replace(/^v/, ""),
        url: url,
        seite: seite,
        notizen: neuer.map(function (r) { return { version: r.tag_name.replace(/^v/, ""), titel: r.name || r.tag_name, text: r.body || "" }; })
    };
}

// ------------------------------------------------------------------ Pakete (DHL, Hermes, DPD, Amazon)
var DIENSTE = {
    dhl: { name: "DHL", farbe: "#FFCC00", schrift: "#D40511" },
    hermes: { name: "Hermes", farbe: "#0091CD", schrift: "#FFFFFF" },
    dpd: { name: "DPD", farbe: "#DC0032", schrift: "#FFFFFF" },
    amazon: { name: "Amazon", farbe: "#232F3E", schrift: "#FF9900" }
};
function dienst(b) { return DIENSTE[b.dienst || "dhl"] || { name: b.dienst_name || b.dienst || "", farbe: "#777777", schrift: "#FFFFFF" }; }

/** Nur Briefe bzw. nur Pakete ("alles" = beides) */
function nurArt(briefe, inhalt) {
    if (inhalt === "briefe") return (briefe || []).filter(function (b) { return b.art !== "paket"; });
    if (inhalt === "pakete") return (briefe || []).filter(function (b) { return b.art === "paket"; });
    return briefe || [];
}

function isoTag(ms) { var d = new Date(ms); return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2); }

/** Kommt heute: Stand „heute“/„abholbereit“ oder heute erwartet */
function paketHeute(b, jetzt) { return b.stand === "heute" || b.stand === "abholbereit" || (!!b.erwartet && b.erwartet === isoTag(jetzt)); }

/**
 * Pakete gruppieren: heute (kommt heute, abholbereit) / unterwegs (nach Termin) / zugestellt.
 */
function paketGruppen(briefe, jetzt) {
    var p = nurArt(briefe, "pakete"), g = { heute: [], unterwegs: [], angekommen: [] };
    for (var i = 0; i < p.length; i++) {
        var b = p[i];
        if (erledigt(b)) g.angekommen.push(b);
        else if (paketHeute(b, jetzt)) g.heute.push(b);
        else g.unterwegs.push(b);
    }
    var nachTermin = function (a, b) { return (a.erwartet || "9999") < (b.erwartet || "9999") ? -1 : (a.erwartet || "9999") > (b.erwartet || "9999") ? 1 : b.datum - a.datum; };
    g.heute.sort(nachTermin); g.unterwegs.sort(nachTermin);
    g.angekommen.sort(function (a, b) { return b.datum - a.datum; });
    g.offen = g.heute.concat(g.unterwegs);
    return g;
}

/** „voraussichtlich Do 23.10., 10:00–13:00“, „heute 9:30–10:30“, „zur Abholung bereit“ */
function erwartetText(b, jetzt) {
    if (b.stand === "zugestellt") return t("zugestellt");
    if (b.stand === "abholbereit") return t("zur Abholung bereit");
    var f = b.zeitfenster ? ", " + b.zeitfenster : "";
    if (b.erwartet) {
        var teile = b.erwartet.split("-"), d = new Date(+teile[0], +teile[1] - 1, +teile[2]).getTime();
        var tage = Math.round((new Date(+teile[0], +teile[1] - 1, +teile[2]).getTime() - new Date(new Date(jetzt).getFullYear(), new Date(jetzt).getMonth(), new Date(jetzt).getDate()).getTime()) / 86400000);
        if (tage === 0) return t("kommt heute") + f;
        if (tage === 1) return t("kommt morgen") + f;
        var x = new Date(d), wt = [t("So"), t("Mo"), t("Di"), t("Mi"), t("Do"), t("Fr"), t("Sa")][x.getDay()];
        return t("voraussichtlich %1", (tage > 1 && tage < 7 ? wt + " " : "") + x.getDate() + "." + (x.getMonth() + 1) + ".") + f;
    }
    if (b.stand === "heute") return t("kommt heute") + f;
    return t("unterwegs");
}

/** Zeile unter dem Absender eines Pakets: Termin · Kundenkonto · Postfach */
function paketZeile(b, jetzt, mitKonto) {
    var teile = [erwartetText(b, jetzt)];
    if (b.kundenkonto) teile.push(b.kundenkonto);
    else if (mitKonto && b.konto_name) teile.push(b.konto_name);
    return teile.join(" · ");
}

/** Titel für Pakete: „3 Pakete unterwegs“ */
function paketTitel(offen) { return offen.length ? t("%1 unterwegs", anzahl(offen)) : t("Keine Pakete unterwegs"); }

/** Dienst an der Sendungsnummer erkennen ("" = nicht eindeutig) – wie in der Integration */
function dienstVonNummer(n) {
    n = String(n || "").replace(/\s+/g, "").toUpperCase();
    if (/^(TBA\d{9,14}|\d{3}-\d{7}-\d{7})$/.test(n)) return "amazon";
    if (/^(JJD\d{12,20}|00\d{18}|\d{20}|\d{12})$/.test(n)) return "dhl";
    if (/^H[0-9A-Z]{19}$/.test(n)) return "hermes";
    return "";
}
