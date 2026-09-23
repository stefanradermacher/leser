# Leser

Schlichter PDF-Betrachter für macOS 15+, gebaut mit SwiftUI und PDFKit. Er kann nur anzeigen, nichts bearbeiten.

Leser ist kostenlos, quelloffen (Apache-Lizenz 2.0, siehe `LICENSE`), werbefrei und sammelt keine Daten: kein Tracking, keine Analyse, keine eigenen Netzwerkverbindungen. Es nutzt ausschließlich Apple-Frameworks. Wer die Entwicklung unterstützen möchte, kann unter **Leser → Über Leser** ein freiwilliges Trinkgeld über den App Store geben; es schaltet nichts frei.

Nicht Teil des lizenzierten Werks sind die Kennzeichen des Projekts: der Name „Leser“, das App- und das Dokumentsymbol, die Monogramme und `scripts/make_icon.swift`, das die Symbole zeichnet. Was damit erlaubt ist, steht in `TRADEMARKS.md` — kurz gesagt: über Leser reden und die unveränderte App weitergeben ja, eine Abspaltung unter diesem Namen nein. `NOTICE` hält den Umfang fest und ist nach Abschnitt 4(d) der Lizenz bei jeder Weitergabe mitzuführen. Der Code selbst bleibt frei verwendbar.

Für die Veröffentlichung im Mac App Store liegen unter `docs/` die vorbereiteten Texte (`app-store.md`), die Datenschutzerklärung (`datenschutz.md`), die Support-Seite (`support.md`) und die Screenshots.

Die Oberfläche gibt es auf Deutsch und Englisch. Die Texte liegen im String-Katalog `Resources/Localizable.xcstrings`; die Schlüssel sind die deutschen Sätze. Neue Texte holt man mit `xcodebuild -exportLocalizations -project Leser.xcodeproj -localizationPath <Ordner> -exportLanguage en` heraus und trägt die Übersetzung im Katalog nach.

## Bauen

Leser ist ein Xcode-Projekt (`Leser.xcodeproj`, Xcode 26 oder neuer, macOS 15+). In Xcode öffnen und mit ⌘R starten; für einen signierten Build unter „Signing & Capabilities“ das eigene Team eintragen.

Ohne Xcode-Oberfläche und ohne Entwicklerkonto:

```
./build.sh
```

Das baut `build/Leser.app` mit `xcodebuild` (lokal ad hoc signiert, mit derselben Sandbox wie im App Store) und installiert die App nach `/Applications`. Läuft Leser gerade, wird es vorher beendet und danach wieder geöffnet. Nur bauen, ohne zu installieren: `./build.sh --no-install`.

Die Versionsnummer (z. B. 1.0) steht im Projekt unter „Version“ (`MARKETING_VERSION`) und wird von Hand erhöht. Die Build-Nummer in Klammern steht als `CURRENT_PROJECT_VERSION` in `Config/Leser.xcconfig` und ist damit eingecheckter Zustand: Xcode und `build.sh` lesen dieselbe Zahl, sie kann nicht sinken, und im Verlauf sieht man, welcher Commit welchen Build ergeben hat.

**Vor jedem Upload in den App Store einmal `./scripts/bump-build.sh` ausführen und mitcommitten** — App Store Connect verlangt für jeden Upload eine höhere Nummer als für den vorigen. Lokale Builds brauchen das nicht.

Nachträglich lässt sich die Nummer nicht setzen: `CFBundleVersion` wird beim Verarbeiten der `Info.plist` eingesetzt, und ein Skript, das die fertige Plist im Produkt ändert, wird von Xcode danach wieder überschrieben.

Das App-Icon und das Dokumentsymbol werden von `scripts/make_icon.swift` gezeichnet: das App-Icon in den Asset-Katalog, das Dokumentsymbol nach `Resources/PDFDocument.icns`. Nach Änderungen an der Zeichnung im Projektordner `swift scripts/make_icon.swift` ausführen. Das Dokumentsymbol zeigt macOS nur, wenn Leser die Standard-App für PDFs ist, und auch dann meist nur dort, wo es keine Seitenvorschau gibt.

