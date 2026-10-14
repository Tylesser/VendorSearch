local _, ns = ...

ns.defaults = {
  boxOffset = nil,
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
