local _, ns = ...

-- The "Unknown", "Usable" and "Can afford" toggles are not saved: they reset when the vendor closes,
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
local GetItemFamily = (C_Item and C_Item.GetItemFamily) or GetItemFamily
local GetItemMaxStackSize = C_Item and C_Item.GetItemMaxStackSize
local RECIPE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9
local MISC_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Miscellaneous) or 15
local BATTLEPET_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Battlepet) or 17
local MISC = Enum and Enum.ItemMiscellaneousSubclass
local PET_SUBCLASS = (MISC and MISC.CompanionPet) or 2
local MOUNT_SUBCLASS = (MISC and MISC.Mount) or 5

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
    item.kind = ns.CollectibleKind(link)
    item.isRecipe = item.kind == "recipe"
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
-- Mounts and pets you already have: asked by item ID from the mount and pet
-- journals; the tooltip's "Already known" line where a client has no journal
--------------------------------------------------------------------------------
-- A value is only used when it is a plain number / boolean (never a secret).
local function Number(value)
  local ok, result = pcall(function()
    return type(value) == "number" and value + 0 == value and value or nil
  end)
  return ok and result or nil
end

local function Boolean(value)
  local ok, result = pcall(function()
    if value == true then
      return true
    elseif value == false then
      return false
    end
    return nil
  end)
  if ok then
    return result
  end
  return nil
end

-- itemID, classID, subclassID of an item link.
local function ItemClass(link)
  local itemID, classID, subclassID
  if GetItemInfoInstant then
    local ok, id, _, _, _, _, class, subclass = pcall(GetItemInfoInstant, link)
    if ok then
      itemID, classID, subclassID = id, class, subclass
    end
  end
  if classID == nil and GetItemInfo then
    local ok, _, _, _, _, _, _, _, _, _, _, _, class, subclass = pcall(GetItemInfo, link)
    if ok then
      classID, subclassID = class, subclass
    end
  end
  itemID = Number(itemID) or tonumber(tostring(link):match("item:(%d+)"))
  return itemID, classID, subclassID
end

-- The mount an item teaches (mount journal), or nil.
local function MountOf(itemID)
  local journal = C_MountJournal
  if not (itemID and journal and journal.GetMountFromItem) then
    return nil
  end
  local ok, mountID = pcall(journal.GetMountFromItem, itemID)
  return ok and Number(mountID) or nil
end

-- The pet species an item teaches (pet journal), or nil.
local function SpeciesOf(itemID)
  local journal = C_PetJournal
  if not (itemID and journal and journal.GetPetInfoByItemID) then
    return nil
  end
  local ok, _, _, _, _, _, _, _, _, _, _, _, _, speciesID = pcall(journal.GetPetInfoByItemID, itemID)
  return ok and Number(speciesID) or nil
end

-- "recipe", "mount", "pet" or nil: the things a vendor sells that you learn or collect once.
function ns.CollectibleKind(link)
  if not link then
    return nil
  end
  local itemID, classID, subclassID = ItemClass(link)
  if classID == RECIPE_CLASS then
    return "recipe"
  end
  if (classID == MISC_CLASS and subclassID == MOUNT_SUBCLASS) or MountOf(itemID) then
    return "mount"
  end
  if classID == BATTLEPET_CLASS or (classID == MISC_CLASS and subclassID == PET_SUBCLASS) or SpeciesOf(itemID) then
    return "pet"
  end
  return nil
end

-- true / false from the journals, nil when the journal can't tell (then the tooltip decides).
local function JournalKnows(kind, link)
  local itemID = ItemClass(link)
  if kind == "mount" then
    local mountID = MountOf(itemID)
    if mountID and C_MountJournal.GetMountInfoByID then
      local ok, _, _, _, _, _, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
      if ok then
        return Boolean(isCollected)
      end
    end
  elseif kind == "pet" then
    local speciesID = SpeciesOf(itemID)
    if speciesID and C_PetJournal.GetNumCollectedInfo then
      local ok, owned = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
      owned = ok and Number(owned)
      if owned then
        return owned > 0
      end
    end
  end
  return nil
end

