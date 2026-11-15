# VendorSearch ("Tylesser - Vendor Search")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from VendorSearch.toc)

- `Tylesser.lua`: the shared Tylesser "Runestone" look (`ns.T`: stone panels, gold borders, studs, Cinzel, buttons,
  check boxes, options page header, chat prefix). Loaded first. The same file is in every Tylesser addon: edit them together
  (see the workspace CLAUDE.md).
- `Core.lua`: SavedVariables `VendorSearchDB` defaults (`boxOffset`, `fade`, `bagCount` = true) and the pure logic
  (tested in `tools/harness/vs_test.lua`): the search matching (each typed word must match the item's name, type,
  subtype or equipment slot), recipe detection (item class 9), known-recipe detection from the merchant tooltip
  (`C_TooltipInfo.GetMerchantItem`, else the hidden `VendorSearchScanTooltip` with `SetMerchantItem`; looks for
  `ITEM_SPELL_KNOWN`, cached per item link while the vendor is open, not cached while the tooltip says
  `RETRIEVING_ITEM_INFO`), the filter combination `ns.ItemPasses` (words AND "Unknown recipes" AND "Usable", the
  merchant API's isUsable) and the bag count text `ns.BagCountText` (`GetItemCount(link, true)`, bags + bank).
- `Filter.lua`: filters the **vendor window's own item grid**. After Blizzard fills a page
  (`hooksecurefunc` on `MerchantFrame_UpdateMerchantInfo`), each slot is refilled with a matching item, and the button's
  ID is set to that item's real merchant index. Blizzard's own click, buy, tooltip, drag and preview handlers then keep
  working. Paging follows the matches. Fade mode keeps Blizzard's pages and fades the items that don't match.
  The search box can be Alt-dragged; its default position was a guess. A second row under the box (anchored to it, so
  it moves with it) has the "Unknown recipes", "Usable" and "In bags" check boxes. "Unknown recipes" and "Usable" are
  session-only (`Filter.unknownOnly`/`usableOnly`, reset on `MERCHANT_CLOSED`, not saved); "In bags" is
  `VendorSearchDB.bagCount`. Slot marks (bag count as a backpack icon + number, `ns.BagCountText`, top-right of the item button, green "Known" bottom-left) are
  our own font strings on each item button, refreshed from the button's current ID after every page update, and hidden
  on the Buyback tab and on close.
- `Events.lua`: vendor open/close (the search and the session toggles are cleared on `MERCHANT_CLOSED`), a short
  `C_Timer` refresh for item info that arrives late, bag/spell changes (`BAG_UPDATE_DELAYED`, `NEW_RECIPE_LEARNED`,
  `LEARNED_SPELL_IN_TAB`: clear the known cache and refresh counts), the addon compartment entry (`ns.T.AddCompartment`,
  prints `ns.PrintHelp`), and slash commands `/vsearch` and `/vendorsearch` (`reset`, `feedback`, `help`).

## Rules

- No separate panel: the user rejected one. All UI stays on `MerchantFrame`.
- With an empty search box and "Unknown recipes"/"Usable" off, the vendor's items, pages, order and colors must be
  exactly Blizzard's. The only additions are our controls and the small slot marks (bag count, which "In bags" turns
  off, and "Known" on learned recipes). Never change Blizzard's own Count/Stock text on the item button.
- No Auctionator code here. The flip finder (AH profit at vendors) lives in ProfitSort `Vendor.lua`.
- tylesser.com and CurseForge show the illustration `branding/vendorsearch-card.png` (alt text in the site's
  `site.json`). The in-game screenshots `Tylesser - Vendor Search 1.png` and `2.png` are no longer on the site.
