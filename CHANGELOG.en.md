# Changes

What changed in Leser from version to version. Deutsche Fassung: [CHANGELOG.md](CHANGELOG.md).

## 1.1 – not released yet

### New

**Bookmarks.** Leser keeps places you want to come back to. ⌘D sets a bookmark for the place at the top of the window, a right-click sets one exactly where you click on the page or at an entry of the outline. As the name Leser suggests the heading of the place. The bookmarks have an area of their own above the outline, where you can also rename and delete them, and are listed in the new “Bookmarks” menu. ⌃⌘3 shows and hides the area, and its height can be dragged; a double-click on the divider fits it to the contents again.

**Link preview.** When the pointer rests on a link for a moment, Leser shows in a small window where it leads, without leaving the page. A click jumps there.

**Page references become links.** References such as “see page 12” or “(page 359)” behave like links, even where the document does not contain them as links: with a preview and a jump to the page given. Leser counts the pages the way they are printed.

**References to other documents.** When a text names a page in another document, such as “(Atlas of the Stars, p. 42)”, clicking it opens that document at the page, in a new tab or in the second view. The first time, Leser asks which file belongs to the title and remembers it for all documents. Real links to other PDF files work the same way. Under “References” in the settings, all assigned documents are listed; you can show them in the Finder, assign another file or remove the assignment.

**Back and forward with the mouse.** The side buttons of a mouse, or a swipe on the trackpad or a Magic Mouse, take you back to where you were before a jump, and there again.

**Sepia.** “View → Sepia” tints the pages like warm paper, easier on the eyes for long reading. Printing and copying are not affected.

**Manual in the app.** “Help → Leser Manual” opens the manual right in Leser, in English or German and without an internet connection.

### Improved

**Copying.** Copied text arrives in paragraphs instead of line by line, and words hyphenated at the end of a line are joined again. Bold and italic are kept. White text, from coloured heading bars for instance, turns black so that it stays readable on a white background.

**Printing.** A section of its own in the print dialog offers actual size, “Shrink large pages” and “Scale to paper size”, as well as turning landscape pages. Actual size is now the default; Leser used to print every page a little smaller than other programs. Leser remembers the choice for the next print.

**Page numbers as in the book.** Between the page arrows stands the page label of the document, such as “xi” or “12”; clicking it opens “Go to Page”, which understands these labels as well. The window subtitle shows the position in the document, such as “11 of 300”.

**Search from the current page.** The search first shows the match on the page you are on or after it, and only then the ones before. This can be switched off in the settings.

**Reading position and bookmarks belong to the document.** Leser recognises a document by its identifier rather than its file name. The reading position and the bookmarks therefore stay when you rename or move the file, and a copy opens at the same place. Reading positions stored before are taken over.

**Split view when you continue reading.** If you close a document in split view, Leser opens it that way again next time, with both halves where they were.

**Settings in tabs.** The settings are divided into “General”, “View” and “References”.

**Manual.** The manual describes all new features, and its page references demonstrate them right away.

### Fixed

- Outline entries with sub-entries at the top level could no longer be clicked.
- Clicking the outline entry already highlighted did not go back to the start of the chapter.
- When Leser was started without a document and a PDF was chosen in the Open dialog, the window opened slightly offset.
- A window filling the whole screen was offset when another document was opened, and cut off as a result.

### Behind the scenes

- Unit tests for the parts with logic of their own, run with `./test.sh`.
- Test documents with links between two files in `testdata/`.
- A debug build with an identifier of its own, which can run next to the installed app.

## 1.0 – 1 October 2026

First release in the Mac App Store.
