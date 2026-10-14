local _, ns = ...

local UI = {}
ns.UI = UI

local ROW_HEIGHT = 18
local NUM_ROWS = 18
local LEFT = 12
local SEARCH_Y = -30
local HEADER_Y = -58
local ROWS_Y = HEADER_Y - 20
local COL_GAP = 4
local ICON_SPACE = 20

local COLUMNS = {
  {key = "name", label = "Item", width = 210, justify = "LEFT"},
  {key = "price", label = "Price", width = 110, justify = "RIGHT"},
}

local CONTENT_WIDTH = -COL_GAP
for _, column in ipairs(COLUMNS) do
  CONTENT_WIDTH = CONTENT_WIDTH + column.width + COL_GAP
end
local PANEL_WIDTH = LEFT + CONTENT_WIDTH + 34
local PANEL_HEIGHT = -ROWS_Y + NUM_ROWS * ROW_HEIGHT + 40

local panel, searchBox, scrollFrame, toggle, status, glow
local rows, headers = {}, {}
local filtered = {}
local dockParent
local selectedIndex

--------------------------------------------------------------------------------
-- Positioning
--------------------------------------------------------------------------------
-- The classic merchant frame has ~34px of transparent padding on its right.
local function DockOffsets(frame)
  if frame:GetWidth() >= 370 then
    return -34, -12
  end
  return 2, 0
end

local function ApplyPosition()
  panel:ClearAllPoints()
  local pos = VendorSearchDB.position
  local dx, dy = 0, 0
  if dockParent then
    dx, dy = DockOffsets(dockParent)
  end
  if pos then
    panel:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  elseif dockParent then
    panel:SetPoint("TOPLEFT", dockParent, "TOPRIGHT", dx, dy)
  else
    panel:SetPoint("CENTER")
  end
  if dockParent then
    toggle:ClearAllPoints()
    toggle:SetPoint("TOPLEFT", dockParent, "TOPRIGHT", dx, dy - 4)
  end
end

--------------------------------------------------------------------------------
-- Merchant window interaction
--------------------------------------------------------------------------------
local function HideGlow()
  if glow then
    glow.anim:Stop()
    glow:Hide()
  end
end

local function Highlight(button)
  if not glow then
    glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata("HIGH")
    local texture = glow:CreateTexture(nil, "OVERLAY")
    texture:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    texture:SetBlendMode("ADD")
    texture:SetAllPoints()
    glow.anim = glow:CreateAnimationGroup()
    glow.anim:SetLooping("BOUNCE")
    local alpha = glow.anim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.2)
    alpha:SetDuration(0.4)
  end
  glow:ClearAllPoints()
  glow:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
  glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -6)
  glow:Show()
  glow.anim:Play()
  glow.token = (glow.token or 0) + 1
  local token = glow.token
  C_Timer.After(2.5, function()
    if glow.token == token then
      HideGlow()
    end
  end)
end

-- Turn the vendor window to the page holding the item and make it glow.
function UI:JumpTo(item)
  if not (MerchantFrame and MerchantFrame:IsShown()) then
    return
  end
  local perPage = MERCHANT_ITEMS_PER_PAGE or 10
  if MerchantFrame.selectedTab ~= 1 and PanelTemplates_SetTab then
    PanelTemplates_SetTab(MerchantFrame, 1)
  end
  MerchantFrame.page = math.ceil(item.index / perPage)
  if MerchantFrame_Update then
    MerchantFrame_Update()
  end
  local slot = item.index - (MerchantFrame.page - 1) * perPage
  local button = _G["MerchantItem" .. slot .. "ItemButton"]
  if button and button:IsVisible() then
    Highlight(button)
  end
end

-- Same as right-clicking the item in the vendor window. Items that cost
-- tokens/currency go through the vendor window so Blizzard's confirmation shows.
function UI:Buy(item)
  if item.hasExtendedCost then
    self:JumpTo(item)
    print(ns.PREFIX .. "items with a token or currency cost must be bought in the vendor window.")
    return
  end
  BuyMerchantItem(item.index)
end

local function ResetScroll()
  FauxScrollFrame_SetOffset(scrollFrame, 0)
  local bar = scrollFrame.ScrollBar or _G["VendorSearchScrollFrameScrollBar"]
  if bar then
    bar:SetValue(0)
  end
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------
local function RowOnClick(self, button)
  local item = self.item
  if not item then
    return
  end
  selectedIndex = item.index
  if button == "RightButton" then
    UI:Buy(item)
    UI:UpdateRows()
    return
  end
  if IsModifiedClick("CHATLINK") and item.link then
    local insertLink = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if insertLink and insertLink(item.link) then
      return
    end
  end
  if IsModifiedClick("DRESSUP") and item.link and DressUpItemLink then
    DressUpItemLink(item.link)
    return
  end
  UI:JumpTo(item)
  UI:UpdateRows()
end

