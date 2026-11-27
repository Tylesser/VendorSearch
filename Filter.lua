local _, ns = ...
local L = ns.L

-- Filters the vendor window's own item grid. After Blizzard fills the page
-- (MerchantFrame_UpdateMerchantInfo), each slot is refilled with the matching
-- item and the button's ID is set to that item's real index, so Blizzard's
-- own click, tooltip, drag and buy handlers keep working unchanged.
local Filter = {}
ns.Filter = Filter

local box, fadeCheck, countText, emptyText
local unknownCheck, usableCheck, bagsCheck
local originalNameColors = {}
local slotMarks = {}
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
  return count == 1 and L["1 match"] or L["%d matches"]:format(count)
end

-- Session-only toggles (reset when the vendor closes).
Filter.unknownOnly = false
Filter.usableOnly = false

function Filter:Criteria()
  return ns.MakeCriteria(box and box:GetText() or "", Filter.unknownOnly, Filter.usableOnly)
end

-- Fade mode: keep the vendor's own pages, fade the items that don't match.
local function ApplyFade(criteria)
  local perPage = PerPage()
  local matched, pagesWithMatch, count = {}, {}, 0
  for _, item in ipairs(ns.ScanMerchant()) do
    if ns.ItemPasses(item, criteria) then
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
  if count > 0 and GetMerchantNumItems() > perPage then
    local listed = {}
    for n = 1, math.min(#pagesWithMatch, MAX_PAGES_LISTED) do
      listed[n] = pagesWithMatch[n]
    end
    text = text .. L[" - page %s"]:format(table.concat(listed, ", "))
    if #pagesWithMatch > MAX_PAGES_LISTED then
      text = text .. "..."
    end
  end
  countText:SetText(text)
  emptyText:SetShown(count == 0)
end

local function UpdatePaging(page, pages, total)
  local multiple = total > PerPage()
  if MerchantPageText then
    MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER or "Page %s of %s", page, pages)
    MerchantPageText:SetShown(multiple)
  end
  if MerchantPrevPageButton then
    MerchantPrevPageButton:SetShown(multiple)
    MerchantPrevPageButton:SetEnabled(page > 1)
  end
  if MerchantNextPageButton then
    MerchantNextPageButton:SetShown(multiple)
    MerchantNextPageButton:SetEnabled(page < pages)
  end
end

--------------------------------------------------------------------------------
-- Slot marks: bag count "(3)" and "Known" on learned recipes
--------------------------------------------------------------------------------
-- Our own font strings on each item button. They are refreshed from the button's current ID
-- after every update, so a slot reused for another item never keeps an old mark.
local function Marks(i, slot)
  local marks = slotMarks[i]
  if not marks then
    local itemButton = slot.itemButton
    local bags = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    bags:SetDrawLayer("OVERLAY", 7)
    bags:SetPoint("TOPRIGHT", itemButton, "TOPRIGHT", 0, -2)
    bags:SetJustifyH("RIGHT")
    bags:SetTextColor(0.55, 0.8, 1)
    bags:Hide()
    local known = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    known:SetDrawLayer("OVERLAY", 7)
    known:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", 2, 2)
    known:SetText(L["Known"])
    known:SetTextColor(0.3, 1, 0.3)
    known:Hide()
    marks = { bags = bags, known = known }
    slotMarks[i] = marks
  end
  return marks
end

local function HideMarks()
  for _, marks in pairs(slotMarks) do
    marks.bags:SetText("")
    marks.bags:Hide()
    marks.known:Hide()
  end
end

function Filter:UpdateMarks()
  if not (box and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1) then
    HideMarks()
    return
  end
  for i = 1, PerPage() do
    local slot = Slot(i)
    if slot and slot.itemButton then
      local marks = Marks(i, slot)
      local bagText, known
      if slot.itemButton:IsShown() then
        local index = slot.itemButton:GetID()
        local link = index and index > 0 and GetMerchantItemLink(index)
        if link then
          bagText = ns.BagCountText(ns.GetBagCount(link), VendorSearchDB.bagCount)
          known = ns.IsKnownRecipe(index, link)
        end
      end
      marks.bags:SetText(bagText or "")
      marks.bags:SetShown(bagText ~= nil)
      marks.known:SetShown(known and true or false)
    end
  end
end

function Filter:IsActive()
  return box ~= nil and ns.IsFiltering(Filter:Criteria())
end

