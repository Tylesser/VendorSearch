local addonName, ns = ...

local eventFrame = CreateFrame("Frame")

local refreshPending = false
local function RequestRefresh()
  if refreshPending or not ns.UI:IsAttached() then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    ns.UI:Refresh()
  end)
end

local function OnMerchantShow()
  if MerchantFrame and MerchantFrame:IsShown() then
    ns.UI:Attach(MerchantFrame)
  end
end

local function OnMerchantHide()
  ns.UI:Detach()
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
    if MerchantFrame then
      MerchantFrame:HookScript("OnShow", OnMerchantShow)
      MerchantFrame:HookScript("OnHide", OnMerchantHide)
    end
  end,
  MERCHANT_SHOW = function()
    C_Timer.After(0, OnMerchantShow)
  end,
  MERCHANT_CLOSED = OnMerchantHide,
}

local refreshEvents = {
  "MERCHANT_UPDATE",
  "MERCHANT_FILTER_ITEM_UPDATE",
  "GET_ITEM_INFO_RECEIVED",
  "PLAYER_MONEY",
  "BAG_UPDATE_DELAYED",
}

-- Some events only exist on some clients; registering an unknown one errors.
local function SafeRegister(event)
  pcall(eventFrame.RegisterEvent, eventFrame, event)
end

for event in pairs(handlers) do
  SafeRegister(event)
end
for _, event in ipairs(refreshEvents) do
  SafeRegister(event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local handler = handlers[event]
  if handler then
    handler(...)
  else
    RequestRefresh()
  end
end)

SLASH_VENDORSEARCH1 = "/vsearch"
SLASH_VENDORSEARCH2 = "/vendorsearch"
SlashCmdList.VENDORSEARCH = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "reset" then
    ns.UI:ResetPosition()
    print(ns.PREFIX .. "panel docked to the vendor window again.")
    return
  end
  if not ns.UI:IsAttached() then
    print(ns.PREFIX .. "talk to a vendor to search their items.")
    return
  end
  if VendorSearchDB.shown then
    ns.UI:FocusSearch()
  else
    VendorSearchDB.shown = true
    ns.UI:UpdateVisibility()
    ns.UI:FocusSearch()
  end
end