local function RowOnEnter(self)
  local item = self.item
  if not item then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if GameTooltip.SetMerchantItem then
    GameTooltip:SetMerchantItem(item.index)
  elseif item.link then
    GameTooltip:SetHyperlink(item.link)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click: show in vendor window", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Right-click: buy", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Shift-click: link - Ctrl-click: preview", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function HideTooltip()
  GameTooltip:Hide()
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------
local function SetSort(key)
  if VendorSearchDB.sortKey ~= key then
    VendorSearchDB.sortKey = key
    VendorSearchDB.ascending = true
  elseif VendorSearchDB.ascending then
    VendorSearchDB.ascending = false
  else
    -- third click goes back to the vendor's own order
    VendorSearchDB.sortKey = "index"
    VendorSearchDB.ascending = true
  end
  UI:Refresh()
end

local function CreateCheck(label, dbKey, tooltip)
  local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  check:SetSize(22, 22)
  local text = check.Text or check.text
  if not text then
    text = check:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  end
  text:SetFontObject("GameFontHighlightSmall")
  text:SetText(label)
  check.label = text

  check:SetScript("OnShow", function(self)
    self:SetChecked(VendorSearchDB[dbKey])
  end)
  check:SetScript("OnClick", function(self)
    VendorSearchDB[dbKey] = self:GetChecked() and true or false
    UI:Refresh()
  end)
  check:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  check:SetScript("OnLeave", HideTooltip)
  return check
end

local function CreateSearchBox()
  local ok, box = pcall(CreateFrame, "EditBox", "VendorSearchBox", panel, "SearchBoxTemplate")
  if not ok then
    box = CreateFrame("EditBox", "VendorSearchBox", panel, "InputBoxTemplate")
  end
  box:SetSize(CONTENT_WIDTH - 6, 20)
  box:SetPoint("TOPLEFT", LEFT + 6, SEARCH_Y)
  box:SetAutoFocus(false)
  if box.Instructions then
    box.Instructions:SetText("Search name, type or slot")
  end
  box:HookScript("OnTextChanged", function()
    if scrollFrame then
      ResetScroll()
    end
    UI:Refresh()
  end)
  box:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    if filtered[1] then
      selectedIndex = filtered[1].index
      UI:JumpTo(filtered[1])
      UI:UpdateRows()
    end
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  return box
end

local function Create()
  panel = CreateFrame("Frame", "VendorSearchPanel", UIParent, "BasicFrameTemplateWithInset")
  panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
  panel:SetToplevel(true)
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    local point, _, relativePoint, x, y = self:GetPoint(1)
    VendorSearchDB.position = {point, relativePoint, x, y}
  end)
  panel:Hide()

  panel.title = panel.TitleText
  if not panel.title then
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.title:SetPoint("TOP", 0, -5)
  end

  local closeButton = panel.CloseButton or _G["VendorSearchPanelCloseButton"]
  if closeButton then
    closeButton:HookScript("OnClick", function()
      VendorSearchDB.shown = false
      UI:UpdateVisibility()
    end)
  end

  searchBox = CreateSearchBox()

  -- Column headers (click to sort)
  local x = LEFT
  for _, column in ipairs(COLUMNS) do
    local header = CreateFrame("Button", nil, panel)
    header:SetSize(column.width, 18)
    header:SetPoint("TOPLEFT", x, HEADER_Y)
    header.key = column.key

    local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetJustifyH(column.justify)
    text:SetText(column.label)

    local arrow = header:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    arrow:SetSize(9, 8)
    if column.justify == "LEFT" then
      text:SetPoint("TOPLEFT", ICON_SPACE, 0)
      text:SetPoint("BOTTOMRIGHT")
      arrow:SetPoint("LEFT", header, "LEFT", ICON_SPACE + text:GetStringWidth() + 3, 0)
    else
      text:SetPoint("TOPLEFT")
      text:SetPoint("BOTTOMRIGHT", -12, 0)
      arrow:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    end
    header.arrow = arrow

    header:SetScript("OnClick", function()
      SetSort(column.key)
    end)
    header:SetScript("OnEnter", function()
      text:SetTextColor(1, 1, 1)
    end)
    header:SetScript("OnLeave", function()
      text:SetTextColor(1, 0.82, 0)
    end)

    table.insert(headers, header)
    x = x + column.width + COL_GAP
  end

  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(1, 1, 1, 0.15)
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT", LEFT, ROWS_Y + 1)
  divider:SetWidth(CONTENT_WIDTH)

  scrollFrame = CreateFrame("ScrollFrame", "VendorSearchScrollFrame", panel, "FauxScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", LEFT, ROWS_Y)
  scrollFrame:SetSize(CONTENT_WIDTH, NUM_ROWS * ROW_HEIGHT)
  scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
      UI:UpdateRows()
    end)
  end)

  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", LEFT, ROWS_Y - (i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    if i % 2 == 0 then
      local stripe = row:CreateTexture(nil, "BACKGROUND")
      stripe:SetAllPoints()
      stripe:SetColorTexture(1, 1, 1, 0.03)
    end

    row.selected = row:CreateTexture(nil, "BORDER")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(1, 0.82, 0, 0.18)
    row.selected:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 0, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetHeight(ROW_HEIGHT)
    row.name:SetPoint("LEFT", ICON_SPACE, 0)
    row.name:SetWidth(COLUMNS[1].width - ICON_SPACE)

    row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.price:SetJustifyH("RIGHT")
    row.price:SetWordWrap(false)
    row.price:SetHeight(ROW_HEIGHT)
    row.price:SetPoint("LEFT", COLUMNS[1].width + COL_GAP, 0)
    row.price:SetWidth(COLUMNS[2].width)

    row:SetScript("OnClick", RowOnClick)
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", HideTooltip)
    rows[i] = row
  end

  local usable = CreateCheck("Usable only", "usableOnly", "Hide items your character can't use.")
  usable:SetPoint("BOTTOMLEFT", 10, 8)

  local affordable = CreateCheck("Affordable", "affordableOnly", "Hide items that cost more gold than you have.")
  affordable:SetPoint("LEFT", usable.label, "RIGHT", 12, 0)

  status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  status:SetPoint("BOTTOMRIGHT", -14, 14)
  status:SetJustifyH("RIGHT")

  toggle = CreateFrame("Button", "VendorSearchToggle", UIParent, "UIPanelButtonTemplate")
  toggle:SetSize(70, 22)
  toggle:SetText("Search")
  toggle:SetScript("OnClick", function()
    VendorSearchDB.shown = true
    UI:UpdateVisibility()
  end)
  toggle:Hide()
