<!--
Texte des Handbuchs. Daraus erzeugt `swift scripts/make_manual.swift` das PDF
(mit „en“ die englische Fassung).

Oben stehen die Angaben für Titelseite und Dokumentinformationen, danach der Inhalt:
  # Kapitel             beginnt eine neue Seite und einen Eintrag in der Gliederung
  ## Überschrift        Zwischenüberschrift
  Text                  Absatz; Zeilenumbrüche sind egal, eine Leerzeile trennt Absätze
                        (das gilt auch für die Angaben oben)
  - Punkt               Aufzählungspunkt
  > Hinweis             Text im farbigen Kasten
  ![Text](Pfad)         Bildschirmfoto über die ganze Breite, darunter der Text;
                        fehlt die Datei, wird es ausgelassen
  | Befehl | Kürzel |   Zeile der Tastaturkürzel-Tabelle
  {Name}                die Seite des Kapitels oder der Überschrift dieses Namens,
                        etwa „siehe Seite {Suchen}“
-->

Dokumenttitel: Leser – Handbuch
Thema: PDF-Betrachter für macOS
Untertitel: Handbuch zum PDF-Betrachter für macOS
Leitsatz: Gemacht zum Lesen.
Einleitung: Aufgeräumt, schnell und ohne Ablenkung: mit Gliederung, Lesezeichen, Volltextsuche und geteilter Ansicht.
Kostenlos, werbefrei und ohne Datensammlung.

# Über dieses Handbuch

Leser ist ein PDF-Betrachter für macOS, gemacht zum Lesen. Dieses Handbuch beschreibt in wenigen Kapiteln, was Leser kann und wie es sich bedienen lässt.

Es ist zugleich ein Beispieldokument: mehrere Kapitel mit Gliederung, damit sich die Seitenleiste, die Suche und die geteilte Ansicht daran ausprobieren lassen. Auch die Seitenangaben darin funktionieren wie Links (siehe Seite {Links und Verweise}).

## Was Leser ausmacht

- Kostenlos und quelloffen unter der Apache-Lizenz 2.0
- Keine Werbung, kein Tracking, keine Datensammlung
- Nur Apple-Frameworks, keine Fremdkomponenten
- Deutsch und Englisch

# Lesen und Navigieren

Ein Dokument öffnest du per Doppelklick, über „Ablage → Öffnen …“ oder indem du es auf das Symbol im Dock ziehst. Leser merkt sich, an welcher Stelle du zuletzt warst, und öffnet das Dokument beim nächsten Mal genau dort.

![Die Gliederung in der Seitenleiste, rechts die ganze Seite](docs/screenshots/1-dokument.png)

## Blättern

Mit den Pfeiltasten nach links und rechts blätterst du seitenweise, mit den Tasten nach oben und unten sowie mit dem Trackpad scrollst du fortlaufend. Über „Gehe zu Seite …“ springst du direkt zu einer Seitenzahl; die aktuelle Seite steht immer als Untertitel im Fenster.

## Die Seitenleiste

Links zeigt Leser wahlweise die Gliederung des Dokuments oder Miniaturen aller Seiten. Beides lässt sich mit einem Klick umschalten. In der Gliederung folgt die Markierung deiner Leseposition, sodass du jederzeit siehst, in welchem Kapitel du bist.

- Gliederung: springt zu Kapiteln und Abschnitten
- Miniaturen: zeigt alle Seiten und die aktuelle Seite hervorgehoben

## Zoom

Der Zoom lässt sich in Stufen ändern oder an die Seitenbreite, die Seitenhöhe oder die ganze Seite anpassen. Die gewählte Anpassung bleibt erhalten, auch wenn du das Fenster größer oder kleiner ziehst.

## Zurück und vor

Nach einem Sprung, etwa über einen Link, die Gliederung oder „Gehe zu Seite …“, bringt dich „Gehe zu → Zurück“ wieder an die Stelle davor, „Vorwärts“ wieder hin. Mit einer Maus geht das auch über die Seitentasten, mit einem Trackpad oder einer Magic Mouse über eine Wischbewegung.

## Tabs und Fenster

Mehrere Dokumente öffnet Leser wahlweise als Tabs in einem Fenster oder in eigenen Fenstern, je nachdem, was in den Einstellungen steht. Größe und Position des zuletzt benutzten Fensters merkt sich Leser, sodass neue Dokumente gleich passend aufgehen.

# Lesezeichen

Lesezeichen merken sich Stellen, zu denen du zurückkehren willst. Sie stehen in einem eigenen Bereich über der Gliederung und im Menü „Lesezeichen“, jeweils mit ihrer Seitenzahl.

## Ein Lesezeichen setzen

„Lesezeichen → Lesezeichen hinzufügen …“ merkt sich die Stelle, die gerade oben im Fenster steht. Mit einem Rechtsklick in die Seite setzt du es genau an diese Stelle, mit einem Rechtsklick auf einen Eintrag der Gliederung an dessen Kapitel. Als Name schlägt Leser die Überschrift der Stelle vor; du kannst ihn übernehmen, aus weiteren Vorschlägen wählen oder selbst einen eingeben.

