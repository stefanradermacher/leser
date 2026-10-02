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
  | Befehl | Kürzel |   Zeile der Tastaturkürzel-Tabelle
  {Name}                die Seite des Kapitels oder der Überschrift dieses Namens,
                        etwa „see page {Searching}“
-->

Dokumenttitel: Leser – Manual
Thema: PDF viewer for macOS
Untertitel: Manual for the macOS PDF viewer
Leitsatz: Made for reading.
Einleitung: Tidy, fast and free of distractions: with outline, bookmarks, full-text search and split view.
Free, ad-free and collecting no data.

# About This Manual

Leser is a plain PDF viewer for macOS, made for reading. This manual describes in a few short chapters what Leser can do and how it is used.

It is also a sample document: several chapters with an outline, so sidebar, search and split view have something to work with. The page references in it work like links, too (see page {Links and References}).

> “Leser” [ˈleːzɐ] is the German word for “reader”.

## What Leser stands for

- Free and open source under Apache 2.0 licence
- No ads, no tracking, no data collection
- Apple frameworks only, no third-party components
- English and German

# Reading and Navigating

You open a document by double-clicking it, with “File → Open …” or by dropping it onto the icon in the Dock. Leser remembers where you left off and opens the document there the next time.

![The outline in the sidebar, the whole page on the right](docs/screenshots/en/1-document.png)

## Turning pages

The left and right arrow keys turn one page at a time; the up and down keys and the trackpad scroll continuously. “Go to Page …” jumps straight to a page number, and the current page is always shown as the window subtitle.

## The sidebar

On the left, Leser shows either the outline of the document or thumbnails of every page. A single click switches between them. In the outline the highlight follows your reading position, so you can always see which chapter you are in.

- Outline: jumps to chapters and sections
- Thumbnails: shows every page with the current page highlighted

## Zoom

The zoom factor can be changed in steps or fitted to the page width, the page height or the whole page. The chosen fit is kept even when you resize the window.

## Back and forward

After a jump, through a link, the outline or “Go to Page …” for instance, “Go → Back” takes you to where you were before, and “Forward” takes you there again. With a mouse, its side buttons do the same, with a trackpad or a Magic Mouse a swipe.

## Tabs and windows

Leser opens several documents either as tabs in one window or in windows of their own, whichever the settings say. It remembers the size and position of the last window used, so new documents open to fit right away.

# Bookmarks

Bookmarks keep places you want to come back to. They have an area of their own above the outline and are listed in the “Bookmarks” menu, each with its page number.

## Setting a bookmark

“Bookmarks → Add Bookmark …” keeps the place at the top of the window. A right-click into the page sets it exactly there, a right-click on an outline entry at that chapter. As the name Leser suggests the heading of the place; you can take it, pick from further suggestions or type your own.

## Renaming and removing

A double-click or the return key renames a bookmark, the delete key removes it. Both are in the context menu as well. The divider to the outline can be moved; a double-click on it fits the height to the contents again.

> Bookmarks belong to the document, not to its file name. They stay when you rename or move the file.

# Links and References

When the pointer rests on a link, Leser shows after a moment where it leads, without leaving the page. A click jumps there, “Back” returns to where you were.

![The preview of a page reference, without leaving the page](docs/screenshots/en/3-preview.png)

## Page references in the text

References such as “see page {Bookmarks}” or “(page {Searching})” behave like links as well, even where the document does not contain them as links. Leser finds them in the text and shows the same preview when you point at them.

## References to other documents

When a text names a page in another document, such as “(Atlas of the Stars, p. 42)”, clicking it opens that document at the page given. The first time, Leser asks which file belongs to the title and remembers the answer for all documents. Links to other files work the same way.

Whether the other document opens in a new tab or in the second view is set under “References” in the settings. All assigned documents are listed there as well; you can show them in the Finder, assign another file or remove the assignment.

# Searching

The search looks through the whole document. Every match appears in a sidebar of its own on the right, each with a snippet of text and the page number. Clicking one jumps to that spot, and all matches are highlighted in the document.

![Searching for “Leser” with the list of matches on the right](docs/screenshots/en/2-search.png)

## From match to match

The return key, or “Find Next”, walks you through the matches, and backwards works just as well. The search starts on the page you are on; the settings can change that. Leser ignores both capitalisation and accents, so “Ubergrosse” will find “Übergröße”.

