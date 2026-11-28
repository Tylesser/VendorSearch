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
  `RETRIEVING_ITEM_INFO`), mounts and pets (`ns.CollectibleKind`: "recipe" / "mount" / "pet" by item class 9, 15/5,
  15/2, 17 or by item ID in the journals; `ns.IsKnownItem`: `C_MountJournal.GetMountFromItem` +
  `GetMountInfoByID` 11th return isCollected, `C_PetJournal.GetPetInfoByItemID` 13th return speciesID +
  `GetNumCollectedInfo`, the tooltip's `ITEM_SPELL_KNOWN` when a journal can't tell; Forever has both journals,
  2026-11-28; toys are left out: Forever's C_ToyBox has no GetToyInfo and toys are used as items), the filter
  combination `ns.ItemPasses` (words AND "Unknown" AND "Usable", the merchant API's isUsable, AND "Can afford":
  `ns.CanAfford` = not sold out and `CanAffordMerchantItem`, else `ns.CostsCovered` from GetMoney /
  GetMerchantItemCostItem), the bag count text `ns.BagCountText` (`GetItemCount(link, true)`, bags + bank) and buying
  in bulk: `ns.BagRoom` (free slots of bags whose family takes the item + room on partial stacks), `ns.BuyLimit`
  (gold, stock, room, `ns.BULK_MAX` 2000), `ns.BuyPlan` (whole vendor units, at most `GetMerchantItemMaxStack` per
  purchase), `ns.BulkInfo` (nil for unstackable items and extended costs) and `ns.BuyBulk` (checks the slot's link
  again, then one `BuyMerchantItem(index, n)` per chunk, all inside the Buy click).
- `Filter.lua`: filters the **vendor window's own item grid**. After Blizzard fills a page
  (`hooksecurefunc` on `MerchantFrame_UpdateMerchantInfo`), each slot is refilled with a matching item, and the button's
  ID is set to that item's real merchant index. Blizzard's own click, buy, tooltip, drag and preview handlers then keep
  working. Paging follows the matches. Fade mode keeps Blizzard's pages and fades the items that don't match.
  The search box can be Alt-dragged; its default position was a guess. A second row under the box (anchored to it, so
  it moves with it) has the "Unknown" (`L["Unknown##items"]`), "Usable", "Can afford" and "In bags" check boxes.
  "Unknown", "Usable" and "Can afford" are session-only (`Filter.unknownOnly`/`usableOnly`/`affordOnly`, reset on
  `MERCHANT_CLOSED`, not saved); "In bags" is
  `VendorSearchDB.bagCount`. Slot marks (bag count as a backpack icon + number, `ns.BagCountText`, top-right of the item button, green "Known" bottom-left) are
  our own font strings on each item button, refreshed from the button's current ID after every page update, and hidden
  on the Buyback tab and on close. Every item button gets `HookScript("OnClick")`: Alt-click (no Shift/Ctrl) opens
  the Buy window. Blizzard's own OnModifiedClick does nothing for an Alt-click on goods (forever
  `HandleModifiedItemClick`: CHATLINK, DRESSUP, EXPANDITEM only for azerite / profession gear; Shift = SPLITSTACK opens
  Blizzard's split for up to `GetMerchantItemMaxStack`, which stays as it is).
- `Buy.lua`: the Buy window (`VendorSearchBuyFrame`, parented to MerchantFrame, centred over it like Blizzard's stack
  split, in UISpecialFrames): amount box, -/+ one purchase, Max, cost and limit lines, Buy / Cancel. Redraws on
  MERCHANT_UPDATE, BAG_UPDATE_DELAYED, PLAYER_MONEY; closes when the slot's item changes, on the Buyback tab and on
  vendor close. Its widgets come from a small `Look` table at the top (Codex's twin swaps in Codex's widgets).
- `Events.lua`: vendor open/close (the search and the session toggles are cleared on `MERCHANT_CLOSED`), a short
  `C_Timer` refresh for item info that arrives late, bag/spell changes (`BAG_UPDATE_DELAYED`, `NEW_RECIPE_LEARNED`,
  `LEARNED_SPELL_IN_TAB`, `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`, `COMPANION_LEARNED`: clear the known cache and refresh
  counts; `PLAYER_MONEY` / `CURRENCY_DISPLAY_UPDATE` refresh while "Can afford" is on), the addon compartment entry (`ns.T.AddCompartment`,
  prints `ns.PrintHelp`), and slash commands `/vsearch` and `/vendorsearch` (`reset`, `feedback`, `help`).

**Twin in Codex:** `Addons/Codex/Modules/VendorSearch` is this addon ported into Codex (2026-11-19): the same
Core and Filter code on `ns.vendorsearch`, with Codex's settings and widgets. A fix here goes there too (and back).

## Rules

- No separate panel: the user rejected one. All UI stays on `MerchantFrame`.
- With an empty search box and "Unknown"/"Usable"/"Can afford" off, the vendor's items, pages, order and colors must
  be exactly Blizzard's. The only additions are our controls, the small slot marks (bag count, which "In bags" turns
  off, and "Known" on learned recipes and owned mounts / pets) and the Buy window that only an Alt-click opens.
  Never change Blizzard's own Count/Stock text on the item button.
- No Auctionator code here. The flip finder (AH profit at vendors) lives in ProfitSort `Vendor.lua`.
- tylesser.com and CurseForge show the illustration `branding/vendorsearch-card.png` (alt text in the site's
  `site.json`). The in-game screenshots `Tylesser - Vendor Search 1.png` and `2.png` are no longer on the site.