-- True if the merchant item `index` is a recipe you know, or a mount or pet you already have.
function ns.IsKnownItem(index, link)
  local kind = ns.CollectibleKind(link)
  if not kind then
    return false
  end
  if kind == "recipe" then
    return ns.IsKnownRecipe(index, link)
  end
  local cached = knownCache[link]
  if cached ~= nil then
    return cached
  end
  local known = JournalKnows(kind, link)
  if known == nil then
    local lines = MerchantTooltipLines(index)
    if not lines then
      return false
    end
    known = ns.LinesSayKnown(lines)
    if not (known or LinesComplete(lines)) then
      return known
    end
  end
  knownCache[link] = known
  return known
end

--------------------------------------------------------------------------------
-- Filters: the search words plus the "Unknown", "Usable" and "Can afford" toggles
--------------------------------------------------------------------------------
function ns.MakeCriteria(text, unknownOnly, usableOnly, affordOnly)
  return {
    terms = ns.ParseQuery(text),
    unknownOnly = unknownOnly and true or false,
    usableOnly = usableOnly and true or false,
    affordOnly = affordOnly and true or false,
  }
end

-- False when nothing is typed and every toggle is off: the vendor window is left alone.
function ns.IsFiltering(criteria)
  return #criteria.terms > 0 or criteria.unknownOnly or criteria.usableOnly or criteria.affordOnly
end

-- The item must match the words AND every toggle that is on.
-- isKnown(item) is only called for recipes, mounts and pets, and only when "Unknown" is on;
-- canAfford(item) only when "Can afford" is on.
function ns.ItemPasses(item, criteria, isKnown, canAfford)
  if not ns.Matches(item, criteria.terms) then
    return false
  end
  if criteria.usableOnly and not item.isUsable then
    return false
  end
  if criteria.unknownOnly then
    if not (item.kind or item.isRecipe) then
      return false
    end
    isKnown = isKnown or function(it)
      return ns.IsKnownItem(it.index, it.link)
    end
    if isKnown(item) then
      return false
    end
  end
  if criteria.affordOnly and not (canAfford or ns.CanAfford)(item) then
    return false
  end
  return true
end

--------------------------------------------------------------------------------
-- Can afford: gold and the items or currency an item costs
--------------------------------------------------------------------------------
-- What you have of one extra cost (an item in your bags, or a currency), or nil when unknown.
local function CostOwned(link, currencyName)
  if not link then
    return nil
  end
  if currencyName then
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfoFromLink then
      local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfoFromLink, link)
      return ok and type(info) == "table" and Number(info.quantity) or nil
    end
    return nil
  end
  if not GetItemCount then
    return nil
  end
  local ok, count = pcall(GetItemCount, link)
  return ok and Number(count) or nil
end

-- Your own sum, for clients where CanAffordMerchantItem gives no answer. Unknown costs don't hide the item.
function ns.CostsCovered(item)
  local money = GetMoney and Number(GetMoney())
  if money and item.price > 0 and money < item.price then
    return false
  end
  if item.hasExtendedCost and GetMerchantItemCostInfo and GetMerchantItemCostItem then
    local ok, count = pcall(GetMerchantItemCostInfo, item.index)
    count = ok and Number(count) or 0
    for i = 1, count do
      local okCost, _, value, link, currencyName = pcall(GetMerchantItemCostItem, item.index, i)
      value = okCost and Number(value)
      if value then
        local owned = CostOwned(link, currencyName)
        if owned and owned < value then
          return false
        end
      end
    end
  end
  return true
end

-- True if you can buy the item now: it isn't sold out and you have the gold and every extra cost.
function ns.CanAfford(item)
  if item.numAvailable == 0 then
    return false
  end
  if CanAffordMerchantItem then
    local ok, result = pcall(CanAffordMerchantItem, item.index)
    if ok then
      local can = Boolean(result)
      if can ~= nil then
        return can
      end
    end
  end
  return ns.CostsCovered(item)
end

--------------------------------------------------------------------------------
-- Buying several stacks at once (Alt-click a stackable item sold for gold)
--------------------------------------------------------------------------------
-- The first value of a protected call, or nil.
local function First(fn, ...)
  if not fn then
    return nil
  end
  local ok, value = pcall(fn, ...)
  return ok and value or nil
end

