<img src="branding/vendorsearch-icon-512.png" width="96" align="right" alt="">

# Tylesser - Vendor Search

A World of Warcraft addon that adds a **search box to the vendor window**. Type part of an item's name, type or equipment slot and the vendor window shows only the matching items. No extra windows.

## Features

- **Search box on the vendor window.** Each word you type must match the item's **name**, **type**, **subtype** or **equipment slot**: `vial`, `recipe cooking`, `head`, `thread`...
- **Filters the vendor's own item grid**, across all pages. The page count updates to the matching items ("Page 1 of 2").
- Matching items work exactly like normal: **right-click to buy**, tooltips, Shift-click to link, Ctrl-click to preview, drag to your bags. Items that cost tokens or currency still show Blizzard's confirmation.
- Shows how many items match, or "No items match your search."
- With an empty search box the vendor window looks and behaves exactly as without the addon.
- The search is cleared when you close the vendor. The box hides on the Buyback tab.
- **Alt-drag** the search box to move it; the position is saved.

## Usage

Talk to any vendor and type in the search box at the top of the vendor window.

- `/vsearch`: put the cursor in the search box
- `/vsearch reset`: move the search box back to its default place

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
