local _, ns = ...

-- Filters the vendor window's own item grid. After Blizzard fills the page
-- (MerchantFrame_UpdateMerchantInfo), each slot is refilled with the matching
-- item and the button's ID is set to that item's real index, so Blizzard's
-- own click, tooltip, drag and buy handlers keep working unchanged.
local Filter = {}
ns.Filter = Filter

local box, fadeCheck, flipCheck, countText, emptyText
local originalNameColors = {}
local FADED_ALPHA = 0.25
local MAX_PAGES_LISTED = 5

local function PerPage()
  return MERCHANT_ITEMS_PER_PAGE or 10
end

local function Slot(i)
  local merchantButton = _G["MerchantItem" .. i]
  if not merchantButton then
    return nil
  end
  return {
    merchantButton = merchantButton,
    itemButton = _G["MerchantItem" .. i .. "ItemButton"] or merchantButton.ItemButton,
    name = _G["MerchantItem" .. i .. "Name"] or merchantButton.Name,
    nameFrame = _G["MerchantItem" .. i .. "NameFrame"] or merchantButton.NameFrame,
    money = _G["MerchantItem" .. i .. "MoneyFrame"] or merchantButton.MoneyFrame,
    altCurrency = _G["MerchantItem" .. i .. "AltCurrencyFrame"] or merchantButton.AltCurrencyFrame,
  }
end

local function Call(fn, ...)
  if fn then
    pcall(fn, ...)
  end
end

local function Tint(slot, r, g, b, slotR, slotG, slotB)
  Call(SetItemButtonNameFrameVertexColor, slot.merchantButton, r, g, b)
  Call(SetItemButtonSlotVertexColor, slot.merchantButton, slotR or r, slotG or g, slotB or b)
  Call(SetItemButtonTextureVertexColor, slot.itemButton, r, g, b)
  Call(SetItemButtonNormalTextureVertexColor, slot.itemButton, r, g, b)
end

local function SetMoneyColor(money, color)
  if SetMoneyFrameColorByFrame then
    Call(SetMoneyFrameColorByFrame, money, color)
  elseif SetMoneyFrameColor and money:GetName() then
    Call(SetMoneyFrameColor, money:GetName(), color)
  end
end

local function ClearSlot(slot)
  local itemButton = slot.itemButton
  itemButton.price, itemButton.hasItem, itemButton.name = nil, nil, nil
  itemButton.link, itemButton.extendedCost = nil, nil
  itemButton:Hide()
  Tint(slot, 0.5, 0.5, 0.5, 0.4, 0.4, 0.4)
  slot.name:SetText("")
  if slot.money then
    slot.money:Hide()
  end
  if slot.altCurrency then
    slot.altCurrency:Hide()
  end
end

-- Mirrors what MerchantFrame_UpdateMerchantInfo does for one slot.
local function FillSlot(i, slot, item)
  local index = item.index
  local itemButton = slot.itemButton
  local canAfford = CanAffordMerchantItem and CanAffordMerchantItem(index)

  slot.name:SetText(item.name)
  local color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
  if color and color.r then
    slot.name:SetTextColor(color.r, color.g, color.b)
  end
  Call(SetItemButtonCount, itemButton, item.stackCount)
  Call(SetItemButtonStock, itemButton, item.numAvailable)
  Call(SetItemButtonTexture, itemButton, item.icon)
  Call(SetItemButtonQuality, itemButton, item.quality, item.link)

  itemButton.name = item.name
  itemButton.link = item.link
  itemButton.texture = item.icon
  itemButton.extendedCost = item.hasExtendedCost or nil
  if item.hasExtendedCost and item.price <= 0 then
    itemButton.price = nil
  else
    itemButton.price = item.price
  end

  local altWidth = 0
  if item.hasExtendedCost and slot.altCurrency and MerchantFrame_UpdateAltCurrency then
    local ok, width = pcall(MerchantFrame_UpdateAltCurrency, index, i, canAfford)
    altWidth = ok and width or 0
    slot.altCurrency:ClearAllPoints()
    if item.price > 0 and slot.money then
      slot.altCurrency:SetPoint("LEFT", slot.money, "RIGHT", -14, 0)
    elseif slot.nameFrame then
      slot.altCurrency:SetPoint("BOTTOMLEFT", slot.nameFrame, "BOTTOMLEFT", 0, 31)
    end
    slot.altCurrency:Show()
  elseif slot.altCurrency then
    slot.altCurrency:Hide()
  end

  if slot.money then
    if item.price > 0 or not item.hasExtendedCost then
      if MoneyFrame_SetMaxDisplayWidth and MAX_MONEY_DISPLAY_WIDTH then
        Call(MoneyFrame_SetMaxDisplayWidth, slot.money, MAX_MONEY_DISPLAY_WIDTH - altWidth)
      end
      MoneyFrame_Update(slot.money, item.price)
      SetMoneyColor(slot.money, canAfford == false and "red" or nil)
      slot.money:Show()
    else
      slot.money:Hide()
    end
  end

  if item.numAvailable == 0 then
    if item.isUsable then
      Tint(slot, 0.5, 0.5, 0.5)
    else
      Tint(slot, 0.5, 0, 0)
    end
  elseif not item.isUsable then
    Tint(slot, 1, 0, 0)
  else
    Tint(slot, 1, 1, 1)
  end

  itemButton.hasItem = true
  itemButton:SetID(index)
  itemButton:Show()
