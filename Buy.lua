local _, ns = ...
local L = ns.L

-- Buy several stacks at once: Alt-click a stackable item sold for gold on the vendor window and a small
-- window asks how many. Buy splits it into purchases of one stack each (the most the vendor sells per click)
-- and caps it at what your gold, the vendor's stock and your bag space allow. Nothing is bought until you
-- click Buy. Items that cost tokens or currency keep Blizzard's own confirmation, one purchase at a time.
local Buy = {}
ns.Buy = Buy

-- The look: the Tylesser stone panel (Codex's twin draws the same window with Codex's widgets).
local Look = {
  Window = function(frame)
    ns.T.Stone(frame, 12)
  end,
  Title = function(frame, text)
    local band = ns.T.TitleBar(frame, text, 24)
    return band.title
  end,
  Text = function(parent, dim)
    return parent:CreateFontString(nil, "OVERLAY", dim and "GameFontDisableSmall" or "GameFontHighlightSmall")
  end,
  Button = function(parent, width, height, text, primary)
    return ns.T.Button(parent, width, height, text, primary)
  end,
  EditBox = function(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, height)
    box:SetAutoFocus(false)
    ns.T.EditBox(box)
    return box
  end,
  Say = function(text)
    print(ns.PREFIX .. text)
  end,
}

local FRAME_NAME = "VendorSearchBuyFrame"
local frame, current

local function Money(copper)
  copper = math.floor(copper or 0)
  if GetMoneyString then
    return GetMoneyString(copper, true)
  elseif GetCoinTextureString then
    return GetCoinTextureString(copper)
  end
  return tostring(copper)
end

local LIMITS = {
  money = L["Up to %d: what your gold pays for."],
  stock = L["Up to %d: all the vendor has."],
  room = L["Up to %d: what fits in your bags."],
}

local function Quantity()
  return tonumber(frame.amount:GetText() or "") or 0
end

-- One purchase: the vendor's most per click, in whole vendor units.
local function Step(info)
  return math.max(info.stackCount, math.floor(info.maxStack / info.stackCount) * info.stackCount)
end

local function SetQuantity(value)
  frame.amount:SetText(tostring(math.max(0, math.floor(value))))
  Buy:Update()
end

function Buy:Update()
  if not (frame and frame:IsShown() and current) then
    return
  end
  local info = ns.BulkInfo(current.index)
  if not info or info.link ~= current.link then
    Buy:Close()
    return
  end
  current.info = info
  local _, total, cost = ns.BuyPlan(Quantity(), info)
  local limit, reason = ns.BuyLimit(info)
  frame.summary:SetText(total > 0 and L["Buys %d for %s."]:format(total, Money(cost)) or L["Nothing to buy."])
  frame.limit:SetText((LIMITS[reason] or L["Up to %d."]):format(limit))
  frame.buy:SetEnabled(total > 0)
end

function Buy:Close()
  current = nil
  if frame then
    frame.amount:ClearFocus()
    frame:Hide()
  end
end

local function DoBuy()
  if not current then
    return
  end
  local link = current.link
  local total = ns.BuyBulk(current.index, link, Quantity())
  if total > 0 then
    Look.Say(L["buying %d %s."]:format(total, link))
  else
    Look.Say(L["nothing was bought: the item changed or can't be bought now."])
  end
  Buy:Close()
end