-- How many of the item still fit in your bags: free slots of bags that take it,
-- plus the room left on stacks you already carry. nil when the client can't tell.
function ns.BagRoom(link)
  local container = C_Container
  if not (link and container and container.GetContainerNumFreeSlots) then
    return nil
  end
  local itemID = ItemClass(link)
  local stack = Number(First(GetItemMaxStackSize, link))
  if not stack and GetItemInfo then
    local ok, _, _, _, _, _, _, _, maxStack = pcall(GetItemInfo, link)
    stack = ok and Number(maxStack) or nil
  end
  if not stack or stack < 1 then
    return nil
  end
  local family = Number(First(GetItemFamily, link)) or 0
  local room = 0
  for bag = 0, NUM_BAG_SLOTS or 4 do
    local ok, free, bagFamily = pcall(container.GetContainerNumFreeSlots, bag)
    free, bagFamily = ok and Number(free) or 0, ok and Number(bagFamily) or 0
    local takesIt = bagFamily == 0 or (bit and bit.band and bit.band(family, bagFamily) ~= 0) or false
    if takesIt then
      room = room + free * stack
      local slots = container.GetContainerItemInfo and Number(First(container.GetContainerNumSlots, bag)) or 0
      for slot = 1, slots do
        local info = First(container.GetContainerItemInfo, bag, slot)
        if type(info) == "table" and Number(info.itemID) == itemID then
          local count = Number(info.stackCount)
          if count and count < stack then
            room = room + stack - count
          end
        end
      end
    end
  end
  return room
end

-- The most one Buy can get. info: stackCount (items per vendor unit), price (copper per unit),
-- money, numAvailable (units, -1 = no limit), room (items that fit, nil = unknown).
-- Returns the items and what limits them: "money", "stock", "room" or nil.
ns.BULK_MAX = 2000

function ns.BuyLimit(info)
  local unit = math.max(1, info.stackCount or 1)
  local best, reason = math.floor(ns.BULK_MAX / unit) * unit, nil
  local function Cap(items, why)
    items = math.floor(items / unit) * unit
    if items < best then
      best, reason = items, why
    end
  end
  if (info.price or 0) > 0 and info.money then
    Cap(math.floor(info.money / info.price) * unit, "money")
  end
  if info.numAvailable and info.numAvailable >= 0 then
    Cap(info.numAvailable * unit, "stock")
  end
  if info.room then
    Cap(info.room, "room")
  end
  return math.max(0, best), reason
end

-- The purchases for `quantity` items: each at most `maxStack` items (the vendor's own
-- limit per click), in whole vendor units. Returns the list, the items and the cost.
function ns.BuyPlan(quantity, info)
  local unit = math.max(1, info.stackCount or 1)
  local perPurchase = math.max(unit, math.floor((info.maxStack or unit) / unit) * unit)
  local total = math.floor(math.min(math.max(0, quantity or 0), (ns.BuyLimit(info))) / unit) * unit
  local plan, left = {}, total
  while left > 0 do
    local chunk = math.min(left, perPurchase)
    plan[#plan + 1] = chunk
    left = left - chunk
  end
  return plan, total, total / unit * (info.price or 0)
end

-- What the open vendor's item `index` needs for a Buy window, or nil when it can't be
-- bought in bulk (not stackable, or it costs items or currency: those keep Blizzard's
-- own confirmation, one purchase at a time).
function ns.BulkInfo(index)
  local item = ns.ReadMerchantItem(index)
  if not item or not item.link or item.hasExtendedCost or not item.isPurchasable or item.numAvailable == 0 then
    return nil
  end
  local maxStack = Number(First(GetMerchantItemMaxStack, index))
  if not maxStack or maxStack <= 1 then
    return nil
  end
  return {
    index = index,
    link = item.link,
    name = item.name,
    icon = item.icon,
    stackCount = math.max(1, item.stackCount),
    maxStack = maxStack,
    price = item.price,
    money = Number(First(GetMoney)) or 0,
    numAvailable = item.numAvailable,
    room = ns.BagRoom(item.link),
  }
end

-- Buys `quantity` items of the vendor item `index`, one stack per purchase. Only called from
-- the Buy button. Returns the items asked for and the purchases made (0, 0 when nothing was bought).
function ns.BuyBulk(index, link, quantity)
  if not (BuyMerchantItem and GetMerchantItemLink and GetMerchantItemLink(index) == link) then
    return 0, 0
  end
  local info = ns.BulkInfo(index)
  if not info then
    return 0, 0
  end
  local plan, total = ns.BuyPlan(quantity, info)
  for _, chunk in ipairs(plan) do
    BuyMerchantItem(index, chunk)
  end
  return total, #plan
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