end

local function RememberNameColor(i, slot)
  if not originalNameColors[i] then
    originalNameColors[i] = {slot.name:GetTextColor()}
  end
end

local function RestoreNameColors()
  for i, rgb in pairs(originalNameColors) do
    local slot = Slot(i)
    if slot then
      slot.name:SetTextColor(rgb[1], rgb[2], rgb[3])
    end
  end
end

-- Fade mode changes slot alpha, which Blizzard never resets itself.
local function ResetAlpha()
  for i = 1, PerPage() do
    local slot = Slot(i)
    if slot then
      slot.merchantButton:SetAlpha(1)
    end
  end
end

local function PluralMatches(count)
  return count == 1 and "1 match" or (count .. " matches")
end

local function Wanted(item, terms)
  return ns.Matches(item, terms) and (not Filter.flipsOnly or item.isFlip)
end

-- The match count goes on the vendor's own page line under the grid.
local function SetStatus(text)
  if MerchantPageText then
    MerchantPageText:SetText(text)
    MerchantPageText:Show()
  elseif countText then
    countText:SetText(text)
  end
end

local function PageList(pages)
  local listed = {}
  for n = 1, math.min(#pages, MAX_PAGES_LISTED) do
    listed[n] = pages[n]
  end
  local text = table.concat(listed, ", ")
  if #pages > MAX_PAGES_LISTED then
    text = text .. "..."
  end
  return text
end

local function PageNumber(page, pages)
  return (MERCHANT_PAGE_NUMBER or "Page %s of %s"):format(page, pages)
end

-- Fade mode: keep the vendor's own pages, fade the items that don't match.
local function ApplyFade(items, terms)
  local perPage = PerPage()
  local matched, pagesWithMatch, count = {}, {}, 0
  for _, item in ipairs(items) do
    if Wanted(item, terms) then
      matched[item.index] = true
      count = count + 1
      local page = math.ceil(item.index / perPage)
      if pagesWithMatch[#pagesWithMatch] ~= page then
        table.insert(pagesWithMatch, page)
      end
    end
  end

  for i = 1, perPage do
    local slot = Slot(i)
    if slot and slot.itemButton and slot.itemButton:IsShown() then
      slot.merchantButton:SetAlpha(matched[slot.itemButton:GetID()] and 1 or FADED_ALPHA)
    end
  end

  Filter.firstMatchPage = pagesWithMatch[1]
  local text = PluralMatches(count)
  local vendorPages = math.ceil(#items / perPage)
  if vendorPages > 1 then
    if count > 0 then
      text = text .. " on page " .. PageList(pagesWithMatch)
    end
    text = PageNumber(MerchantFrame.page, vendorPages) .. " - " .. text
  end
  SetStatus(text)
  emptyText:SetShown(count == 0)
end

local function UpdatePaging(page, pages, total)
  local multiple = pages > 1
  local text = PluralMatches(total)
  if multiple then
    text = text .. " - " .. PageNumber(page, pages)
  end
  SetStatus(text)
  if MerchantPrevPageButton then
    MerchantPrevPageButton:SetShown(multiple)
    MerchantPrevPageButton:SetEnabled(page > 1)
  end
  if MerchantNextPageButton then
    MerchantNextPageButton:SetShown(multiple)
    MerchantNextPageButton:SetEnabled(page < pages)
  end
end

-- Hide mode: refill the grid with only the matching items.
local function ApplyHide(items, terms)
  local results = {}
  for _, item in ipairs(items) do
    if Wanted(item, terms) then
      table.insert(results, item)
    end
  end

  local perPage = PerPage()
  local pages = math.max(1, math.ceil(#results / perPage))
  MerchantFrame.page = math.min(math.max(MerchantFrame.page or 1, 1), pages)
  local first = (MerchantFrame.page - 1) * perPage

  for i = 1, perPage do
    local slot = Slot(i)
    if slot and slot.itemButton and slot.name then
      RememberNameColor(i, slot)
      local item = results[first + i]
      if item then
        FillSlot(i, slot, item)
      else
        ClearSlot(slot)
      end
    end
  end

  UpdatePaging(MerchantFrame.page, pages, #results)
  Filter.firstMatchPage = #results > 0 and 1 or nil
  emptyText:SetShown(#results == 0)
end

--------------------------------------------------------------------------------
-- Flips: vendor items that sell for clearly more on the auction house
--------------------------------------------------------------------------------
local flipMarks = {}
local lastItems = {}

local function ShortMoney(copper)
  if copper >= 10000 then
    return math.floor(copper / 10000) .. "g"
  elseif copper >= 100 then
    return math.floor(copper / 100) .. "s"
  end
  return copper .. "c"
end

local function FlipMark(i, slot)
  local mark = flipMarks[i]
  if not mark then
    mark = {}
    local width = slot.itemButton:GetWidth()
    if not width or width == 0 then
      width = 37
    end
    mark.border = slot.itemButton:CreateTexture(nil, "OVERLAY")
    mark.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    mark.border:SetBlendMode("ADD")
    mark.border:SetVertexColor(0.2, 1, 0.35)
    mark.border:SetSize(width * 1.8, width * 1.8)
    mark.border:SetPoint("CENTER", slot.itemButton, "CENTER")
    mark.text = slot.merchantButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mark.text:SetPoint("BOTTOMRIGHT", slot.merchantButton, "BOTTOMRIGHT", -2, 3)
    mark.text:SetTextColor(0.25, 1, 0.4)
    flipMarks[i] = mark
  end
  return mark
end

local function HideFlipMarks()
  for _, mark in pairs(flipMarks) do
    mark.border:Hide()
    mark.text:Hide()
  end
end

local function UpdateFlipMarks(items)
  wipe(lastItems)
  for _, item in ipairs(items) do
    lastItems[item.index] = item
  end
  for i = 1, PerPage() do
    local slot = Slot(i)
    if slot and slot.itemButton then
      local item = slot.itemButton:IsShown() and lastItems[slot.itemButton:GetID()]
      if item and item.isFlip then
        local mark = FlipMark(i, slot)
        mark.text:SetText("+" .. ShortMoney(item.flipProfit))
        mark.border:Show()
        mark.text:Show()
      elseif flipMarks[i] then
        flipMarks[i].border:Hide()
        flipMarks[i].text:Hide()
      end
    end
  end
end

function Filter:IsActive()
  return box ~= nil and MerchantFrame:IsShown()
end

-- Called after Blizzard has filled the current merchant page.
function Filter:Apply()
  if not (box and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1) then
    return
  end
  ResetAlpha()
  Filter.firstMatchPage = nil
  Filter.flipsOnly = VendorSearchDB.flipsOnly and ns.HasAuctionator()

  local items = ns.ScanMerchant()
  local terms = ns.ParseQuery(box:GetText())
  if #terms > 0 or Filter.flipsOnly then
    if VendorSearchDB.fade then
      ApplyFade(items, terms)
    else
      ApplyHide(items, terms)
    end
  else
    if countText then
      countText:SetText("")
    end
    emptyText:Hide()
  end
  UpdateFlipMarks(items)
end

-- Re-run Blizzard's update (our hook then filters it) from the first page.
function Filter:Refresh(resetPage)
  if not (MerchantFrame and MerchantFrame:IsShown()) then
    return
  end
  RestoreNameColors()
  if resetPage then
    MerchantFrame.page = 1
  end
  if MerchantFrame_Update then
    MerchantFrame_Update()
    -- In fade mode, turn to the first page that has a match.
    if resetPage and VendorSearchDB.fade and Filter.firstMatchPage
      and Filter.firstMatchPage ~= MerchantFrame.page then
      MerchantFrame.page = Filter.firstMatchPage
      MerchantFrame_Update()
    end
  end
end

function Filter:UpdateVisibility()
  if not box then
    return
  end
  local onMerchantTab = MerchantFrame.selectedTab == 1
  box:SetShown(onMerchantTab)
  fadeCheck:SetShown(onMerchantTab)
  if flipCheck then
    flipCheck:SetShown(onMerchantTab)
  end
  if countText then
    countText:SetShown(onMerchantTab)
  end
  if not onMerchantTab then
    emptyText:Hide()
    ResetAlpha()
    HideFlipMarks()
  end
end

--------------------------------------------------------------------------------
-- Search box
--------------------------------------------------------------------------------
-- Classic-style merchant art has a wide frame with transparent padding.
local function DefaultOffset()
  if MerchantFrame:GetWidth() >= 370 then
    return 74, -44
  end
  return 64, -32
end

local function ApplyBoxPosition()
  local x, y
  if VendorSearchDB.boxOffset then
    x, y = VendorSearchDB.boxOffset[1], VendorSearchDB.boxOffset[2]
  else
    x, y = DefaultOffset()
  end
  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", x, y)
end

function Filter:ResetPosition()
  VendorSearchDB.boxOffset = nil
  if box then
    ApplyBoxPosition()
  end
end

function Filter:Focus()
  if box and box:IsVisible() then
    box:SetFocus()
  end
end

function Filter:Clear()
  if box and box:GetText() ~= "" then
    box:SetText("")
  end
  RestoreNameColors()
  ResetAlpha()
  HideFlipMarks()
  if emptyText then
    emptyText:Hide()
  end
end

function Filter:Create()
  if box or not MerchantFrame then
    return
  end

  local ok, created = pcall(CreateFrame, "EditBox", "VendorSearchBox", MerchantFrame, "SearchBoxTemplate")
  if ok then
    box = created
  else
    box = CreateFrame("EditBox", "VendorSearchBox", MerchantFrame, "InputBoxTemplate")
  end
  box:SetSize(120, 20)
  box:SetAutoFocus(false)
  box:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
  if box.Instructions then
    box.Instructions:SetText("Search items")
  end
  ApplyBoxPosition()

  box:HookScript("OnTextChanged", function()
    Filter:Refresh(true)
  end)
  box:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    if Filter.firstMatchPage and Filter.firstMatchPage ~= MerchantFrame.page then
      MerchantFrame.page = Filter.firstMatchPage
      MerchantFrame_Update()
    end
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  box:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Vendor Search", 1, 0.82, 0)
    GameTooltip:AddLine("Type part of an item's name, type or slot,", 1, 1, 1)
    GameTooltip:AddLine("e.g. vial, recipe cooking, head.", 1, 1, 1)
    GameTooltip:AddLine("Alt-drag to move this box.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  box:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Alt-drag to move the box; position is saved relative to the vendor window.
  box:SetMovable(true)
  box:RegisterForDrag("LeftButton")
  box:SetScript("OnDragStart", function(self)
    if IsAltKeyDown() then
      self:StartMoving()
    end
  end)
  box:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    local x = self:GetLeft() - MerchantFrame:GetLeft()
    local y = self:GetTop() - MerchantFrame:GetTop()
    VendorSearchDB.boxOffset = {x, y}
    ApplyBoxPosition()
  end)

  local function CreateToggle(label, dbKey, anchor, title, line1, line2)
    local check = CreateFrame("CheckButton", nil, MerchantFrame, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetFrameLevel(box:GetFrameLevel())
    check:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    local text = check.Text or check.text
    if not text then
      text = check:CreateFontString(nil, "OVERLAY")
      text:SetPoint("LEFT", check, "RIGHT", 1, 0)
    end
    text:SetFontObject("GameFontHighlightSmall")
    text:SetText(label)
    check.label = text
    check:SetChecked(VendorSearchDB[dbKey])
    check:SetScript("OnClick", function(self)
      VendorSearchDB[dbKey] = self:GetChecked() and true or false
      Filter:Refresh(true)
    end)
    check:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(title, 1, 0.82, 0)
      GameTooltip:AddLine(line1, 1, 1, 1)
      GameTooltip:AddLine(line2, 1, 1, 1)
      GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    return check
  end

  fadeCheck = CreateToggle("Fade", "fade", box, "Fade instead of hide",
    "Keep the vendor's normal pages and fade the items",
    "that don't match. Enter turns to the first page with a match.")

  if ns.HasAuctionator() then
    flipCheck = CreateToggle("Flips", "flipsOnly", fadeCheck.label, "Flips only",
      "Only items that sell for at least 10% and 1 silver more on the",
      "auction house (after the 5% cut). Uses Auctionator prices.")
  end

  if not MerchantPageText then
    countText = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("LEFT", (flipCheck or fadeCheck).label, "RIGHT", 6, 0)
  end

  emptyText = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  emptyText:SetText("No items match your search.")
  if MerchantItem1 then
    emptyText:SetPoint("TOPLEFT", MerchantItem1, "TOPLEFT", 8, -12)
  else
    emptyText:SetPoint("CENTER", MerchantFrame, "CENTER")
  end
  emptyText:Hide()

  -- Flip details in the vendor item tooltip
  if GameTooltip.SetMerchantItem then
    hooksecurefunc(GameTooltip, "SetMerchantItem", function(tooltip, index)
      local item = lastItems[index]
      if item and item.isFlip then
        local profit = GetCoinTextureString and GetCoinTextureString(item.flipProfit) or ShortMoney(item.flipProfit)
        tooltip:AddLine("Vendor Search: flip, +" .. profit .. " on the AH after the 5% cut", 0.25, 1, 0.4)
        tooltip:Show()
      end
    end)
  end
  ns.CallAuctionator("RegisterForDBUpdate", function()
    Filter:Apply()
  end)

  hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
    Filter:Apply()
  end)
  if MerchantFrame_Update then
    hooksecurefunc("MerchantFrame_Update", function()
      Filter:UpdateVisibility()
    end)
  end
end