end

--------------------------------------------------------------------------------
-- Updating
--------------------------------------------------------------------------------
function UI:UpdateRows()
  if not panel then
    return
  end
  FauxScrollFrame_Update(scrollFrame, #filtered, NUM_ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(scrollFrame)
  local money = GetMoney()

  for i, row in ipairs(rows) do
    local item = filtered[offset + i]
    row.item = item
    if item then
      row.icon:SetTexture(item.icon)
      if not item.isUsable then
        row.icon:SetVertexColor(1, 0.3, 0.3)
      else
        row.icon:SetVertexColor(1, 1, 1)
      end

      local name = item.name
      local color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
      if color and color.hex then
        name = color.hex .. name .. "|r"
      end
      if item.stackCount > 1 then
        name = name .. " |cffa0a0a0x" .. item.stackCount .. "|r"
      end
      if item.numAvailable >= 0 then
        name = name .. " |cffff8000(" .. item.numAvailable .. " left)|r"
      end
      row.name:SetText(name)
      row.price:SetText(ns.FormatCost(item, money))
      row.selected:SetShown(item.index == selectedIndex)
      row:Show()
    else
      row:Hide()
    end
  end
end

function UI:Refresh()
  if not (panel and dockParent and panel:IsShown()) then
    return
  end

  local all = ns.ScanMerchant()
  local terms = ns.ParseQuery(searchBox:GetText())
  local money = GetMoney()
  wipe(filtered)
  for _, item in ipairs(all) do
    local keep = ns.Matches(item, terms)
    if keep and VendorSearchDB.usableOnly and not item.isUsable then
      keep = false
    end
    if keep and VendorSearchDB.affordableOnly and item.price > money then
      keep = false
    end
    if keep then
      table.insert(filtered, item)
    end
  end
  ns.SortItems(filtered, VendorSearchDB.sortKey, VendorSearchDB.ascending)

  panel.title:SetText("Vendor Search - " .. (UnitName("npc") or "Vendor"))
  status:SetText(("%d of %d items"):format(#filtered, #all))

  for _, header in ipairs(headers) do
    if header.key == VendorSearchDB.sortKey then
      if VendorSearchDB.ascending then
        header.arrow:SetTexCoord(0, 0.5625, 1, 0)
      else
        header.arrow:SetTexCoord(0, 0.5625, 0, 1)
      end
      header.arrow:Show()
    else
      header.arrow:Hide()
    end
  end

  self:UpdateRows()
end

function UI:UpdateVisibility()
  if not panel then
    return
  end
  local attached = dockParent ~= nil
  panel:SetShown(attached and VendorSearchDB.shown)
  toggle:SetShown(attached and not VendorSearchDB.shown)
  if panel:IsShown() then
    self:Refresh()
  end
end

function UI:Attach(frame)
  if not panel then
    Create()
  end
  dockParent = frame
  selectedIndex = nil
  searchBox:SetText("")
  ResetScroll()
  ApplyPosition()
  self:UpdateVisibility()
end

function UI:Detach()
  dockParent = nil
  if panel then
    searchBox:ClearFocus()
    panel:Hide()
    toggle:Hide()
  end
  HideGlow()
end

function UI:IsAttached()
  return dockParent ~= nil
end

function UI:FocusSearch()
  if panel and panel:IsShown() then
    searchBox:SetFocus()
  end
end

function UI:ResetPosition()
  VendorSearchDB.position = nil
  if panel then
    ApplyPosition()
  end
end
