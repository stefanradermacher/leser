# Leser

PDF-Betrachter für macOS 15+, gemacht zum Lesen und gebaut mit SwiftUI und PDFKit. Er kann nur anzeigen, nichts bearbeiten.

Leser ist kostenlos, quelloffen (Apache-Lizenz 2.0, siehe `LICENSE`), werbefrei und übermittelt keine Daten: kein Tracking, keine Analyse, keine eigenen Netzwerkverbindungen. Es nutzt ausschließlich Apple-Frameworks. Wer die Entwicklung unterstützen möchte, kann unter **Leser → Über Leser** ein freiwilliges Trinkgeld über den App Store geben; es schaltet nichts frei.

Nicht Teil des lizenzierten Werks sind die Kennzeichen des Projekts: der Name „Leser“, das App- und das Dokumentsymbol, die Monogramme und `scripts/make_icon.swift`, das die Symbole zeichnet. Was damit erlaubt ist, steht in `TRADEMARKS.md` — kurz gesagt: über Leser reden und die unveränderte App weitergeben ja, eine Abspaltung unter diesem Namen nein. `NOTICE` hält den Umfang fest und ist nach Abschnitt 4(d) der Lizenz bei jeder Weitergabe mitzuführen. Der Code selbst bleibt frei verwendbar.

Für die Veröffentlichung im Mac App Store liegen unter `docs/` die vorbereiteten Texte (`app-store.md`), die Datenschutzerklärung (`datenschutz.md`), die Support-Seite (`support.md`) und die Screenshots. Was sich von Version zu Version geändert hat, steht in `CHANGELOG.md` (englisch: `CHANGELOG.en.md`).

Die Oberfläche gibt es auf Deutsch und Englisch. Die Texte liegen im String-Katalog `Resources/Localizable.xcstrings`; die Schlüssel sind die deutschen Sätze. Neue Texte holt man mit `xcodebuild -exportLocalizations -project Leser.xcodeproj -localizationPath <Ordner> -exportLanguage en` heraus und trägt die Übersetzung im Katalog nach.

## Bauen

Leser ist ein Xcode-Projekt (`Leser.xcodeproj`, Xcode 27 oder neuer, macOS 15+). In Xcode öffnen und mit ⌘R starten; für einen signierten Build unter „Signing & Capabilities“ das eigene Team eintragen.

Ohne Xcode-Oberfläche:

```
./build.sh
```

Das baut `build/Leser.app` mit `xcodebuild` (mit derselben Sandbox wie im App Store) und installiert die App nach `/Applications`. Läuft Leser gerade, wird es vorher beendet und danach wieder geöffnet. Stammt die installierte App aus dem App Store, lässt `build.sh` sie unangetastet und meldet nur den Build. Nur bauen, ohne zu installieren: `./build.sh --no-install`.

Nennt `Config/Local.xcconfig` eine Team-ID, signiert `build.sh` mit diesem Team wie beim Archiv für den App Store; Xcode legt das Entwicklungsprofil bei Bedarf an. Ohne Team-ID, oder mit `--adhoc`, signiert es ad hoc und braucht kein Entwicklerkonto.

Die Versionsnummer (z. B. 1.0) steht im Projekt unter „Version“ (`MARKETING_VERSION`) und wird von Hand erhöht. Die Build-Nummer in Klammern steht als `CURRENT_PROJECT_VERSION` in `Config/Leser.xcconfig` und ist damit eingecheckter Zustand: Xcode und `build.sh` lesen dieselbe Zahl, sie kann nicht sinken, und im Verlauf sieht man, welcher Commit welchen Build ergeben hat.

**Vor jedem Upload in den App Store einmal `./scripts/bump-build.sh` ausführen und mitcommitten** — App Store Connect verlangt für jeden Upload eine höhere Nummer als für den vorigen. Die eingereichten Stände tragen Tags wie `v1.0-build26`.

Nachträglich lässt sich die Nummer nicht setzen: `CFBundleVersion` wird beim Verarbeiten der `Info.plist` eingesetzt, und ein Skript, das die fertige Plist im Produkt ändert, wird von Xcode danach wieder überschrieben.

Das App-Icon und das Dokumentsymbol werden von `scripts/make_icon.swift` gezeichnet: das App-Icon in den Asset-Katalog, das Dokumentsymbol nach `Resources/PDFDocument.icns`. Nach Änderungen an der Zeichnung im Projektordner `swift scripts/make_icon.swift` ausführen. Das Dokumentsymbol zeigt macOS nur, wenn Leser die Standard-App für PDFs ist, und auch dann meist nur dort, wo es keine Seitenvorschau gibt.