## Ordnen und umbenennen

Ein Doppelklick oder die Eingabetaste benennt ein Lesezeichen um, die Rückschritttaste löscht es. Beides geht auch über das Kontextmenü. Die Trennlinie zur Gliederung lässt sich verschieben; ein Doppelklick darauf passt die Höhe wieder dem Inhalt an.

> Lesezeichen hängen am Dokument, nicht am Dateinamen. Sie bleiben erhalten, wenn du die Datei umbenennst oder verschiebst.

# Links und Verweise

Ruht der Mauszeiger auf einem Link, zeigt Leser nach einem kurzen Moment, wohin er führt, ohne dass du die Seite verlässt. Ein Klick springt hin, „Zurück“ wieder zur Stelle davor.

![Die Vorschau einer Seitenangabe, ohne die Seite zu verlassen](docs/screenshots/3-vorschau.png)

## Seitenangaben im Text

Auch Angaben wie „siehe Seite {Lesezeichen}“ oder „(Seite {Suchen})“ verhalten sich wie Links, selbst wenn das Dokument sie nicht als Link enthält. Leser erkennt sie im Text und zeigt beim Darauf-Zeigen dieselbe Vorschau.

## Verweise auf andere Dokumente

Nennt ein Text eine Seite in einem anderen Dokument, etwa „(Atlas der Sterne, S. 42)“, öffnet ein Klick darauf dieses Dokument an der genannten Seite. Beim ersten Mal fragt Leser, welche Datei zu dem Titel gehört, und merkt sich die Antwort für alle Dokumente. Links in andere Dateien funktionieren genauso.

Ob das andere Dokument in einem neuen Tab oder in der zweiten Ansicht aufgeht, legst du in den Einstellungen unter „Verweise“ fest. Dort stehen auch alle zugeordneten Dokumente; du kannst sie im Finder zeigen, einer anderen Datei zuordnen oder die Zuordnung entfernen.

# Suchen

Die Suche findet Wörter im gesamten Dokument. Die Fundstellen erscheinen in einer eigenen Seitenleiste rechts, jeweils mit einem Textausschnitt und der Seitenzahl. Ein Klick darauf springt zur Stelle, und alle Treffer sind im Dokument farbig hervorgehoben.

![Die Suche nach „Leser“ mit der Trefferliste rechts](docs/screenshots/2-suche.png)

## Von Treffer zu Treffer

Mit der Eingabetaste oder mit „Weitersuchen“ wanderst du durch die Fundstellen, rückwärts geht es ebenso. Die Suche beginnt auf der Seite, auf der du gerade bist; das lässt sich in den Einstellungen ändern. Leser achtet dabei weder auf Groß- und Kleinschreibung noch auf Akzente, sodass auch „Ubergrosse“ die Stelle „Übergröße“ findet.

> Findet die Suche nichts, obwohl der Text sichtbar ist, enthält das Dokument vermutlich nur Bilder, etwa bei einem Scan ohne Texterkennung. Unter „Dokumentinformationen“ steht dann bei „Durchsuchbarer Text“ ein Nein.

## Wonach sich suchen lässt

Gesucht wird im Text des Dokuments, nicht in den Namen der Kapitel. Ein Dokument, das aus Bildern besteht, lässt sich daher nicht durchsuchen, ein aus einem Satzprogramm erzeugtes PDF dagegen vollständig.

# Zwei Stellen gleichzeitig

Mit der geteilten Ansicht zeigt Leser dasselbe Dokument zweimal, nebeneinander oder untereinander. So lassen sich eine Tabelle und ihre Erläuterung, ein Vertragstext und seine Anlage oder zwei weit auseinanderliegende Kapitel zusammen lesen.

![Zwei Kapitel nebeneinander in der geteilten Ansicht](docs/screenshots/4-geteilt.png)

## Zwei Dokumente

In der zweiten Hälfte kannst du auch ein anderes PDF öffnen, etwa um zwei Fassungen zu vergleichen. Jede Hälfte hat ihre eigene Position, ihren eigenen Zoom und ihren eigenen Anzeigemodus.

## Die aktive Hälfte

Symbolleiste, Menübefehle, Seitenleiste und Suche wirken immer auf die zuletzt angeklickte Hälfte. Welche das ist, zeigt eine farbige Linie unter ihrer Kopfzeile.

## Wieder schließen

Ein Klick auf das Kreuz in der Kopfzeile der zweiten Hälfte beendet die geteilte Ansicht, ebenso der Knopf in der Symbolleiste oder der Menübefehl. Das Hauptdokument bleibt dabei an seiner Stelle. Schließt du ein Dokument mit geteilter Ansicht, öffnet Leser es beim nächsten Mal wieder geteilt, mit beiden Hälften an ihrer Stelle, sofern „An der zuletzt gelesenen Stelle weiterlesen“ eingeschaltet ist. Das gilt, wenn beide Hälften dasselbe Dokument zeigen.

