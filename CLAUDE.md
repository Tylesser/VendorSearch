# VendorSearch ("Tylesser - Vendor Search")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from VendorSearch.toc)

- `Core.lua`: SavedVariables `VendorSearchDB` defaults (`boxOffset`, `fade`) and the search matching: each typed word
  must match the item's name, type, subtype or equipment slot.
- `Filter.lua`: filters the **vendor window's own item grid**. After Blizzard fills a page
  (`hooksecurefunc` on `MerchantFrame_UpdateMerchantInfo`), each slot is refilled with a matching item, and the button's
  ID is set to that item's real merchant index. Blizzard's own click, buy, tooltip, drag and preview handlers then keep
  working. Paging follows the matches. Fade mode keeps Blizzard's pages and fades the items that don't match.
  The search box can be Alt-dragged; its default position was a guess.
- `Events.lua`: vendor open/close (the search is cleared on `MERCHANT_CLOSED`), a short `C_Timer` refresh for item
  info that arrives late, and slash commands `/vsearch` and `/vendorsearch` (`reset`).

## Rules

- No separate panel: the user rejected one. All UI stays on `MerchantFrame`.
- With an empty search box, the vendor window must look and behave exactly as it does without the addon.
- No Auctionator code here. The flip finder (AH profit at vendors) lives in ProfitSort `Vendor.lua`.
- Screenshots in `branding/` (`Tylesser - Vendor Search 1.png`, `2.png`) appear on tylesser.com with the alt text from
  the site's `site.json`. Update both if the screenshots change.