`scripts/make_manual.swift` zeichnet `docs/Leser-Handbuch.pdf`, ein dreizehnseitiges Handbuch mit Gliederung und vier Bildschirmfotos aus `docs/screenshots/`. Es erklärt die Bedienung, dient zugleich als Beispieldokument und ist in den Screenshots für den App Store zu sehen – die Bildschirmfotos im Handbuch zeigen also das Handbuch selbst. Die Texte stehen in `docs/handbuch/de.md` und `docs/handbuch/en.md`, das Format ist oben in den Dateien beschrieben. Nach Änderungen im Projektordner `swift scripts/make_manual.swift` ausführen; `swift scripts/make_manual.swift en` schreibt die englische Fassung nach `docs/Leser-Manual.pdf`. Beide Fassungen kopiert das Skript außerdem nach `Resources/`: Sie liegen im App-Bundle, und „Hilfe → Leser-Handbuch“ öffnet die zur App-Sprache passende direkt in Leser, offline und immer zur installierten Version passend.

### Projektstruktur

- `Sources/Leser/`: Quellcode; neue Dateien gehören automatisch zum Projekt
- `Resources/`: Asset-Katalog mit App-Icon, Monogramme, Lokalisierung, `PrivacyInfo.xcprivacy`
- `Config/Info.plist`, `Config/Leser.entitlements`: App-Einstellungen und Sandbox-Berechtigungen (nur Lesezugriff auf selbst gewählte Dateien, das Merken solcher Dateien für Verweise auf andere Dokumente, und Drucken)
- `Config/Leser.xcconfig`: Build-Einstellungen; bindet optional `Config/Local.xcconfig` ein
- `Tests/LeserTests/`: Unit-Tests; neue Dateien gehören automatisch zum Test-Target
- `testdata/`: Dokumente zum Ausprobieren von Hand, darunter zwei mit Links zwischen den Dateien (`swift scripts/make_link_tests.swift`)

### Tests

```
./test.sh
```

Das führt die Unit-Tests aus (Swift Testing). Sie laufen im Debug-Build von Leser, der eigene Einstellungen hat, und lassen die der installierten App unberührt. Die PDFs, die sie brauchen, erzeugen sie selbst, mit genau dem Text, den Seitenbeschriftungen, Links und Kennungen, um die es im Test geht. Einzelne Gruppen oder Tests: `./test.sh PageReferenceTests` oder `./test.sh PageReferenceTests/pageLabelsDecide()`. Das vollständige Protokoll steht in `.build/test.log`.

Geprüft werden vor allem die Teile mit eigener Logik: Seitenangaben und Verweise auf andere Dokumente, Kopieren mit Absätzen, Dokumentkennung, Lesestellen, Lesezeichen, Zuordnungen und Links in andere Dateien, Navigation, Suche, Drucken, die Teilung der Seitenleiste, die Dateiüberwachung beim Neuladen und die Nachfrage nach der Standard-App.

Zum Signieren mit eigenem Entwicklerkonto `Config/Local.xcconfig.example` nach `Config/Local.xcconfig` kopieren und die eigene Team-ID eintragen. Die Datei bleibt lokal. Ohne sie baut Xcode ohne Team, und `./build.sh` signiert ad hoc.

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
| Erste / letzte Seite | Pos1 / Ende oder ⌥⌘Pos1 / ⌥⌘Ende |
| Zurück / Vorwärts (nach einem Sprung) | ⌘[ / ⌘], Seitentasten der Maus oder Wischen |
| Gehe zu Seite … | ⌥⌘G |
| Lesezeichen hinzufügen | ⌘D |
| Lesezeichen ein-/ausblenden | ⌃⌘3 |
| Ansicht teilen / geteilte Ansicht schließen | ⌃⌘T |
| Dokumentinformationen | ⌘I |
| Drucken / Papierformat | ⌘P / ⇧⌘P |
| Text kopieren | markieren, ⌘C |