-- Filters the page Blizzard has just filled (only when a search or toggle is on).
local function ApplyFilter()
  ResetAlpha()
  Filter.firstMatchPage = nil
  local criteria = Filter:Criteria()
  if not ns.IsFiltering(criteria) then
    countText:SetText("")
    emptyText:Hide()
    return
  end
  if VendorSearchDB.fade then
    ApplyFade(criteria)
    return
  end

  local results = {}
  for _, item in ipairs(ns.ScanMerchant()) do
    if ns.ItemPasses(item, criteria) then
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
  countText:SetText(PluralMatches(#results))
  emptyText:SetShown(#results == 0)
end

-- Called after Blizzard has filled the current merchant page.
function Filter:Apply()
  if not (box and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1) then
    return
  end
  ApplyFilter()
  Filter:UpdateMarks()
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
  unknownCheck:SetShown(onMerchantTab)
  usableCheck:SetShown(onMerchantTab)
  bagsCheck:SetShown(onMerchantTab)
  countText:SetShown(onMerchantTab)
  if not onMerchantTab then
    emptyText:Hide()
    ResetAlpha()
    HideMarks()
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

-- On vendor close: empty the search and turn the session toggles off.
function Filter:Clear()
  Filter.unknownOnly, Filter.usableOnly = false, false
  if unknownCheck then
    unknownCheck:SetChecked(false)
    usableCheck:SetChecked(false)
  end
  if box and box:GetText() ~= "" then
    box:SetText("")
  end
  RestoreNameColors()
  ResetAlpha()
  HideMarks()
  ns.ClearKnownCache()
  if emptyText then
    emptyText:Hide()
  end
end

-- A small check box for the row under the search box.
local function SmallCheck(label, title, lines, onClick)
  local check = ns.T.Check(MerchantFrame, label, "GameFontHighlightSmall")
  check:SetSize(16, 16)
  local tick = check:GetCheckedTexture()
  if tick then
    tick:SetSize(18, 18)
  end
  check:SetFrameLevel(box:GetFrameLevel())
  local width = check.label:GetStringWidth()
  check:SetHitRectInsets(0, -((width and width > 0) and math.ceil(width) + 4 or 40), 0, 0)
  check:SetScript("OnClick", onClick)
  check:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title, 1, 0.82, 0)
    for _, line in ipairs(lines) do
      GameTooltip:AddLine(line, 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  check:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  return check
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
  box:SetSize(140, 20)
  box:SetAutoFocus(false)
  box:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
  ns.T.EditBox(box)
  if box.Instructions then
    box.Instructions:SetText(L["Search items"])
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
    GameTooltip:SetText(L["Vendor Search"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Type part of an item's name, type or slot,"], 1, 1, 1)
    GameTooltip:AddLine(L["e.g. vial, recipe cooking, head."], 1, 1, 1)
    GameTooltip:AddLine(L["Alt-drag to move this box."], 0.6, 0.6, 0.6)
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

  fadeCheck = ns.T.Check(MerchantFrame, L["Fade"], "GameFontHighlightSmall")
  fadeCheck:SetFrameLevel(box:GetFrameLevel())
  fadeCheck:SetPoint("LEFT", box, "RIGHT", 6, 0)
  fadeCheck:SetHitRectInsets(0, -30, 0, 0)
  local fadeLabel = fadeCheck.label
  fadeCheck:SetChecked(VendorSearchDB.fade)
  fadeCheck:SetScript("OnClick", function(self)
    VendorSearchDB.fade = self:GetChecked() and true or false
    Filter:Refresh(true)
  end)
  fadeCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L["Fade instead of hide"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Keep the vendor's normal pages and fade the items"], 1, 1, 1)
    GameTooltip:AddLine(L["that don't match. Enter turns to the first page with a match."], 1, 1, 1)
    GameTooltip:Show()
  end)
  fadeCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  countText = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  countText:SetPoint("LEFT", fadeLabel, "RIGHT", 6, 0)

  -- Second row, under the search box (moves with it).
  unknownCheck = SmallCheck(L["Unknown recipes"], L["Unknown recipes only"],
    { L["Show only recipes you haven't learned yet."], L["Resets when you close the vendor."] },
    function(self)
      Filter.unknownOnly = self:GetChecked() and true or false
      Filter:Refresh(true)
    end)
  unknownCheck:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -1)

  usableCheck = SmallCheck(L["Usable"], L["Usable items only"],
    { L["Show only items your character can use."], L["Resets when you close the vendor."] },
    function(self)
      Filter.usableOnly = self:GetChecked() and true or false
      Filter:Refresh(true)
    end)
  usableCheck:SetPoint("LEFT", unknownCheck.label, "RIGHT", 8, 0)

  bagsCheck = SmallCheck(L["In bags"], L["Count in bags"],
    { L["Show on each item how many you already have"], L["in your bags and bank, e.g. (3)."] },
    function(self)
      VendorSearchDB.bagCount = self:GetChecked() and true or false
      Filter:UpdateMarks()
    end)
  bagsCheck:SetPoint("LEFT", usableCheck.label, "RIGHT", 8, 0)
  bagsCheck:SetChecked(VendorSearchDB.bagCount)

  emptyText = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  emptyText:SetText(L["No items match your search."])
  if MerchantItem1 then
    emptyText:SetPoint("TOPLEFT", MerchantItem1, "TOPLEFT", 8, -12)
  else
    emptyText:SetPoint("CENTER", MerchantFrame, "CENTER")
  end
  emptyText:Hide()

  hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
    Filter:Apply()
  end)
  if MerchantFrame_Update then
    hooksecurefunc("MerchantFrame_Update", function()
      Filter:UpdateVisibility()
    end)
  end
end
