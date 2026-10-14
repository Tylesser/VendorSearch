local addonName, ns = ...

local eventFrame = CreateFrame("Frame")

-- Item types/slots can arrive a moment after the vendor opens.
local refreshPending = false
local function RequestRefresh()
  if refreshPending or not ns.Filter:IsActive() then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    ns.Filter:Apply()
  end)
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
  end,
  MERCHANT_CLOSED = function()
    ns.Filter:Clear()
  end,
  GET_ITEM_INFO_RECEIVED = RequestRefresh,
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
  if not (MerchantFrame and MerchantFrame:IsShown()) then
    print(ns.PREFIX .. "talk to a vendor to search their items.")
    return
  end
  ns.Filter:Focus()
end