Die Anzeige (Fortlaufend, Einzelseite, Doppelseite) lässt sich über das Menü „Darstellung“ oder das Symbol in der Symbolleiste wählen; welche beim Öffnen gilt, steht in den Einstellungen. Die Einstellungen „Seitenbreite“, „Seitenhöhe“ und „Ganze Seite“ bleiben beim Ändern der Fenstergröße erhalten. Zoomen mit zwei Fingern auf dem Trackpad funktioniert ebenfalls. Passwortgeschützte PDFs fragen beim Öffnen nach dem Passwort. Größe und Position des zuletzt benutzten Fensters werden gespeichert und für neu geöffnete Dokumente übernommen, auch nach einem Neustart.

## Symbolleiste

Unter dem Dokumentnamen steht die Position im Dokument („3 von 18“). Die Symbolleiste zeigt drei Gruppen: Blättern (˄, Seitenbezeichnung, ˅), Anzeige (Anzeigemodus, geteilte Ansicht) und Zoom (verkleinern, Zoomstufe mit Anpassen-Optionen, vergrößern), dazu die Suche. Zwischen den Blätterpfeilen steht die Seitenbezeichnung, wie sie das PDF festlegt, etwa „xi“ oder „12“, sonst die Seitenzahl. Ein Klick darauf oder **Gehe zu Seite …** (⌥⌘G) öffnet ein Feld, das Seitenbezeichnungen wie Seitenzahlen versteht.

## Seitenleiste

Die Seitenleiste zeigt wahlweise die **Gliederung** oder **Miniaturen** aller Seiten; umschalten lässt sich mit dem Umschalter oben in der Seitenleiste oder über das Menü „Darstellung“. In den Miniaturen ist die aktuelle Seite markiert, ein Klick springt zur Seite. Hat ein Dokument Lesezeichen, stehen sie in einem eigenen Bereich darüber. In einer geteilten Ansicht gehört die Seitenleiste zur aktiven Ansicht.

## Lesezeichen

Lesezeichen merken sich Stellen in einem Dokument. Gespeichert werden sie in Leser, nicht im PDF. **Lesezeichen → Lesezeichen hinzufügen …** (⌘D) nimmt die Stelle oben im Fenster, ein Rechtsklick in die Seite genau diese Stelle; ein kleines Fenster schlägt als Namen die Gliederungsüberschrift der Stelle vor, die anderen Einträge der Seite und die Seitenbezeichnung stehen zur Auswahl. Über das Kontextmenü der Gliederung entsteht ein Lesezeichen direkt mit dem Namen des Eintrags.

Die Lesezeichen stehen in einem Bereich über der Gliederung und im Menü „Lesezeichen“, nach ihrer Stelle im Dokument geordnet. Umbenennen per Doppelklick, ↩ oder Kontextmenü, löschen per ⌫ oder Kontextmenü. Der Bereich passt seine Höhe den Lesezeichen an; zieht man die Trennlinie, merkt sich Leser die Höhe für das Dokument, und ein Doppelklick auf die Linie oder **Darstellung → Lesezeichen-Bereich automatisch anpassen** stellt die Anpassung wieder her. **Darstellung → Lesezeichen** (⌃⌘3) blendet den Bereich aus und ein.

Lesestelle und Lesezeichen hängen an der Kennung, die das erzeugende Programm ins PDF schreibt, nicht am Dateipfad: Umbenennen und Verschieben übersteht beides, und eine Kopie öffnet an derselben Stelle. PDFs ohne Kennung erkennt Leser an einer Prüfsumme ihres Inhalts.

## Links und Verweise

Ruht der Mauszeiger kurz auf einem Link ins selbe Dokument, zeigt ein kleines Fenster die Zielstelle, ohne dass man die Seite verlässt.

**Seitenangaben** im Text wie „siehe Seite 12“, „(Seite 7)“ oder „on page 359“ behandelt Leser wie Links, mit derselben Vorschau und einem Sprung bei Klick. Gezählt wird nach den Seitenbezeichnungen des PDFs; hat es keine, nach der Position, aber nur, wenn die Zielseite die Zahl auch gedruckt trägt. Leser nimmt lieber eine Angabe nicht, als falsch zu springen: Steht ein fremder Titel davor oder danach, ist es kein Verweis ins eigene Dokument.

**Verweise auf andere Dokumente** wie „(Atlas der Sterne, S. 42)“ oder ein kursiver Titel mit Seitenzahl öffnen das genannte Dokument an der Seite, je nach Einstellung in einem neuen Tab oder in der zweiten Ansicht. Beim ersten Klick fragt Leser, welche Datei zu dem Titel gehört, und merkt sie sich mit einem Security-Scoped Bookmark für alle Dokumente; danach zeigt auch hier die Vorschau die Zielseite. Echte PDF-Links in andere Dateien laufen genauso, mit dem Dateinamen als Titel. Ist das Dokument schon offen, springt Leser dort hin.