`scripts/make_handbook.swift` zeichnet `docs/Leser-Handbuch.pdf`, ein neunseitiges Handbuch mit Gliederung. Es erklärt die Bedienung, dient zugleich als Beispieldokument und ist in den Screenshots für den App Store zu sehen. Nach Änderungen am Text im Projektordner `swift scripts/make_handbook.swift` ausführen; `swift scripts/make_handbook.swift en` schreibt die englische Fassung nach `docs/Leser-Handbook.pdf`.

### Projektstruktur

- `Sources/Leser/`: Quellcode; neue Dateien gehören automatisch zum Projekt
- `Resources/`: Asset-Katalog mit App-Icon, Monogramme, Lokalisierung, `PrivacyInfo.xcprivacy`
- `Config/Info.plist`, `Config/Leser.entitlements`: App-Einstellungen und Sandbox-Berechtigungen (nur Lesezugriff auf selbst gewählte Dateien und Drucken)
- `Config/Leser.xcconfig`: Build-Einstellungen; bindet optional `Config/Local.xcconfig` ein

Zum Signieren mit eigenem Entwicklerkonto `Config/Local.xcconfig.example` nach `Config/Local.xcconfig` kopieren und die eigene Team-ID eintragen. Die Datei bleibt lokal. Ohne sie baut Xcode ohne Team, und `./build.sh` signiert wie immer ad hoc.

PDFs öffnen per Doppelklick („Öffnen mit“), per Drag & Drop aufs Dock-Symbol oder mit ⌘O.

## Bedienung

| Funktion | Tastatur |
|---|---|
| Suchen / Weitersuchen / Rückwärts | ⌘F / ⌘G oder ↩ im Suchfeld / ⇧⌘G |
| Suchergebnisse ein-/ausblenden | ⌥⌘F |
| Seitenleiste ein-/ausblenden | ⌃⌘S |
| Seitenleiste mit Gliederung / Miniaturen | ⌃⌘1 / ⌃⌘2 |
| Vergrößern / Verkleinern / Originalgröße | ⌘+ / ⌘- / ⌘0 |
| Seitenbreite / Seitenhöhe / Ganze Seite | ⌘1 / ⌘2 / ⌘3 |
| Fortlaufend / Einzelseite / Doppelseite / Doppelseite (erste Seite einzeln) | ⌥⌘1 / ⌥⌘2 / ⌥⌘3 / ⌥⌘4 |
| Vorherige / nächste Seite | ← / → oder ⌥⌘↑ / ⌥⌘↓ |
| Erste / letzte Seite | ⌥⌘Pos1 / ⌥⌘Ende |
| Zurück / Vorwärts (nach Link- oder Gliederungssprung) | ⌘[ / ⌘] |
| Gehe zu Seite … | ⌥⌘G |
| Ansicht teilen / geteilte Ansicht schließen | ⌃⌘T |
| Dokumentinformationen | ⌘I |
| Drucken / Papierformat | ⌘P / ⇧⌘P |
| Text kopieren | markieren, ⌘C |

Die Anzeige (Fortlaufend, Einzelseite, Doppelseite) lässt sich über das Menü „Darstellung“ oder das Symbol in der Symbolleiste wählen; welche beim Öffnen gilt, steht in den Einstellungen. Die Einstellungen „Seitenbreite“, „Seitenhöhe“ und „Ganze Seite“ bleiben beim Ändern der Fenstergröße erhalten. Zoomen mit zwei Fingern auf dem Trackpad funktioniert ebenfalls. Passwortgeschützte PDFs fragen beim Öffnen nach dem Passwort. Größe und Position des zuletzt benutzten Fensters werden gespeichert und für neu geöffnete Dokumente übernommen, auch nach einem Neustart.

## Symbolleiste

Wie in Vorschau steht die aktuelle Seite unter dem Dokumentnamen („Seite 3 von 18“). Die Symbolleiste zeigt drei Gruppen: Blättern (˄ ˅), Anzeige (Anzeigemodus, geteilte Ansicht) und Zoom (verkleinern, Zoomstufe mit Anpassen-Optionen, vergrößern), dazu „i“ für die Dokumentinformationen und die Suche. **Gehe zu Seite …** (⌥⌘G) öffnet unter den Blätterknöpfen ein Feld für die Seitenzahl.

