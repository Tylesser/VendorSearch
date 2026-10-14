<img src="branding/vendorsearch-icon-512.png" width="96" align="right" alt="">

# Tylesser - Vendor Search

A World of Warcraft addon that adds a **search panel to the vendor window**. Find any item the vendor sells by name, type or equipment slot, see all of the vendor's items in one list with no paging, and jump to or buy them in one click.

## Features

- **Search box** next to the vendor window. Each word you type must match the item's **name**, **type**, **subtype** or **equipment slot**: `vial`, `recipe cooking`, `head`, `thread`…
- **All items in one scrolling list**, with quality colours, stack size, limited stock and price (gold or tokens/currency).
- **Click** a result to turn the vendor window to its page and make the item glow.
- **Right-click** to buy, just like the vendor window. Items that cost tokens or currency are shown in the vendor window instead, so Blizzard's confirmation still appears.
- **Shift-click** to link the item in chat, **Ctrl-click** to preview it in the dressing room.
- **Enter** in the search box jumps to the first result.
- Sort by **item name** or **price** (click a header to sort, again to reverse, a third time to return to the vendor's own order).
- Filters: **Usable only** and **Affordable**.
- Movable panel; your sort and filter settings are saved.

## Usage

Talk to any vendor. The search panel appears on the right of the vendor window.

- `/vsearch`: open the panel and focus the search box
- `/vsearch reset`: dock the panel next to the vendor window again after you moved it

When the panel is closed, a **Search** button next to the vendor window opens it again.

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
