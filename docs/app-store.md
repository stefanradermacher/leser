# App-Store-Unterlagen

Vorbereitete Texte und Angaben für den Eintrag in App Store Connect. Zeichenzahlen sind Apples Obergrenzen.

## Grunddaten

| Feld | Wert |
|---|---|
| Name (30) | Leser |
| Untertitel (30) | PDFs lesen, sonst nichts |
| Bundle-ID | com.stefanradermacher.leser |
| SKU | leser-macos |
| Primäre Sprache | Deutsch (zusätzlich Englisch) |
| Kategorie | Produktivität (zweite: Dienstprogramme) |
| Altersfreigabe | 4+ |
| Preis | Kostenlos, mit In-App-Käufen |
| Copyright | 2026 Stefan Radermacher |
| Support-URL | https://stefanradermacher.com/leser/support |
| Marketing-URL | https://stefanradermacher.com/projects |
| Datenschutz-URL | https://stefanradermacher.com/leser/datenschutz |

Ist der Name „Leser“ schon vergeben, sind „Leser PDF“ oder „Leser – PDF“ die nächsten Kandidaten.

## Werbetext (170)

Leser zeigt PDFs, schnell und ohne Ballast: Gliederung, Miniaturen, Suche, geteilte Ansicht. Kostenlos, werbefrei, ohne Datensammlung. Verändert deine Dokumente nie.

## Beschreibung (4000)

Leser ist ein schlichter, schneller PDF-Betrachter für den Mac. Er zeigt Dokumente an und verändert sie nie. Kein Werkzeugkasten zum Bearbeiten, keine Anmeldung, keine Werbung.

**Lesen und navigieren**
• Gliederung und Seitenminiaturen in der Seitenleiste, beides mit einem Klick umschaltbar
• Blättern mit den Pfeiltasten, Sprung zu einer Seitenzahl, zurück und vorwärts nach Links im Dokument
• Fortlaufend, Einzelseite, Doppelseite oder Doppelseite mit einzelner erster Seite
• Zoomstufen sowie Anpassen an Seitenbreite, Seitenhöhe oder ganze Seite

**Suchen**
• Volltextsuche mit allen Fundstellen in einer eigenen Seitenleiste rechts, mit Textausschnitt und Seitenzahl
• Alle Treffer im Dokument hervorgehoben, Sprung von Treffer zu Treffer

**Zwei Stellen gleichzeitig**
• Geteilte Ansicht nebeneinander oder untereinander
• Beide Hälften mit eigener Position, eigenem Zoom und eigener Anzeige
• In der zweiten Hälfte lässt sich auch ein anderes Dokument öffnen

**Angenehm im Alltag**
• Merkt sich die zuletzt gelesene Stelle und die Fenstergröße
• Lädt ein Dokument automatisch neu, wenn ein anderes Programm die Datei ändert, etwa beim Export oder bei LaTeX
• Text markieren und kopieren, drucken, Dokumentinformationen einsehen
• Passwortgeschützte PDFs fragen beim Öffnen nach dem Passwort

**Ehrlich und offen**
• Kostenlos und quelloffen unter der Apache-Lizenz 2.0
• Keine Werbung, kein Tracking, keine Analyse
• Leser baut von sich aus keine Verbindung ins Internet auf; deine Dokumente und Einstellungen bleiben auf deinem Mac
• Wer mag, kann die Entwicklung mit einem freiwilligen Trinkgeld unterstützen. Es schaltet nichts frei, Leser bleibt vollständig kostenlos.

## Schlüsselwörter (100, mit Komma, ohne Leerzeichen)

PDF,Viewer,Betrachter,lesen,Dokument,Gliederung,Miniaturen,Suche,Vorschau,werbefrei,Datenschutz,schlicht

## Neue Funktionen (4000)

Erste Version.

## In-App-Käufe

Typ für alle drei: Verbrauchsartikel. Sie schalten nichts frei.

| Referenzname | Produkt-ID | Anzeigename | Beschreibung | Preis |
|---|---|---|---|---|
| Trinkgeld Kaffee | com.stefanradermacher.leser.tip.coffee | Ein Kaffee | Ein kleines Trinkgeld für die Weiterentwicklung von Leser. | 1,99 € |
| Trinkgeld Frühstück | com.stefanradermacher.leser.tip.breakfast | Ein Frühstück | Ein mittleres Trinkgeld für die Weiterentwicklung von Leser. | 4,99 € |
| Trinkgeld Abendessen | com.stefanradermacher.leser.tip.dinner | Ein Abendessen | Ein großzügiges Trinkgeld für die Weiterentwicklung von Leser. | 9,99 € |

Als Prüfbild für jeden Artikel dient `screenshots/trinkgeld.png`.

Die Anzeigenamen und Beschreibungen der drei Artikel sollten in App Store Connect auch auf Englisch hinterlegt werden: „Coffee“, „Breakfast“, „Dinner“ mit „A small/medium/generous tip for the continued work on Leser.“ Sie erscheinen in der App genau so, wie sie dort stehen.

## Datenschutzangaben im Fragebogen

„Es werden keine Daten erfasst.“ Leser sendet nichts an eigene oder fremde Server. Einstellungen und Lesepositionen liegen ausschließlich lokal. Käufe wickelt Apple ab.

## Hinweise für die Prüfung

Leser ist ein reiner PDF-Betrachter und verändert Dokumente nie. Es gibt keine Anmeldung, kein Konto und keine Testzugangsdaten.

Die drei In-App-Käufe sind freiwillige Trinkgelder für die Weiterentwicklung. Sie schalten keine Funktionen frei; alle Funktionen sind ohne Kauf verfügbar. Zu finden sind sie unter „Leser → Über Leser“ und „Hilfe → Leser unterstützen …“.

Leser fragt an seltenen Stellen, ob es die Standard-App für PDFs werden soll. Die Frage erscheint als schmale Leiste im Dokumentfenster, erst nachdem an drei verschiedenen Tagen PDFs geöffnet wurden, höchstens zweimal insgesamt, und die eigentliche Umstellung bestätigt macOS selbst.

Zum Testen eignet sich jedes beliebige PDF; im Quellcode liegt `Testdokument.pdf` mit Gliederung und mehreren Seiten.

## Screenshots

In `docs/screenshots/`, 2880 × 1800 Pixel:

| Datei | Inhalt |
|---|---|
| 1-dokument.png | Dokument mit Gliederung in der Seitenleiste |
| 2-suche.png | Suche mit Trefferliste rechts |
| 3-geteilt.png | Geteilte Ansicht mit zwei Stellen |
| 4-miniaturen.png | Miniaturen in der Seitenleiste |
| trinkgeld.png | Fenster „Leser unterstützen“ als Prüfbild für die In-App-Käufe |

Die Screenshots zeigen die deutsche Oberfläche. Für den englischen Eintrag lassen sie sich in derselben Form mit englischer Oberfläche aufnehmen; Apple erlaubt aber auch, dieselben Bilder für beide Sprachen zu verwenden.

## Vor dem Hochladen

- [ ] Vertrag für kostenpflichtige Apps aktiv, Steuer- und Bankdaten hinterlegt
- [ ] App-Eintrag angelegt, Name verfügbar
- [ ] Drei Verbrauchsartikel angelegt und zur Prüfung eingereicht
- [ ] Support- und Datenschutzseite online
- [ ] In Xcode: Team gewählt, Archiv erstellt, Validierung ohne Fehler