## Seitenleiste

Die Seitenleiste zeigt wahlweise die **Gliederung** oder **Miniaturen** aller Seiten; umschalten lässt sich mit dem Umschalter oben in der Seitenleiste oder über das Menü „Darstellung“. In den Miniaturen ist die aktuelle Seite markiert, ein Klick springt zur Seite. In einer geteilten Ansicht gehört die Seitenleiste zur aktiven Ansicht.

## Suche

Die Fundstellen erscheinen in einer eigenen Seitenleiste rechts, mit Textausschnitt und Seitenzahl; ein Klick springt zur Stelle. Die Leiste lässt sich mit ⌥⌘F aus- und wieder einblenden und verschwindet, wenn das Suchfeld geleert wird. Die linke Seitenleiste zeigt dabei weiter Gliederung oder Miniaturen.

## Geteilte Ansicht

Mit **Darstellung → Ansicht teilen** (⌃⌘T) oder dem Knopf in der Symbolleiste zeigt das Fenster das Dokument zweimal, nebeneinander oder untereinander (umschaltbar im Menü „Darstellung“). Jede Hälfte hat eigene Position, eigenen Zoom und eigenen Anzeigemodus; den Trenner kann man verschieben.

Über **Anderes Dokument …** in der Kopfzeile der zweiten Ansicht (oder **Darstellung → Anderes Dokument in zweiter Ansicht öffnen …**) lässt sich dort ein anderes PDF öffnen. Dessen Leseposition wird nicht gespeichert.

Symbolleiste, Menübefehle, Pfeiltasten, Gliederung und Suche wirken immer auf die **aktive Ansicht**: die zuletzt angeklickte, erkennbar an der farbigen Linie unter ihrer Kopfzeile.

## Trinkgeld

Das Über-Fenster bietet drei freiwillige Trinkgelder als In-App-Käufe (StoreKit 2, Verbrauchsartikel):

| Produkt-ID | Name | Preis |
|---|---|---|
| `com.stefanradermacher.leser.tip.coffee` | Ein Kaffee ☕️ | 1,99 € |
| `com.stefanradermacher.leser.tip.breakfast` | Ein Frühstück 🥐 | 4,99 € |
| `com.stefanradermacher.leser.tip.dinner` | Ein Abendessen 🍝 | 9,99 € |

Namen und Emoji stehen in der App und folgen deshalb ihrer Sprache; aus dem App Store kommt nur der Preis, der sich nach dem Land des Kontos richtet. Anzeigename und Beschreibung aus App Store Connect zeigt Leser nicht selbst — sie erscheinen in Apples Kaufdialog und im Store-Eintrag. Angelegt werden müssen genau diese Produkte dort trotzdem, als „Verbrauchsartikel“.

Zum Testen ohne echtes Geld liegt `Config/Leser.storekit` bei; das Schema „Leser“ nutzt sie, wenn die App in Xcode mit ⌘R gestartet wird. Builds, die nicht aus dem App Store oder Xcode kommen (z. B. über `build.sh`), zeigen statt der Knöpfe einen Hinweis.

Dieselben Trinkgelder gibt es in einem eigenen kleinen Fenster über **Hilfe → Leser unterstützen …**. Das Hilfe-Menü enthält außerdem Links zur Projektseite auf GitHub und zum Melden von Fehlern und Ideen.

## Dokumentinformationen

**Ablage → Dokumentinformationen** (⌘I) zeigt Name, Ort, Größe und Datum der Datei, die im PDF gespeicherten Angaben (Titel, Autor, Thema, Stichwörter, erstellendes Programm, Daten, PDF-Version), Seitenzahl und Seitenformat, ob es eine Gliederung und durchsuchbaren Text gibt, sowie Verschlüsselung und Berechtigungen. Die Werte lassen sich markieren und kopieren; „Im Finder zeigen“ öffnet den Ordner der Datei. In einer geteilten Ansicht gelten die Angaben für das Dokument der aktiven Ansicht.

## Einstellungen

