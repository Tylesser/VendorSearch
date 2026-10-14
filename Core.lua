local _, ns = ...

ns.defaults = {
  sortKey = "index",
  ascending = true,
  usableOnly = false,
  affordableOnly = false,
  shown = true,
  position = nil,
}

ns.PREFIX = "|cffffd700Tylesser - Vendor Search|r: "

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

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

local function ScanCosts(index)
  local costs = {}
  if not GetMerchantItemCostInfo then
    return costs
  end
  for c = 1, GetMerchantItemCostInfo(index) or 0 do
    local texture, value, link, currencyName = GetMerchantItemCostItem(index, c)
    if value and value > 0 then
      table.insert(costs, {
        texture = texture,
        value = value,
        name = currencyName or (link and link:match("%[(.-)%]")),
      })
    end
  end
  return costs
end

-- Returns every item of the open vendor (Merchant tab), in vendor order.
function ns.ScanMerchant()
  local items = {}
  for index = 1, GetMerchantNumItems() do
    local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost =
      GetMerchantItem(index)
    if name then
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
        costs = {},
      }
      if link then
        local _, _, quality, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
        item.quality = quality
        item.itemType = itemType
        item.itemSubType = itemSubType
        if equipLoc and equipLoc ~= "" then
          item.equipSlot = _G[equipLoc]
        end
      end
      if item.hasExtendedCost then
        item.costs = ScanCosts(index)
      end
      item.searchText = table.concat({
        name, item.itemType or "", item.itemSubType or "", item.equipSlot or "",
      }, " "):lower()
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

-- sortKey "index" keeps the vendor's own order.
function ns.SortItems(items, key, ascending)
  table.sort(items, function(a, b)
    local va, vb
    if key == "name" then
      va, vb = a.name:lower(), b.name:lower()
    elseif key == "price" then
      va, vb = a.price, b.price
    end
    if va == nil or va == vb then
      return a.index < b.index
    end
    if ascending then
      return va < vb
    end
    return va > vb
  end)
end

local GOLD = "|cffffd700g|r"
local SILVER = "|cffc7c7cfs|r"
local COPPER = "|cffeda55fc|r"

function ns.FormatMoney(amount, digitColor)
  digitColor = digitColor or "|cffffffff"
  amount = math.floor(amount + 0.5)
  local gold = math.floor(amount / 10000)
  local silver = math.floor(amount / 100) % 100
  local copper = amount % 100

  local function Part(n, suffix)
    return digitColor .. n .. "|r" .. suffix
  end

  local parts = {}
  if gold > 0 then
    table.insert(parts, Part(BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or gold, GOLD))
  end
  if silver > 0 then
    table.insert(parts, Part(silver, SILVER))
  end
  if copper > 0 or #parts == 0 then
    table.insert(parts, Part(copper, COPPER))
  end
  return table.concat(parts, " ")
end

function ns.FormatCost(item, money)
  local parts = {}
  if item.price > 0 then
    local color = money and item.price > money and "|cffff5050" or nil
    table.insert(parts, ns.FormatMoney(item.price, color))
  end
  for _, cost in ipairs(item.costs) do
    local icon = cost.texture and ("|T" .. cost.texture .. ":0|t") or ""
    table.insert(parts, "|cffffffff" .. cost.value .. "|r" .. icon)
  end
  if #parts == 0 then
    return "|cff40ff40Free|r"
  end
  return table.concat(parts, " ")
end
