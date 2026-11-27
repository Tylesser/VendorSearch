<img src="branding/vendorsearch-icon-512.png" width="96" align="right" alt="">

# Tylesser - Vendor Search

A World of Warcraft addon that adds a **search box to the vendor window**. Type part of an item's name, type or equipment slot and the vendor window shows only the matching items. No extra windows.

## Features

- **Search box on the vendor window.** Each word you type must match the item's **name**, **type**, **subtype** or **equipment slot**: `vial`, `recipe cooking`, `head`, `thread`...
- **Filters the vendor's own item grid**, across all pages. The page count updates to the matching items ("Page 1 of 2").
- Matching items work exactly like normal: **right-click to buy**, tooltips, Shift-click to link, Ctrl-click to preview, drag to your bags. Items that cost tokens or currency still show Blizzard's confirmation.
- Shows how many items match, or "No items match your search."
- **Unknown recipes** check box: show only recipes you haven't learned yet. Recipes you already know get a small green **Known** mark.
- **Usable** check box: show only items your character can use.
- Both combine with the search words (an item must match all of them), work in Fade mode too, and reset when you close the vendor.
- **In bags**: each vendor item shows how many you already have in your bags and bank, shown as a small backpack icon and a number, top-right of the item. Untick it to hide the counts.
- **Fade** option: instead of hiding items, keep the vendor's normal pages and fade the ones that don't match. The match count lists the pages with matches, and the vendor turns to the first one (or press Enter).
- With an empty search box and the check boxes off, the vendor shows its items exactly as without the addon (only the small counts and Known marks are added).
- The search is cleared when you close the vendor. The box hides on the Buyback tab.
- **Alt-drag** the search box to move it; the position is saved.

## Usage

Talk to any vendor and type in the search box at the top of the vendor window.

- `/vsearch`: put the cursor in the search box
- `/vsearch reset`: move the search box back to its default place
- `/vsearch feedback`: get the link to report a bug or suggest an idea
- `/vsearch help`: list these commands (also in the addon menu by the minimap, on clients that have it)

Languages: English, German, French, Spanish (Spain and Mexico), Russian and Brazilian Portuguese, following your game client.

## Feedback

Found a bug or have an idea? Type `/vsearch feedback` in game to get the link, or go straight to [tylesser.com/feedback](https://tylesser.com/feedback/#vendorsearch).

No GitHub account? Join the [Tylesser Discord](https://discord.gg/n2rEB6mRxF) and post in #bug-reports or #ideas with the addon's tag; each post is copied to GitHub and the bot answers with the link.

## Installation

Install from CurseForge, or download the latest zip from [Releases](https://github.com/Tylesser/VendorSearch/releases) and extract it to `Interface/AddOns`. The folder must be named `VendorSearch`.

## Releasing (maintainers)

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager). Push a version tag to publish to GitHub Releases and CurseForge:

```
git tag v1.0.0
git push origin v1.0.0
```

## License

[MIT](LICENSE)