# Anzeige und Einstellungen

Leser kennt vier Arten, Seiten anzuordnen: fortlaufend, einzeln, als Doppelseite oder als Doppelseite mit einzelner erster Seite, wie bei einem Buch mit Titelseite.

## Was beim Öffnen gilt

In den Einstellungen legst du unter „Darstellung“ fest, womit ein Dokument aufgeht: mit welcher Anzeige, welchem Zoom und ob die Seitenleiste erscheint. Unter „Allgemein“ steht, ob neue Dokumente als Tab oder in einem eigenen Fenster öffnen.

## Sepia

„Darstellung → Sepia“ tönt die Seiten wie warmes Papier, angenehmer für langes Lesen. Drucken und Kopieren bleiben davon unberührt.

## Automatisch neu laden

Ändert ein anderes Programm die Datei, etwa beim Export aus einem Satzprogramm oder beim Übersetzen eines LaTeX-Dokuments, zeigt Leser die neue Fassung von selbst an. Seite, Zoom und Anzeige bleiben dabei erhalten.

## Drucken

Im Druckdialog hat Leser einen eigenen Bereich: Seiten lassen sich in Originalgröße drucken, große Seiten verkleinern oder alle auf das Papierformat skalieren, und auf Wunsch dreht Leser quer liegende Seiten passend.

## Standard-App

Soll Leser PDFs immer öffnen, genügt ein Klick in den Einstellungen. Die Umstellung bestätigt macOS anschließend selbst, damit sie nie unbemerkt geschieht.

# Fragen und Antworten

## Kann ich mit Leser PDFs bearbeiten?

Nein. Leser ist ein reiner Betrachter. Für Anmerkungen, Formulare oder das Zusammenfügen von Dokumenten eignen sich andere Programme, etwa Vorschau.

## Warum fehlt die Gliederung?

Weil das Dokument keine enthält. Viele PDFs aus Textverarbeitungen bringen keine mit. In diesem Fall zeigt Leser Miniaturen der Seiten an.

## Kann ich Text kopieren?

Ja. Text lässt sich wie gewohnt mit der Maus markieren und kopieren, sofern das Dokument es erlaubt. Ob das so ist, steht unter „Dokumentinformationen“. Leser fügt die Zeilen dabei wieder zu Absätzen zusammen und behält Fett und Kursiv; weiße Schrift wird schwarz, damit sie auf weißem Grund lesbar bleibt.

## Was passiert mit meinen Dokumenten?

Nichts, außer dass sie angezeigt werden. Leser schreibt nie in ein Dokument und lädt nichts hoch.

# Tastaturkürzel

Die wichtigsten Befehle lassen sich ohne Maus erreichen:

| Suchen, Weitersuchen, Rückwärts | ⌘F, ⌘G, ⇧⌘G |
| Suchergebnisse ein- und ausblenden | ⌥⌘F |
| Seitenleiste ein- und ausblenden | ⌃⌘S |
| Gliederung, Miniaturen | ⌃⌘1, ⌃⌘2 |
| Vergrößern, Verkleinern, Originalgröße | ⌘+, ⌘-, ⌘0 |
| Seitenbreite, Seitenhöhe, Ganze Seite | ⌘1, ⌘2, ⌘3 |
| Vorherige und nächste Seite | ← und → |
| Erste und letzte Seite | Pos1, Ende |
| Zurück, Vorwärts | ⌘Ö, ⌘Ä |
| Gehe zu Seite | ⌥⌘G |
| Lesezeichen hinzufügen | ⌘D |
| Lesezeichen ein- und ausblenden | ⌃⌘3 |
| Ansicht teilen | ⌃⌘T |
| Dokumentinformationen | ⌘I |
| Drucken | ⌘P |

# Datenschutz

Leser übermittelt keine Daten. Es gibt kein Tracking, keine Analyse und keine Werbung, und die App baut selbst keine Verbindung ins Internet auf; nur ein freiwilliges Trinkgeld läuft über den App Store. Deine Dokumente werden ausschließlich auf deinem Mac gelesen und angezeigt.

## Was lokal gespeichert wird

- Deine Einstellungen
- Größe und Position des zuletzt benutzten Fensters
- Die zuletzt gelesene Stelle für bis zu 200 Dokumente
- Deine Lesezeichen
- Welche Datei zu welchem Titel gehört, für Verweise auf andere Dokumente

Diese Angaben verlassen deinen Mac nicht. Die gespeicherten Stellen lassen sich in den Einstellungen mit einem Schalter wieder löschen, die Zuordnungen unter „Verweise“ einzeln.

> Wer möchte, kann die Weiterentwicklung mit einem freiwilligen Trinkgeld unterstützen. Es schaltet nichts frei: Leser bleibt vollständig kostenlos.
