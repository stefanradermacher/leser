# Änderungen

Was sich in Leser von Version zu Version geändert hat. English version: [CHANGELOG.en.md](CHANGELOG.en.md).

## 1.1 – 3. Oktober 2026

### Neu

**Lesezeichen.** Leser merkt sich Stellen, zu denen du zurückkehren willst. Ein Lesezeichen setzt du mit ⌘D für die Stelle oben im Fenster, mit einem Rechtsklick genau an einer Stelle der Seite oder über einen Eintrag der Gliederung. Als Namen schlägt Leser die Überschrift der Stelle vor. Die Lesezeichen stehen in einem eigenen Bereich über der Gliederung, wo du sie auch umbenennen und löschen kannst, und im neuen Menü „Lesezeichen“. Den Bereich kannst du mit ⌃⌘3 ein- und ausblenden und seine Höhe ziehen; ein Doppelklick auf die Trennlinie passt sie wieder dem Inhalt an.

**Vorschau für Links.** Ruht der Mauszeiger kurz auf einem Link, zeigt Leser in einem kleinen Fenster, wohin er führt, ohne dass du die Seite verlässt. Ein Klick springt hin.

**Seitenangaben werden zu Links.** Angaben wie „siehe Seite 12“ oder „(page 359)“ verhalten sich wie Links, auch wenn das Dokument sie nicht als Links enthält: mit Vorschau und Sprung auf die genannte Seite. Leser zählt dabei die Seiten so, wie sie gedruckt sind.

**Verweise auf andere Dokumente.** Nennt ein Text eine Seite in einem anderen Dokument, etwa „(Atlas der Sterne, S. 42)“, öffnet ein Klick darauf dieses Dokument an der Seite, in einem neuen Tab oder in der zweiten Ansicht. Beim ersten Mal fragt Leser, welche Datei zu dem Titel gehört, und merkt sich das für alle Dokumente. Echte Links in andere PDF-Dateien funktionieren genauso. In den Einstellungen unter „Verweise“ stehen alle zugeordneten Dokumente; du kannst sie im Finder zeigen, eine andere Datei zuordnen oder die Zuordnung entfernen.

**Zurück und vor mit der Maus.** Die Seitentasten einer Maus, oder eine Wischbewegung auf dem Trackpad oder der Magic Mouse, bringen dich nach einem Sprung zurück an die Stelle davor und wieder hin.

**Sepia.** „Darstellung → Sepia“ tönt die Seiten wie warmes Papier, angenehmer für langes Lesen. Drucken und Kopieren bleiben davon unberührt.

**Handbuch in der App.** „Hilfe → Leser-Handbuch“ öffnet das Handbuch direkt in Leser, auf Deutsch oder Englisch und ohne Internetverbindung.

### Verbessert

**Kopieren.** Kopierter Text kommt in Absätzen an statt Zeile für Zeile, und am Zeilenende getrennte Wörter werden wieder zusammengesetzt. Fett und Kursiv bleiben erhalten. Weiße Schrift, etwa aus farbigen Überschriftbalken, wird schwarz, damit sie auf weißem Grund lesbar bleibt.

**Drucken.** Ein eigener Bereich im Druckdialog bietet Originalgröße, „Große Seiten verkleinern“ und „Auf Papierformat skalieren“ sowie das Drehen quer liegender Seiten. Voreingestellt ist jetzt die Originalgröße; bisher druckte Leser jede Seite etwas kleiner als andere Programme. Leser merkt sich die Wahl für den nächsten Druck.

**Seitenzahlen wie im Buch.** Zwischen den Blätterpfeilen steht die Seitenbezeichnung des Dokuments, etwa „xi“ oder „12“; ein Klick darauf öffnet „Gehe zu Seite“, das diese Bezeichnungen ebenfalls versteht. Der Untertitel des Fensters zeigt die Position im Dokument, etwa „11 von 300“.

**Suche ab der aktuellen Seite.** Die Suche zeigt zuerst den Treffer auf der Seite, auf der du gerade bist, oder danach, und erst dann die davor. Das lässt sich in den Einstellungen abschalten.

**Lesestelle und Lesezeichen hängen am Dokument.** Leser erkennt ein Dokument an seiner Kennung statt am Dateinamen. Die Lesestelle und die Lesezeichen bleiben so erhalten, wenn du die Datei umbenennst oder verschiebst, und eine Kopie öffnet an derselben Stelle. Bereits gespeicherte Lesestellen werden übernommen.

**Geteilte Ansicht beim Weiterlesen.** Schließt du ein Dokument in geteilter Ansicht, öffnet Leser es beim nächsten Mal wieder so, mit beiden Hälften an ihrer Stelle.

**Einstellungen in Tabs.** Die Einstellungen sind in „Allgemein“, „Darstellung“ und „Verweise“ aufgeteilt.

**Handbuch.** Das Handbuch beschreibt alle neuen Funktionen, und seine Seitenangaben führen die Verweise gleich vor.

### Behoben

- In der Gliederung waren Einträge mit Unterpunkten auf der obersten Ebene nicht mehr anklickbar.
- Ein Klick auf den bereits markierten Eintrag der Gliederung führte nicht zurück an den Anfang des Kapitels.
- Wurde Leser ohne Dokument gestartet und ein PDF im Öffnen-Dialog gewählt, öffnete sich das Fenster etwas versetzt.
- Ein Fenster, das den ganzen Bildschirm ausfüllt, wurde beim Öffnen eines weiteren Dokuments versetzt und dadurch abgeschnitten.

### Hinter den Kulissen

- Unit-Tests für die Teile mit eigener Logik, auszuführen mit `./test.sh`.
- Testdokumente mit Links zwischen zwei Dateien in `testdata/`.
- Ein Debug-Build mit eigener Kennung, der neben der installierten App laufen kann.

## 1.0 – 1. Oktober 2026

Erste Veröffentlichung im Mac App Store.
