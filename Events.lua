local addonName, ns = ...

local eventFrame = CreateFrame("Frame")

local function MerchantOpen()
  return MerchantFrame and MerchantFrame:IsShown()
end

-- Item types/slots can arrive a moment after the vendor opens; the bag counts and
-- "Known" marks need the item data too.
local refreshPending = false
local function RequestRefresh()
  if refreshPending or not MerchantOpen() then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    ns.Filter:Apply()
  end)
end

-- Buying or using an item (e.g. learning a recipe) changes the bag counts and what is known.
local function InventoryChanged()
  if not MerchantOpen() then
    return
  end
  ns.ClearKnownCache()
  RequestRefresh()
end

function ns.PrintHelp()
  print(ns.PREFIX .. "search box on the vendor window. Commands:")
  print("  /vsearch: put the cursor in the search box")
  print("  /vsearch reset: move the search box back to its default place")
  print("  /vsearch feedback: get the link to report a bug or suggest an idea")
  print("  Found a bug or have an idea? Type /vsearch feedback.")
end

local handlers = {
  ADDON_LOADED = function(loadedName)
    if loadedName ~= addonName then
      return
    end
    VendorSearchDB = VendorSearchDB or {}
    for key, value in pairs(ns.defaults) do
      if VendorSearchDB[key] == nil then
        VendorSearchDB[key] = value
      end
    end
    ns.Filter:Create()
    ns.T.AddCompartment({ -- Retail and WoW Forever; skipped on clients without the addon menu
      text = "Tylesser - Vendor Search",
      onClick = ns.PrintHelp,
      tooltip = { "Search box on the vendor window.", "/vsearch for commands." },
    })
  end,
  MERCHANT_SHOW = function()
    ns.ClearKnownCache()
  end,
  MERCHANT_CLOSED = function()
    ns.Filter:Clear()
  end,
  GET_ITEM_INFO_RECEIVED = RequestRefresh,
  BAG_UPDATE_DELAYED = InventoryChanged,
  NEW_RECIPE_LEARNED = InventoryChanged,
  LEARNED_SPELL_IN_TAB = InventoryChanged,
}

for event in pairs(handlers) do
  pcall(eventFrame.RegisterEvent, eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  handlers[event](...)
end)

SLASH_VENDORSEARCH1 = "/vsearch"
SLASH_VENDORSEARCH2 = "/vendorsearch"
SlashCmdList.VENDORSEARCH = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "reset" then
    ns.Filter:ResetPosition()
    print(ns.PREFIX .. "search box moved back to its default place.")
    return
  end
  if msg == "feedback" then
    ns.T.ShowFeedback()
    return
  end
  if msg == "help" then
    ns.PrintHelp()
    return
  end
  if not MerchantOpen() then
    print(ns.PREFIX .. "talk to a vendor to search their items. Type /vsearch help for commands.")
    return
  end
  ns.Filter:Focus()
end