> If the search finds nothing although the text is plainly visible, the document probably holds nothing but images, as a scan without text recognition does. In that case “Document Information” says No next to “Searchable text”.

## What can be searched

Leser searches the text of the document, not the names of its chapters. A document made of images therefore cannot be searched at all, while a PDF produced by a word processor can be searched completely.

# Two Places at Once

With the split view Leser shows the same document twice, side by side or stacked. That way a table and its explanation, a contract and its appendix, or two chapters far apart can be read together.

![Two chapters side by side in split view](docs/screenshots/en/4-split.png)

## Two documents

In the second half you can also open a different PDF, to compare two versions for instance. Each half keeps its own position, its own zoom and its own page layout.

## The active half

The toolbar, the menu commands, the sidebar and the search always act on the half you clicked last. A coloured line under its header shows which one that is.

## Closing it again

Clicking the cross in the header of the second half ends the split view, and so does the toolbar button or the menu command. The main document stays exactly where it was. If you close a document in split view, Leser opens it split again next time, with both halves where they were, as long as “Continue where you left off” is on. This applies when both halves show the same document.

# Display and Settings

Leser knows four ways to arrange pages: continuous, single page, two pages, or two pages with a single first page, the way a book with a title page reads.

## How documents open

Under “View” the settings decide what a document opens with: which page layout, which zoom factor and whether the sidebar appears. Under “General” they decide whether new documents open as a tab or in a window of their own.

## Sepia

“View → Sepia” tints the pages like warm paper, easier on the eyes for long reading. Printing and copying are not affected.

## Reloading automatically

When another program changes the file, after an export or when a LaTeX document is typeset, Leser shows the new version by itself. Page, zoom and page layout are kept.

## Printing

The print dialog has a section of its own for Leser: pages can be printed at actual size, large pages shrunk or all of them scaled to the paper size, and Leser can turn landscape pages to fit if you like.

## Default app

If you want Leser to open PDFs from now on, one click in the settings is enough. macOS then confirms the change itself, so that it never happens unnoticed.

# Questions and Answers

## Can I edit PDFs with Leser?

No. Leser is a viewer only. For notes, forms or merging documents, other programs such as Preview are the right tool.

## Why is the outline missing?

Because the document doesn't have one. Many PDFs from word processors do not bring one along. In that case Leser shows thumbnails of the pages instead.

## Can I copy text?

Yes. Text can be selected and copied with the mouse as usual, as long as the document allows it. Whether it does is listed under “Document Information”. Leser joins the lines into paragraphs again and keeps bold and italic; white text turns black, so that it stays readable on a white background.

## What happens to my documents?

Nothing, other than being shown. Leser never modifies documents and never uploads anything.

# Keyboard Shortcuts

The most useful commands are all within reach without the mouse:

| Find, Find Next, Find Previous | ⌘F, ⌘G, ⇧⌘G |
| Show and hide search results | ⌥⌘F |
| Show and hide the sidebar | ⌃⌘S |
| Outline, Thumbnails | ⌃⌘1, ⌃⌘2 |
| Zoom in, Zoom out, Actual Size | ⌘+, ⌘-, ⌘0 |
| Page Width, Page Height, Whole Page | ⌘1, ⌘2, ⌘3 |
| Previous and next page | ← and → |
| First and last page | Home, End |
| Back, Forward | ⌘[, ⌘] |
| Go to Page | ⌥⌘G |
| Add Bookmark | ⌘D |
| Show and hide bookmarks | ⌃⌘3 |
| Split View | ⌃⌘T |
| Document Information | ⌘I |
| Print | ⌘P |

# Privacy

Leser sends no data anywhere. There is no tracking, no analytics and no advertising, and the app itself never connects to the internet; only a voluntary tip goes through the App Store. Your documents are read and shown on your Mac only.

## What is stored locally

- Your settings
- Size and position of the last window used
- The place you last read, for up to 200 documents
- Your bookmarks
- Which file belongs to which title, for references to other documents

None of this leaves your Mac. The stored places can be deleted again with a switch in the settings, the assignments one by one under “References”.

> If you like, you can support the continued development with a voluntary tip. It unlocks nothing: Leser stays free in full.