local function Create()
  frame = CreateFrame("Frame", FRAME_NAME, MerchantFrame)
  frame:SetSize(260, 158)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:Hide()
  Look.Window(frame)
  if UISpecialFrames then
    table.insert(UISpecialFrames, FRAME_NAME)
  end

  local title = Look.Title(frame, L["Buy several stacks"])
  if title and title.SetPoint and not title:GetPoint(1) then
    title:SetPoint("TOPLEFT", 12, -10)
  end

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetSize(22, 22)
  frame.icon:SetPoint("TOPLEFT", 14, -38)
  frame.name = Look.Text(frame)
  frame.name:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
  frame.name:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  frame.name:SetJustifyH("LEFT")
  frame.name:SetWordWrap(false)

  frame.amount = Look.EditBox(frame, 64, 20)
  frame.amount:SetPoint("TOPLEFT", frame.icon, "BOTTOMLEFT", 6, -10)
  if frame.amount.SetNumeric then
    frame.amount:SetNumeric(true)
  end
  frame.amount:SetMaxLetters(5)
  frame.amount:SetScript("OnTextChanged", function(_, userInput)
    if userInput then
      Buy:Update()
    end
  end)
  frame.amount:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  frame.amount:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  local less = Look.Button(frame, 22, 20, "-")
  less:SetPoint("LEFT", frame.amount, "RIGHT", 8, 0)
  less:SetScript("OnClick", function()
    if current and current.info then
      SetQuantity(Quantity() - Step(current.info))
    end
  end)
  local more = Look.Button(frame, 22, 20, "+")
  more:SetPoint("LEFT", less, "RIGHT", 4, 0)
  more:SetScript("OnClick", function()
    if current and current.info then
      SetQuantity(Quantity() + Step(current.info))
    end
  end)
  local most = Look.Button(frame, 56, 20, L["Max"])
  most:SetPoint("LEFT", more, "RIGHT", 4, 0)
  most:SetScript("OnClick", function()
    if current and current.info then
      SetQuantity((ns.BuyLimit(current.info)))
    end
  end)

  frame.summary = Look.Text(frame)
  frame.summary:SetPoint("TOPLEFT", frame.amount, "BOTTOMLEFT", -6, -10)
  frame.summary:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  frame.summary:SetJustifyH("LEFT")
  frame.limit = Look.Text(frame, true)
  frame.limit:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -4)
  frame.limit:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  frame.limit:SetJustifyH("LEFT")

  frame.buy = Look.Button(frame, 80, 22, L["Buy"], true)
  frame.buy:SetPoint("BOTTOMRIGHT", -12, 12)
  frame.buy:SetScript("OnClick", DoBuy)
  local cancel = Look.Button(frame, 80, 22, L["Cancel"])
  cancel:SetPoint("RIGHT", frame.buy, "LEFT", -6, 0)
  cancel:SetScript("OnClick", function()
    Buy:Close()
  end)

  -- money, bags and the vendor's stock change while the window is open
  for _, event in ipairs({ "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_MONEY" }) do
    pcall(frame.RegisterEvent, frame, event)
  end
  frame:SetScript("OnEvent", function()
    Buy:Update()
  end)
  frame:SetScript("OnHide", function()
    current = nil
  end)
end

-- Opens the window for the vendor item `index` (Alt-click on its button). Items that can't be bought in
-- bulk are left to Blizzard; those that cost tokens or currency get a short note.
function Buy:Open(index)
  local info = ns.BulkInfo(index)
  if not info then
    local item = ns.ReadMerchantItem(index)
    if item and item.hasExtendedCost and GetMerchantItemMaxStack and (GetMerchantItemMaxStack(index) or 0) > 1 then
      Look.Say(L["items that cost tokens or currency are bought one at a time."])
    end
    return
  end
  if not frame then
    Create()
  end
  current = { index = index, link = info.link, info = info }
  frame.icon:SetTexture(info.icon)
  frame.name:SetText(info.link or info.name)
  frame:ClearAllPoints()
  -- a small dialog over the vendor's own window, like Blizzard's stack split (no panel beside it)
  frame:SetPoint("CENTER", MerchantFrame, "CENTER", 0, 30)
  frame:Show()
  frame:Raise()
  SetQuantity(math.min(Step(info), (ns.BuyLimit(info))))
  frame.amount:SetFocus()
  if frame.amount.HighlightText then
    frame.amount:HighlightText()
  end
end

function Buy:IsShown()
  return frame ~= nil and frame:IsShown()
end
