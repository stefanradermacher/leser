<!--
Texte des Handbuchs. Daraus erzeugt `swift scripts/make_handbook.swift` das PDF
(mit „en“ die englische Fassung).

Oben stehen die Angaben für Titelseite und Dokumentinformationen, danach der Inhalt:
  # Kapitel             beginnt eine neue Seite und einen Eintrag in der Gliederung
  ## Überschrift        Zwischenüberschrift
  Text                  Absatz; Zeilenumbrüche sind egal, eine Leerzeile trennt Absätze
  - Punkt               Aufzählungspunkt
  > Hinweis             Text im farbigen Kasten
  | Befehl | Kürzel |   Zeile der Tastaturkürzel-Tabelle
-->

Dokumenttitel: Leser – Handbook
Thema: PDF viewer for macOS
Untertitel: Handbook for the macOS PDF viewer
Leitsatz: View documents. Nothing else.
Einleitung: Leser shows PDFs and never changes them: with an outline, thumbnails, full-text search and a split view. Free, ad-free and collecting no data.

# About This Handbook

Leser is a plain PDF viewer for macOS. It shows documents and never changes them. This handbook describes in a few short chapters what Leser can do and how it is used.

It is also a sample document: several chapters with an outline, so that the sidebar, the search and the split view have something to work with.

> “Leser” [ˈleːzɐ] is the German word for “reader”. Leser does not edit documents. Anyone who wants to add notes, rotate pages or fill in forms needs a different program. That very limitation is what keeps Leser fast and uncluttered.

## What Leser stands for

- Free and open source under the Apache 2.0 licence
- No ads, no tracking, no data collection
- Apple frameworks only, no third-party components
- English and German

# Reading and Navigating

You open a document by double-clicking it, through “File → Open …” or by dropping it onto the icon in the Dock. Leser remembers where you left off and opens the document there the next time.

## Turning pages

The left and right arrow keys turn one page at a time; the up and down keys and the trackpad scroll continuously. “Go to Page …” jumps straight to a page number, and the current page is always shown as the window subtitle.

## The sidebar

On the left, Leser shows either the outline of the document or thumbnails of every page. A single click switches between them. In the outline the highlight follows your reading position, so you can always see which chapter you are in.

- Outline: jumps to chapters and sections
- Thumbnails: shows every page with the current one highlighted

## Zoom

The zoom can be changed in steps or fitted to the page width, the page height or the whole page. The chosen fit is kept even when you resize the window.

## Tabs and windows

Leser opens several documents either as tabs in one window or in windows of their own, whichever the settings say. It remembers the size and position of the last window used, so new documents open to fit right away.

# Searching

The search looks through the whole document. Every match appears in a sidebar of its own on the right, each with a snippet of text and the page number. Clicking one jumps to that spot, and all matches are highlighted in the document.

## From match to match

The return key, or “Find Next”, walks you through the matches, and backwards works just as well. Leser ignores both capitalisation and accents, so “Ubergrosse” will find “Übergröße”.

> If the search finds nothing although the text is plainly visible, the document probably holds nothing but images, as a scan without text recognition does. In that case “Document Information” says No next to “Searchable text”.

## What can be searched

Leser searches the text of the document, not the names of its chapters. A document made of images therefore cannot be searched at all, while a PDF produced by a word processor can be searched completely.

# Two Places at Once

With the split view Leser shows the same document twice, side by side or stacked. That way a table and its explanation, a contract and its appendix, or two chapters far apart can be read together.

## Two documents

In the second half you can also open a different PDF, to compare two versions for instance. Each half keeps its own position, its own zoom and its own page layout.

## The active half

The toolbar, the menu commands, the sidebar and the search always act on the half you clicked last. A coloured line under its header shows which one that is.

## Closing it again

Clicking the cross in the header of the second half ends the split view, and so does the toolbar button or the menu command. The main document stays exactly where it was.

# Display and Settings

Leser knows four ways to arrange pages: continuous, single page, two pages, or two pages with the first one alone, the way a book with a title page reads.

## How documents open

The settings decide what a document opens with: which page layout, which zoom and whether the sidebar appears. They also decide whether new documents open as a tab or in a window of their own.

## Reloading automatically

When another program changes the file, after an export or when a LaTeX document is typeset, Leser shows the new version by itself. Page, zoom and page layout are kept.

## Default app

If you want Leser to open PDFs from now on, one click in the settings is enough. macOS then confirms the change itself, so that it never happens unnoticed.

# Questions and Answers

## Can I edit PDFs with Leser?

No, and it will stay that way. Leser is deliberately a viewer only. For notes, forms or merging documents, other programs are the right tool.

## Why is the outline missing?

Because the document has none. Many PDFs from word processors do not bring one along. In that case Leser shows thumbnails of the pages instead.

## Can I copy text?

Yes. Text can be selected and copied with the mouse as usual, as long as the document allows it. Whether it does is listed under “Document Information”.

## What happens to my documents?

Nothing, other than being shown. Leser never writes into a document and never uploads anything.

# Keyboard Shortcuts

The most useful commands are all within reach without the mouse:

| Find, Find Next, Find Previous | ⌘F, ⌘G, ⇧⌘G |
| Show and hide search results | ⌥⌘F |
| Show and hide the sidebar | ⌃⌘S |
| Outline, Thumbnails | ⌃⌘1, ⌃⌘2 |
| Zoom in, Zoom out, Actual Size | ⌘+, ⌘-, ⌘0 |
| Page Width, Page Height, Whole Page | ⌘1, ⌘2, ⌘3 |
| Previous and next page | ← and → |
| First and last page | ⌥⌘Home, ⌥⌘End |
| Go to Page | ⌥⌘G |
| Split View | ⌃⌘T |
| Document Information | ⌘I |
| Print | ⌘P |

# Privacy

Leser sends no data anywhere. There is no tracking, no analytics and no advertising, and the app itself never connects to the internet; only a voluntary tip goes through the App Store. Your documents are read and shown on your Mac and nowhere else.

## What is stored locally

- Your settings
- Size and position of the last window used
- The place you last read, for up to 200 documents

None of this leaves your Mac. The stored places can be deleted again with a switch in the settings.

> If you like, you can support the continued development with a voluntary tip. It unlocks nothing: Leser stays free in full.
