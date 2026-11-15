local _, ns = ...

-- The "Unknown recipes" and "Usable" toggles are not saved: they reset when the vendor closes,
-- so the next vendor always opens unfiltered.
ns.defaults = {
  boxOffset = nil,
  fade = false,
  bagCount = true,
}

ns.PREFIX = ns.T.Prefix("Vendor Search")

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local RECIPE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9

-- Retail moved the merchant API into C_MerchantFrame; older clients keep the
-- global function with the same return order.
local function GetMerchantItem(index)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(index)
    if info then
      return info.name, info.texture, info.price, info.stackCount, info.numAvailable,
        info.isPurchasable, info.isUsable, info.hasExtendedCost
    end
    return nil
  end
  return GetMerchantItemInfo(index)
end

-- True if the item link is a recipe (pattern, plans, formula, manual...).
function ns.IsRecipeLink(link)
  if not link then
    return false
  end
  local classID
  if GetItemInfoInstant then
    classID = select(6, GetItemInfoInstant(link))
  end
  if classID == nil and GetItemInfo then
    classID = select(12, GetItemInfo(link))
  end
  return classID == RECIPE_CLASS
end

-- One vendor item (Merchant tab), or nil if the slot has no data yet.
function ns.ReadMerchantItem(index)
  local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost =
    GetMerchantItem(index)
  if not name then
    return nil
  end
  local link = GetMerchantItemLink(index)
  local item = {
    index = index,
    name = name,
    icon = texture,
    price = price or 0,
    stackCount = stackCount or 1,
    numAvailable = numAvailable or -1,
    isPurchasable = isPurchasable ~= false,
    isUsable = isUsable ~= false,
    hasExtendedCost = hasExtendedCost and true or false,
    link = link,
    isRecipe = false,
  }
  if link then
    local _, _, quality, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
    item.quality = quality
    item.itemType = itemType
    item.itemSubType = itemSubType
    if equipLoc and equipLoc ~= "" then
      item.equipSlot = _G[equipLoc]
    end
    item.isRecipe = ns.IsRecipeLink(link)
  end
  item.searchText = table.concat({
    name, item.itemType or "", item.itemSubType or "", item.equipSlot or "",
  }, " "):lower()
  return item
end

-- Returns every item of the open vendor (Merchant tab), in vendor order.
function ns.ScanMerchant()
  local items = {}
  for index = 1, GetMerchantNumItems() do
    local item = ns.ReadMerchantItem(index)
    if item then
      table.insert(items, item)
    end
  end
  return items
end

function ns.ParseQuery(text)
  local terms = {}
  for term in (text or ""):lower():gmatch("%S+") do
    table.insert(terms, term)
  end
  return terms
end

-- Every word must appear in the item's name, type, subtype or slot.
function ns.Matches(item, terms)
  for _, term in ipairs(terms) do
    if not item.searchText:find(term, 1, true) then
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
-- Known recipes: read from the item's tooltip ("Already known")
--------------------------------------------------------------------------------
-- Per item link, while the vendor is open. Cleared on open/close and when bags or spells change.
local knownCache = {}

function ns.ClearKnownCache()
  knownCache = {}
end

-- True if one of the tooltip lines says the item is already known.
function ns.LinesSayKnown(lines)
  local known = ITEM_SPELL_KNOWN or "Already known"
  for i = 1, #lines do
    local text = lines[i]
    if type(text) == "string" then
      local ok, found = pcall(string.find, text, known, 1, true)
      if ok and found then
        return true
      end
    end
  end
  return false
end

-- Tooltip lines are only final once the item's data has arrived.
local function LinesComplete(lines)
  if #lines == 0 then
    return false
  end
  local retrieving = RETRIEVING_ITEM_INFO or "Retrieving item information"
  for i = 1, #lines do
    if lines[i] == retrieving then
      return false
    end
  end
  return true
end

local scanTip
local SCAN_TIP_NAME = "VendorSearchScanTooltip"

-- The left-hand texts of the merchant item's tooltip, or nil.
local function MerchantTooltipLines(index)
  if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
    local ok, data = pcall(C_TooltipInfo.GetMerchantItem, index)
    if ok and data and data.lines then
      local lines = {}
      for i = 1, #data.lines do
        local line = data.lines[i]
        if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
          pcall(TooltipUtil.SurfaceArgs, line)
        end
        lines[i] = line.leftText or ""
      end
      return lines
    end
  end
  if not scanTip then
    local ok, tip = pcall(CreateFrame, "GameTooltip", SCAN_TIP_NAME, nil, "GameTooltipTemplate")
    if not ok or not tip or not tip.SetMerchantItem then
      return nil
    end
    scanTip = tip
  end
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:ClearLines()
  if not pcall(scanTip.SetMerchantItem, scanTip, index) then
    return nil
  end
  local lines = {}
  for i = 1, scanTip:NumLines() do
    local region = _G[SCAN_TIP_NAME .. "TextLeft" .. i]
    lines[i] = region and region:GetText() or ""
  end
  scanTip:Hide()
  return lines
end

-- True if the merchant item `index` (with this link) is a recipe you already know.
function ns.IsKnownRecipe(index, link)
  if not link or not ns.IsRecipeLink(link) then
    return false
  end
  local cached = knownCache[link]
  if cached ~= nil then
    return cached
  end
  local lines = MerchantTooltipLines(index)
  if not lines then
    return false
  end
  local known = ns.LinesSayKnown(lines)
  if known or LinesComplete(lines) then
    knownCache[link] = known
  end
  return known
end

--------------------------------------------------------------------------------
-- Filters: the search words plus the "Unknown recipes" and "Usable" toggles
--------------------------------------------------------------------------------
function ns.MakeCriteria(text, unknownOnly, usableOnly)
  return {
    terms = ns.ParseQuery(text),
    unknownOnly = unknownOnly and true or false,
    usableOnly = usableOnly and true or false,
  }
end

-- False when nothing is typed and both toggles are off: the vendor window is left alone.
function ns.IsFiltering(criteria)
  return #criteria.terms > 0 or criteria.unknownOnly or criteria.usableOnly
end

-- The item must match the words AND every toggle that is on.
-- isKnown(item) is only called for recipes, and only when "Unknown recipes" is on.
function ns.ItemPasses(item, criteria, isKnown)
  if not ns.Matches(item, criteria.terms) then
    return false
  end
  if criteria.usableOnly and not item.isUsable then
    return false
  end
  if criteria.unknownOnly then
    if not item.isRecipe then
      return false
    end
    isKnown = isKnown or function(it)
      return ns.IsKnownRecipe(it.index, it.link)
    end
    if isKnown(item) then
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
-- Bag count shown on vendor item slots
--------------------------------------------------------------------------------
-- How many of the item you have in your bags and bank.
function ns.GetBagCount(link)
  if not (link and GetItemCount) then
    return 0
  end
  local ok, count = pcall(GetItemCount, link, true)
  return ok and tonumber(count) or 0
end

-- The text for the slot, or nil when it should be empty.
function ns.BagCountText(count, enabled)
  if not enabled or type(count) ~= "number" or count <= 0 then
    return nil
  end
  -- A backpack icon, so it isn't mistaken for Blizzard's "(5)" limited stock count.
  local icon = "|TInterface\\Buttons\\Button-Backpack-Up:12:12|t"
  if count > 9999 then
    return icon .. "9999+"
  end
  return icon .. count
end
