[简体中文](README.md) | **English**

# ADHD-Friendly Bionic Reading Plugin for KOReader and Moon (月读), Supporting Chinese and English

# (Made by elbowing an AI into doing it)

A bionic reading plugin for EPUBs in [KOReader](https://koreader.rocks/): it bolds the first half of each word to guide your eyes quickly across the text and make reading easier. It supports both English and Chinese, is designed for e-ink devices such as the Kindle, and is compatible with [Moon (月读)](https://github.com/AnkioTomas/moon).

<!-- Suggested: add 2–3 screenshots here: the settings menu, and a before/after comparison -->

## Features

- **One-tap toggle**: Turn bionic reading on or off per EPUB, or enable it by default for all EPUBs. You can also bind "Bionic reading: toggle" in the Gesture Manager.
- **Never modifies your book**: The original file is left untouched. The plugin stores the converted content as a cached copy, and KOReader still believes you are reading the original book, so the title, reading progress, and reading history all stay the same.
- **Separate English and Chinese settings**: English is bolded word by word. Chinese has no spaces, so it is bolded in groups of a fixed number of characters. The two sets of settings are independent of each other.
- **Rich appearance options**: Fixation strength, saccades interval, word stem length, edge opacity, 6 emphasis styles, and 6 colours (for colour screens).
- **Presets**: Save multiple sets of settings for English and Chinese separately and apply them with one tap.
- **Automatic annotation sync**: Highlights, notes, and bookmarks made in the original book appear when you open the bionic version; annotations made in the bionic version are automatically synced back to the original a few seconds later. Additions, edits, and deletions are all synced, and positions are converted by text content and verified, so nothing ends up misplaced.
- **Backup and restore**: An automatic backup is made the first time you open a book each day, and you can also back up manually at any time (with a custom name). Only the 3 most recent backups are kept. Restoring only fills in what is missing, and you can also import the current book's annotations from a backup at any time.
- **Export bionic EPUBs**: Convert local books and export them as standalone EPUB files that work on other devices too.
- **Moon compatibility**: If Moon is installed, a "Bionic reading" button is added to Moon's reading panel, and chapters from Moon's online book sources are supported. The plugin works perfectly well without Moon. (Versions after Moon 5.24 have not been tested.)
- **Chinese and English interface**: The menu language can be switched at any time and follows KOReader's interface language by default.

## Compatibility

| Item | Notes |
|---|---|
| Verified devices | Kindle 2024 |
| Other devices | In theory, any device that can run KOReader should work, but this is **untested** |
| Supported formats | EPUB only. PDF, MOBI, AZW3, and other formats are not supported; you can convert them to EPUB first with a tool such as Calibre |
| Dependencies | No other plugins required. Moon is optional |

<!-- Suggested: add the KOReader version you used for testing here -->

## Installation

1. On this repository's **Releases** page, download the latest `bionic.koplugin-vX.Y.Z.zip`. Download the file uploaded to the Release, and **do not** download the automatically generated "Source code" archive.
2. Unzip it to get the `bionic.koplugin` folder. **Do not rename the folder.**
3. Connect your Kindle via USB and copy the entire `bionic.koplugin` folder into KOReader's `plugins` directory. On a Kindle this is usually `/mnt/us/koreader/plugins/`.
4. Eject the device, then restart KOReader (or exit KOReader and reopen it).
5. Open any EPUB and find "Bionic reading" in the top menu.

## Quick Start

**Menu location** (may vary slightly depending on your KOReader version):

- While reading: Top menu → Typeset tab → Bionic reading
- In the file manager: Top menu → More tools → Bionic reading

**Getting started:**

1. Open an EPUB and check "Bionic reading for this book". The first time you enable it, the entire book has to be converted; large books may take a while on older devices. After that, the cached copy is used directly.
2. To enable it by default for all EPUBs, check "Always on for EPUB books".
3. Adjust the effect under "English / Latin text" and "Chinese (Han characters)". Changes are applied immediately to the book you are reading.
4. For a quick toggle, bind "Bionic reading: toggle" to a gesture in KOReader's Gesture Manager.

## Settings

### English / Latin text

English, Greek, Cyrillic, and other scripts that separate words with spaces are all handled by these settings.

| Setting | Range | Default | Description |
|---|---|---|---|
| Bionic effect on English text | On / Off | Off | Must be turned on manually |
| Fixation strength | 1 – 4 | 2 | How much of each word is bolded. 1 is the least; 4 bolds the entire word stem |
| Saccades interval | 0 – 4 | 0 | How many words to skip between two bolded words. 0 means every word is bolded |
| Word stem length | 30 – 100% | 70% | The proportion of a longer word that can be bolded |
| Edge opacity | 20 – 100% | 100% | The brightness of the non-bolded part. 100 means no dimming. **For e-ink screens, keeping it at 100 is recommended** |
| Emphasis style | 6 options | Bold | Bold, semi-bold, extra bold, underline, bold + underline, italic. Semi-bold and extra bold depend on whether the font has the corresponding weights |
| Emphasis colour (colour screens) | On / Off | Off | Only works on colour screens |
| Colour | 6 options | Red | Red, blue, green, orange, purple, brown. The colours are toned down to suit colour e-ink screens |

### Chinese (Han characters)

### Might Japanese and Korean work too, in theory?

Chinese has no spaces, so words cannot be identified. The plugin therefore **splits the text into groups of every N characters** and bolds the first part of each group. This is a fixed-length approximation, not true word segmentation.

| Setting | Range | Default | Description |
|---|---|---|---|
| Bionic effect on Chinese text | On / Off | Off | Chinese characters have no spaces, so words cannot be detected. When set to N, every N characters are treated as one “word”. 0 means Chinese characters are left unprocessed.|
| Emphasised share | 20 – 80% | 50% | The proportion of each group that is emphasised. 50% means the first half |
| Saccades interval | 0 – 4 | 0 | How many groups to skip between two emphasised groups |
| Edge opacity | 20 – 100% | 100% | The brightness of the non-emphasised part of each group |
| Emphasis style, emphasis colour, colour | Same as English | Same as English | Set separately from English |

### General options

- **Page theme for dimming**: Light page (dark text) or dark page (light text). This only matters when edge opacity is below 100%.
- **Separate settings for this book**: When checked, this book uses its own set of settings without affecting other books. Unchecking it returns the book to the global settings.
- **Clear conversion cache**: Deletes the cached copies produced by conversion to free up space. The book will be converted again the next time it is opened.
- **Language / 语言**: At the very bottom of the menu; switches the interface between Chinese and English.

## Presets

At the very bottom of both the "English / Latin text" and "Chinese (Han characters)" settings pages there is a "Presets" entry.

- **Save current settings as preset…**: Give the current settings a name and save them. If you leave the name blank, it is automatically named "Preset 1", "Preset 2", and so on. Using an existing name updates that preset.
- **Default settings**: A built-in entry that restores the plugin's default values.
- **Tap a preset name**: Applies that preset. When the current settings exactly match a preset, a checkmark appears in front of it.
- **Delete preset**: Choose the preset you want to delete.

English and Chinese presets are independent of each other. **Presets do not change the bionic effect switches**: whether the English effect and the Chinese effect are enabled is something you toggle manually, after which you choose a preset. The Chinese "group size" also serves as the on/off switch for the Chinese effect, so applying a preset only changes it when the Chinese effect is already on.

## Annotations, Sync, Backup, and Restore

"Annotations" means highlights, notes, and bookmarks.

### Syncing between the original book and the bionic version

Menu: Bionic reading → Highlight sync

The original and the bionic version of the same book have different layouts, and in an EPUB, annotation positions are recorded within the text structure, so they cannot be shared directly. The plugin converts each annotation's position to the other version based on the "text content", and after converting it also verifies that the highlighted text matches. If it doesn't match, the annotation is not written, so nothing ends up misplaced.

- **Original → bionic**: Annotations you add, edit, or delete in the original book are brought over automatically when you open the bionic version. If the book already has a converted bionic cache, the changes are also written into the bionic copy right away; for books that haven't been converted yet, they are brought over the first time you open the bionic version.
- **Bionic → original**: Annotations you add, edit, or delete in the bionic version are automatically synced to the original about 3 seconds later; a final check is also performed when you close the book.
- **What is synced**: Highlights, notes, and bookmarks. Additions, edits (note text, colour, style, and highlight range), and deletions are all synced.
- **Annotations survive settings changes**: After you change a setting that alters the text structure, such as fixation strength, your annotations are carried over to the version with the new settings via the original book.

**This menu contains:**

- **Sync highlights and notes between original and bionic**: The master switch for syncing; on by default.
- **Sync this book now**: First syncs the current changes over, then reopens the book to bring in changes from the other version, and retries items that failed earlier.
- **Not carried over yet (n)**: See below. Only available while in a book.
- **Back up now…**, **Automatic backup once a day**, **Import this book's notes from a backup**: See "Backup" below.

**What to do when sync fails:** In rare cases an annotation cannot be converted, for example because its text doesn't match between the two versions, or because a chapter's markup is non-standard. These annotations are not lost; they appear under "Not carried over yet (n)" and a notification is shown. Open one of them and you can:

- **Import by searching for the text**: Look for that text in the other version and place the annotation there.
- **Discard (do not sync this one)**: Never try to sync it again.

You can also use "Import all by searching for the text" to handle everything at once.

### How notes are stored

The bionic effect changes the text structure, so internally the plugin gives **each text structure its own independent set of annotations**, and then uses the sync described above to keep these sets consistent with the original book (the original acts as the relay):

- Toggling the bionic effect, or changing fixation strength, saccades interval, word stem length, emphasis style, whether the edges are dimmed, or the Chinese grouping parameters, switches you to a different set.
- Changing only the colour, the specific edge-opacity value, or the page theme does not switch sets.
- The other sets of annotations are not lost; when you switch back to the corresponding settings, they are automatically aligned with the original book.

> In older versions, annotations in the original and in the bionic version were kept separate; they are now synced automatically. The first time you open a book after upgrading, the plugin checks which version your existing annotations were made in and puts them in the right place.

### Backup

Menu: Bionic reading → Backup annotations

- **Back up now…**: Opens a naming box. Enter a name, or leave it blank to use the date and time as the name.
- **Automatic backup once a day**: A backup is made automatically the first time you open a book each day (before any syncing), named "Automatic backup" followed by the date. You can turn this off in the "Highlight sync" menu. If there are no annotations yet when you open a book that day, it will try again a few hours later.
- **Only the 3 most recent are kept**: Manual and automatic backups together are limited to the newest 3; older ones are deleted automatically. To keep a particular backup long-term, copy its folder out of `bionic_backups` to somewhere else.
- **Delete backups**: Lists all backups; tap one and confirm to delete it. You can also delete all of them at once.
- Backup scope: Books in your reading history, books the plugin has processed, and the book currently open. Chapters from Moon's online book sources and conversion caches are not included.
- Each backup is saved in `koreader/bionic_backups/<date-time>/` and contains three files:
  - `backup.lua`: the complete data, used for restoring
  - `backup.txt`: the annotations as human-readable text
  - `info.lua`: brief information such as the name and time

### Restore

Menu: Bionic reading → Backup annotations → Restore backup

- **Can only be done in the file manager** (with no book open). This is because when an open book is closed, it writes its in-memory annotations back to disk, which would overwrite the restored content.
- Restoring only **fills in annotations missing from a book**; it **does not delete or modify** existing content, so restoring repeatedly will not create duplicates.
- Annotations go back to the set they originally belonged to, so nothing is misplaced. Restored annotations are synced to the other version the next time you open that book.
- Books that can no longer be found are skipped, and the results will tell you so.

Two minor limitations:

- If you deliberately deleted an annotation after making a backup, restoring will bring it back.
- Restored annotations are inserted according to their position in the document, but when a paragraph has headings, images, or other content interleaved within it, the order may be slightly off. This only affects the jump order of "next highlight" and does not lose any data.

### Importing this book's annotations from a backup while in the book

Menu: Bionic reading → Highlight sync → Import this book's notes from a backup

Available at any time, without closing the book. It only adds annotations that this book doesn't already have and leaves existing ones alone. Annotations in the backup that belong to a different version (the original, or the current bionic settings) have their positions converted first and are then added; annotations belonging to other bionic settings cannot be converted and are skipped, with the count shown in the results. After importing, they are automatically synced to the other version.

## Exporting Bionic EPUBs

Menu: Bionic reading → Export → Export bionic EPUB

Converts a local book and exports it as a standalone EPUB file that you can read on other devices.

- You can choose whether to append "(Bionic)" to the exported file's title, to avoid a name clash with the original book.
- By default it exports to `documents/bionic_export`; you can also change the export folder.
- Only regular EPUBs are supported; chapters from Moon's online book sources are not.

## Using It with Moon

- Without Moon: The plugin works completely normally; Moon-related files and menu items have no effect.
- With Moon: An extra "Bionic reading" button appears in the reading panel, and you can set "Always on for online-source chapters".
- Chapters from Moon's online book sources are **rewritten in place** (the original is backed up as `.html.bionic`). If you turn off bionic reading within a book, the chapters are restored one by one the next time they are opened; when the plugin is uninstalled, all of them are restored automatically.
- Moon is still iterating quickly. If, after a Moon upgrade, the button disappears from the panel or online chapters stop working, please open an Issue.

## Data Locations

All of the paths below are under KOReader's data directory (usually `/mnt/us/koreader/` on a Kindle):

| Path | Contents |
|---|---|
| `settings/bionic_reading.lua` | The plugin's settings, presets, and annotation sync records |
| `bionic_cache/` | Converted cached copies; can be cleared at any time |
| `bionic_backups/` | Backups (manual and daily automatic; only the 3 most recent are kept) |
| `bionic_save/` | Created only on uninstall; holds the preserved notes text and backup |
| `../documents/bionic_export/` | The default export location |

## Updating

Menu → Bionic reading → **Check for updates** (requires an internet connection). Restart KOReader after updating; the old version is kept as `plugins/bionic.koplugin.old` and can be rolled back to manually.

## Uninstalling

In the **file manager** (not inside a book): Bionic reading → Uninstall Bionic Reading…. Three options will appear:

- **Cancel**: Does nothing.
- **Uninstall**: Books are restored to their original text, and notes made under the bionic effect are saved as a text file in `koreader/bionic_save`. The plugin, cache, settings, and all backups are deleted.
- **Uninstall and keep backup**: On top of the above, the most recent backup is also kept, likewise in `koreader/bionic_save`. If you want to use the plugin again later, just copy the backup folder from there back into `koreader/bionic_backups/`.

The `bionic_save` folder is created only on uninstall, and only appears if there is actually something to save.

## FAQ

**I can't see any bold effect?**
Some fonts have no bold weight. You can switch to a font that includes a bold weight, or change the emphasis style to "Underline". Whether "Semi-bold" and "Extra bold" work depends on whether the font has the corresponding weights.

**"Bionic reading for this book" is greyed out in the menu?**
The book currently open is not an EPUB. This plugin only supports EPUB.

**The first time I enable it, it's very slow?**
The first time, the entire book needs to be converted; after that, the cached copy is used directly. Large books are slower on older devices.

**My reading position is slightly off after changing a setting?**
Settings that change the text structure trigger a re-conversion, and the plugin returns you to your previous position by percentage, which may leave a slight deviation.

**My highlights have disappeared?**
First check whether they are listed under "Bionic reading → Highlight sync → Not carried over yet". Annotations are stored in separate sets by text structure and synced through the original book (see above), and changing the settings back to what they were when you made the annotations will also align them automatically. You can also bring them back with "Import this book's notes from a backup" or "Restore backup".

**Highlights I made in the original book don't show up in the bionic version?**
Confirm that the master switch under "Highlight sync" is checked, then tap "Sync this book now". If they still don't appear, look at "Not carried over yet", which lists the items that could not be converted; you can import them by searching for the text.

**The cache takes up too much space?**
"Clear conversion cache" in the menu shows the space used; tap it to clear.

**The Chinese effect looks strange?**
Chinese is grouped by a fixed number of characters rather than true word segmentation, so the bolded portion won't necessarily fall on word boundaries. Try different group sizes and emphasis ratios.

## Known Limitations

- EPUB only.
- Chinese uses fixed-length grouping, not word segmentation.
- Verified only on the Kindle 2024.
- Annotation sync converts positions by text content. In rare cases (text that doesn't match between the two versions, or non-standard chapter markup, such as text placed directly inside a table), conversion fails and the annotation goes into "Not carried over yet", where you can manually import it by searching for the text.
- Books that use the legacy typesetting DOM do not take part in syncing and are skipped automatically.
- Only the current set of bionic settings is synced with the original book in real time; other settings you used previously are aligned only when you switch back to them.
- The plugin uses some of KOReader's internal interfaces, so it may need to be adapted after a major KOReader update. After upgrading KOReader, it is recommended to back up your annotations first and then try it on a book you don't care about.
- Adjusting edge opacity may cause page-turn animations to stutter. If this happens, set it back to the default value or turn off page-turn animations.
- Versions after Moon 5.24 have not been tested.

## Changelog

**v1.0.1**

- Fixed: adjusting edge opacity increased conversion time.

**v1.0.2**

- Added: automatic two-way sync of annotations (highlights, notes, bookmarks) between the original book and the bionic version. Additions, edits, and deletions are all synced; items that fail to sync can be imported manually.
- Added: an automatic backup the first time you open a book each day; only the 3 most recent backups are kept; you can import the current book's annotations from a backup while in the book.

## Reporting Issues

Feedback is welcome in Issues. To help pinpoint the problem, please provide as much of the following as you can:

- Device model and firmware version
- KOReader version
- Plugin version (the version number in the downloaded zip file's name)
- Steps to reproduce
- If there is a crash, attach `crash.log` from the KOReader data directory

## Credits & License

- [JiffyReader](https://github.com/jiffyreader/jiffyreader-plugin) (GPL-3.0)
- [KOReader](https://github.com/koreader/koreader), [Moon (月读)](https://github.com/AnkioTomas/moon)
- This project is released under GPL-3.0; see `LICENSE`.