Unter **Leser → Einstellungen …** (⌘,) steht ganz oben, welche App gerade PDFs öffnet, mit einem Knopf, um Leser zur Standard-App zu machen. Das geht nur, wenn Leser im Ordner „Programme“ liegt. Außerdem lässt sich dort festlegen, wie Dokumente geöffnet werden:

- **Anzeige:** zuletzt verwendet (Standard), Fortlaufend, Einzelseite, Doppelseite oder Doppelseite (erste Seite einzeln)
- **Zoom:** Seitenbreite (Standard), Seitenhöhe, Ganze Seite oder Originalgröße
- **Seitenleiste anzeigen:** wenn das Dokument eine Gliederung hat (Standard), immer oder nie
- **Seitenleiste zeigt:** Gliederung, bei Dokumenten ohne Gliederung Miniaturen (Standard), oder immer Miniaturen
- **Neue Dokumente öffnen:** wie in den Systemeinstellungen (Standard), als Tab oder in einem neuen Fenster
- **Dokument neu laden, wenn sich die Datei ändert:** Standard: an. Seite, Zoom, Anzeige und eine laufende Suche bleiben erhalten; das gilt auch für ein zweites Dokument in der geteilten Ansicht.
- **Tableiste auch bei nur einem Dokument anzeigen:** Standard: aus. Die Leiste erscheint dann erst ab zwei Tabs.
- **An der zuletzt gelesenen Stelle weiterlesen:** merkt sich für bis zu 200 Dokumente die letzte Position (Standard: an). Beim Ausschalten werden die gespeicherten Stellen gelöscht.

### Nachfrage nach der Standard-App

Leser fragt selbst höchstens zweimal, ob es PDFs standardmäßig öffnen soll, und zwar mit einer schmalen Leiste oben im Dokumentfenster, nie mit einem Dialog:

- zum ersten Mal, wenn an drei verschiedenen Tagen PDFs mit Leser geöffnet wurden,
- ein zweites und letztes Mal frühestens 30 Tage und drei weitere Nutzungstage nach „Nicht jetzt“,
- nie, wenn Leser schon einmal Standard war, nicht in „Programme“ liegt oder das Dokument passwortgeschützt ist.

Die Änderung selbst bestätigt macOS mit einer eigenen Rückfrage.

## Quellcode

- `LeserApp.swift`: App, schreibgeschütztes Dokument (`DocumentGroup(viewing:)`)
- `ViewerModel.swift`: PDFView, Seiten, Zoom, Gliederung, Suche
- `ContentView.swift`: Fenster mit Split-View und Symbolleiste
- `SidebarView.swift`: Gliederung und Suchtreffer
- `ViewerCommands.swift`: Menübefehle
- `AboutView.swift`: Über-Fenster; Links (Quellcode, weitere Projekte) stehen gesammelt in `AppLinks`
- `DefaultAppOffer.swift`: Nachfrage und Einstellung zur Standard-App für PDFs
- `DocumentInfoView.swift`: Fenster mit Dokumentinformationen
- `FileWatcher.swift`: meldet Änderungen an einer Datei, auch wenn Programme sie beim Speichern ersetzen
- `MenuCleaner.swift`: entfernt Menüeinträge, die in einem reinen Betrachter keinen Sinn ergeben (Sichern, Duplizieren, Umbenennen, Bewegen, Zurücksetzen, Neu, Schreibtools, Automatisch ausfüllen, Hilfe); Widerrufen, Wiederholen, Ausschneiden, Einsetzen und Löschen sind ausgeblendet, ihre Tastenkürzel funktionieren in Such- und Seitenfeld aber weiter
- `Preferences.swift`: Einstellungen und Einstellungsfenster, gespeicherte Lesepositionen
- `SplitView.swift`: geteilte Ansicht, aktive Ansicht, zweites Dokument
- `TabBarKeeper.swift`: blendet die Tableiste bei nur einem Dokument ein oder aus
- `ToolbarSegments.swift`: Knopfgruppen der Symbolleiste (AppKit-Segmente mit Menüs, wie in Vorschau)
- `TipJar.swift`: Trinkgeldkasse (StoreKit 2)
- `WindowFrameKeeper.swift`: merkt sich Fenstergröße und -position