Nach jedem Sprung führt **Gehe zu → Zurück** (⌘[) zurück, ebenso die Seitentasten einer Maus oder eine Wischbewegung.

## Kopieren und Drucken

Kopierter Text kommt in Absätzen an: Leser fügt die Zeilen wieder zusammen, wo das Layout es nahelegt, und setzt am Zeilenende getrennte Wörter wieder zusammen, auch über Spalten hinweg. Fett und Kursiv bleiben erhalten (als RTF), weiße Schrift wird schwarz.

Der Druckdialog hat einen eigenen Abschnitt „Leser“: Originalgröße (Standard), Große Seiten verkleinern oder Auf Papierformat skalieren, dazu das automatische Drehen quer liegender Seiten. Leser merkt sich die Wahl für den nächsten Druck.

**Darstellung → Sepia** tönt die Seiten wie warmes Papier; Drucken und Kopieren bleiben davon unberührt.

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

Dieselben Trinkgelder gibt es in einem eigenen kleinen Fenster über **Hilfe → Leser unterstützen …**. Das Hilfe-Menü enthält außerdem das Handbuch (**Hilfe → Leser-Handbuch**, zur App-Sprache passend und offline) und Links zur Projektseite auf GitHub und zum Melden von Fehlern und Ideen.

## Dokumentinformationen

**Ablage → Dokumentinformationen** (⌘I) zeigt Name, Ort, Größe und Datum der Datei, die im PDF gespeicherten Angaben (Titel, Autor, Thema, Stichwörter, erstellendes Programm, Daten, PDF-Version), Seitenzahl und Seitenformat, ob es eine Gliederung und durchsuchbaren Text gibt, sowie Verschlüsselung und Berechtigungen. Die Werte lassen sich markieren und kopieren; „Im Finder zeigen“ öffnet den Ordner der Datei. In einer geteilten Ansicht gelten die Angaben für das Dokument der aktiven Ansicht.

## Einstellungen

Die Einstellungen (**Leser → Einstellungen …**, ⌘,) sind in drei Tabs geteilt.

**Allgemein**

- **Standard-App für PDF-Dokumente:** welche App gerade PDFs öffnet, mit einem Knopf, um Leser dazu zu machen. Das geht nur, wenn Leser im Ordner „Programme“ liegt.
- **Neue Dokumente öffnen:** wie in den Systemeinstellungen (Standard), als Tab oder in einem neuen Fenster
- **Tableiste auch bei nur einem Dokument anzeigen:** Standard: aus. Die Leiste erscheint dann erst ab zwei Tabs.
- **An der zuletzt gelesenen Stelle weiterlesen:** merkt sich für bis zu 200 Dokumente die letzte Position (Standard: an), auch eine geteilte Ansicht desselben Dokuments mit Anordnung, Position der zweiten Hälfte und aktiver Hälfte. Zeigte die zweite Hälfte ein anderes Dokument, öffnet Leser wieder ungeteilt: Die Sandbox erlaubt nicht, eine andere Datei ohne erneute Auswahl zu öffnen. Beim Ausschalten werden die gespeicherten Stellen gelöscht.
- **Dokument neu laden, wenn sich die Datei ändert:** Standard: an. Seite, Zoom, Anzeige und eine laufende Suche bleiben erhalten; das gilt auch für ein zweites Dokument in der geteilten Ansicht.
- **Suche auf der aktuellen Seite beginnen:** Standard: an. Der erste gezeigte Treffer liegt auf der aktuellen Seite oder danach; ausgeschaltet beginnt die Suche am Anfang.

**Darstellung**

- **Anzeige:** zuletzt verwendet (Standard), Fortlaufend, Einzelseite, Doppelseite oder Doppelseite (erste Seite einzeln)
- **Zoom:** Seitenbreite (Standard), Seitenhöhe, Ganze Seite oder Originalgröße
- **Seitenleiste anzeigen:** wenn das Dokument eine Gliederung hat (Standard), immer oder nie
- **Seitenleiste zeigt:** Gliederung, bei Dokumenten ohne Gliederung Miniaturen (Standard), oder immer Miniaturen
- **Seiten in Sepia anzeigen:** Standard: aus

**Verweise**

- **Dokumente öffnen:** in einem neuen Tab (Standard) oder in der zweiten Ansicht, für Verweise und Links in andere Dokumente
- **Zugeordnete Dokumente:** jeder Titel mit seiner Datei; der volle Pfad erscheint, wenn der Mauszeiger auf dem Dateinamen ruht. Die Lupe zeigt die Datei im Finder, das Menü daneben ordnet eine andere Datei zu oder entfernt die Zuordnung.

### Nachfrage nach der Standard-App

Leser fragt selbst höchstens zweimal, ob es PDFs standardmäßig öffnen soll, und zwar mit einer schmalen Leiste oben im Dokumentfenster, nie mit einem Dialog:

- zum ersten Mal, wenn an drei verschiedenen Tagen PDFs mit Leser geöffnet wurden,
- ein zweites und letztes Mal frühestens 30 Tage und drei weitere Nutzungstage nach „Nicht jetzt“,
- nie, wenn Leser schon einmal Standard war, nicht in „Programme“ liegt oder das Dokument passwortgeschützt ist.

Die Änderung selbst bestätigt macOS mit einer eigenen Rückfrage.

## Quellcode

- `LeserApp.swift`: App, schreibgeschütztes Dokument (`DocumentGroup(viewing:)`)
- `ViewerModel.swift`: PDFView, Seiten, Zoom, Gliederung, Suche, Lesestelle; `ReaderPDFView` mit Kopieren, Kontextmenü und Klicks auf Verweise
- `ContentView.swift`: Fenster mit Split-View und Symbolleiste
- `SidebarView.swift`: Gliederung, Miniaturen, Lesezeichen-Bereich, Suchtreffer
- `SplitView.swift`: geteilte Ansicht, aktive Ansicht, zweites Dokument; `SplitContainer` für die Teilung mit AppKit
- `ViewerCommands.swift`: Menübefehle
- `Bookmarks.swift`: Lesezeichen, ihre Liste in der Seitenleiste und das Fenster zum Anlegen
- `DocumentKey.swift`: erkennt ein Dokument an seiner Kennung statt am Pfad, für Lesestelle und Lesezeichen
- `DocumentSearch.swift`: hält die Suchen zweier Ansichten desselben Dokuments auseinander
- `LinkPreview.swift`: Vorschau beim Zeigen auf Links und Verweise
- `PageReferences.swift`: findet Seitenangaben und Verweise auf andere Dokumente im Text
- `OtherDocuments.swift`: Zuordnung von Titeln zu Dateien, Öffnen in Tab oder zweiter Ansicht, Links in andere Dateien, Einstellungen „Verweise“
- `ParagraphText.swift`: fügt kopierte Zeilen wieder zu Absätzen zusammen
- `PrintOptions.swift`: Abschnitt „Leser“ im Druckdialog
- `PageTone.swift`: Sepia-Ton der Seiten
- `AboutView.swift`: Über-Fenster; Links (Quellcode, weitere Projekte) stehen gesammelt in `AppLinks`
- `TipJar.swift`: Trinkgelder mit StoreKit 2
- `DefaultAppOffer.swift`: Nachfrage und Einstellung zur Standard-App für PDFs
- `DocumentInfoView.swift`: Fenster mit Dokumentinformationen
- `FileWatcher.swift`: meldet Änderungen an einer Datei, auch wenn Programme sie beim Speichern ersetzen
- `LockedChangeBanner.swift`: Leiste für eine geänderte Datei, die wieder ihr Passwort braucht
- `MenuCleaner.swift`: entfernt Menüeinträge, die in einem reinen Betrachter keinen Sinn ergeben (Sichern, Duplizieren, Umbenennen, Bewegen, Zurücksetzen, Neu, Schreibtools, Automatisch ausfüllen, Hilfe); Widerrufen, Wiederholen, Ausschneiden, Einsetzen und Löschen sind ausgeblendet, ihre Tastenkürzel funktionieren in Such- und Seitenfeld aber weiter
- `Preferences.swift`: Einstellungen und Einstellungsfenster, gespeicherte Lesepositionen
- `TabBarKeeper.swift`: blendet die Tableiste bei nur einem Dokument ein oder aus
- `ToolbarSegments.swift`: Knopfgruppen der Symbolleiste (AppKit-Segmente mit Menüs, wie in Vorschau)
- `WindowFrameKeeper.swift`: merkt sich Größe und Position des Fensters und versetzt neue Fenster
