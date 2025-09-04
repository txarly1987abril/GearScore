if not BIS_SelectedRaceDB then BIS_SelectedRaceDB = {} end
-- === BIS ALERTA DE PIEZA BIS EN CHAT ===

if type(BIS_Items) ~= "table" then
    BIS_Items = {}
    -- print("[BIS] BIS_Items inicializado como tabla vacía al cargar el archivo.")
end

-- print("[BIS] EquipBIS.lua cargado correctamente.")

local bisAlertFrame = CreateFrame("Frame")
local chatEvents = {
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER"
}
for _, evt in ipairs(chatEvents) do
    bisAlertFrame:RegisterEvent(evt)
end
--print("[BIS] Frame de alerta BIS creado y eventos de chat registrados.")
bisAlertFrame:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if not msg then return end
    local msgLower = string.lower(msg)
    local found = false

    -- Verificar si el mensaje contiene "dados"
    if string.find(msgLower, "dados") then
        local realm = GetRealmName() or "UnknownRealm"
        local name = UnitName("player") or "Unknown"
        local sets = {"main", "dual", "pvp"}
        local anyFound = false

        for _, setName in ipairs(sets) do
            local bisTable = BIS_Equipment and BIS_Equipment[realm] and BIS_Equipment[realm][name] and BIS_Equipment[realm][name][setName]
            if type(bisTable) == "table" then
                for slot, bisLink in pairs(bisTable) do
                    if bisLink and type(bisLink) == "string" then
                        local bisName = bisLink:match("%[(.-)%]")
                        if bisName and string.find(msgLower, string.lower(bisName), 1, true) then
                            -- Evitar múltiples susurros para el mismo evento
                            if not found then
                                local whisperMsg = "¡Atención! Se va a lotear tu pieza BIS ("..setName.."): "..bisLink
                                local playerName = UnitName("player")
                                if playerName then
                                    local ok, err = pcall(function()
                                        SendChatMessage(whisperMsg, "WHISPER", nil, playerName)
                                    end)
                                    if not ok then
                                        print("[BIS] Error al enviar el susurro:", err)
                                    end
                                end
                                found = true
                            end
                            anyFound = true
                        end
                    end
                end
            end
        end
        if not anyFound then
--            print("[BIS] No se encontró ninguna coincidencia de BIS en el mensaje.")
        end
    end
end)
-- Lista de razas para el dropdown de raza
if not BIS_RaceList then
    BIS_RaceList = {
        "Ninguna raza",
        -- Alianza
        "Humano", "Enano", "Elfo de la noche", "Gnomo", "Draenei",
        -- Horda
        "Orco", "No-muerto", "Tauren", "Trol", "Elfo de sangre"
    }
end
-- Dropdown para seleccionar raza
if not BIS_RaceDropdown then
    BIS_RaceDropdown = CreateFrame("Frame", "BIS_RaceDropdown", BIS_GearFrame, "UIDropDownMenuTemplate")
    BIS_RaceDropdown:SetPoint("TOPLEFT", BIS_GearFrame, "TOPLEFT", 165, -60)
    UIDropDownMenu_SetWidth(BIS_RaceDropdown, 120)
    UIDropDownMenu_SetText(BIS_RaceDropdown, BIS_SelectedRace)
    UIDropDownMenu_Initialize(BIS_RaceDropdown, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for _, race in ipairs(BIS_RaceList) do
            info.text = race
            info.checked = (BIS_SelectedRace == race)
            info.func = function()
                BIS_SelectedRace = race
                SaveRace()
                UIDropDownMenu_SetText(BIS_RaceDropdown, race)
                BIS_UpdateStatsText()
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("[BIS DEBUG] Raza seleccionada: "..race)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end
-- Cargar el XML de la interfaz BIS
local _, addon = ...

-- === Botón para copiar equipo inspeccionado a EquipBIS ===
-- Nuevo botón "Copiar BIS" en la ventana /gs

-- Definir el StaticPopupDialog una sola vez, global
if not _G.StaticPopupDialogs["EQUIPBIS_COPY_SET"] then
    _G.StaticPopupDialogs["EQUIPBIS_COPY_SET"] = {
        text = "¿A qué set de EquipBIS quieres copiar el equipo inspeccionado?",
        button1 = "Main",
        button2 = "Dual",
        OnAccept = function()
            _G.CopyInspectedToEquipBIS("main")
        end,
        OnCancel = function()
            _G.CopyInspectedToEquipBIS("dual")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function CopyInspectedToEquipBIS(selectedSet)
    -- print("[EquipBIS][DEBUG] Iniciando copia para set:", selectedSet)
    if not GS_DisplayPlayer or not GS_DisplayFrame then
    -- print("[EquipBIS][DEBUG] No hay jugador inspeccionado o ventana de inspección no disponible.")
        return
    end
    -- print("[EquipBIS][DEBUG] GS_DisplayPlayer:", GS_DisplayPlayer)
    local realm = GetRealmName() or "UnknownRealm"
    local name = UnitName("player") or "Unknown"
    -- print("[EquipBIS][DEBUG] Realm:", realm, "Mi PJ:", name)
    if type(BIS_Equipment) ~= "table" then BIS_Equipment = {} end
    if type(BIS_Equipment[realm]) ~= "table" then BIS_Equipment[realm] = {} end
    if type(BIS_Equipment[realm][name]) ~= "table" then BIS_Equipment[realm][name] = {} end
    if type(BIS_Equipment[realm][name][selectedSet]) ~= "table" then BIS_Equipment[realm][name][selectedSet] = {} end

    -- print("[EquipBIS][DEBUG] Buscando en GS_Data...")
    if not GS_Data or not GS_Data[realm] or not GS_Data[realm].Players or not GS_Data[realm].Players[GS_DisplayPlayer] then
    -- print("[EquipBIS][DEBUG] No se encontró información de equipo para ", GS_DisplayPlayer, "en la base de datos de GearScore.")
        return
    end
    -- print("[EquipBIS][DEBUG] Encontrado GS_Data para el jugador.")
    local equipTable = GS_Data[realm].Players[GS_DisplayPlayer].Equip
    if not equipTable or type(equipTable) ~= "table" then
        print("[EquipBIS][DEBUG] El jugador no tiene equipo guardado en la base de datos de GearScore.")
        return
    end
    -- print("[EquipBIS][DEBUG] EquipTable encontrada. Copiando slots...")
    for slot=1, 18 do
        local itemID = equipTable[slot]
    -- print("[EquipBIS][DEBUG] Slot:", slot, "itemID:", itemID)
        if itemID then
            local itemLink = GetInventoryItemLink("player", slot) -- fallback
            local nameInfo, link = GetItemInfo(itemID)
            -- print("[EquipBIS][DEBUG] GetItemInfo:", nameInfo, link)
            if link then itemLink = link end
            local slotName = "BIS_Frame"..slot
            BIS_Equipment[realm][name][selectedSet][slotName] = itemLink or tostring(itemID)
            -- print("[EquipBIS][DEBUG] Guardado en:", slotName, "->", BIS_Equipment[realm][name][selectedSet][slotName])
        end
    end
    -- print("[EquipBIS][DEBUG] Equipo de ", GS_DisplayPlayer, " copiado al set '", selectedSet, "' desde la base de datos. Abre /equipobis para verlo.")
    if ToggleBISFrame then ToggleBISFrame() end
    if LoadBIS then LoadBIS() end
end

_G.CopyInspectedToEquipBIS = CopyInspectedToEquipBIS

function ShowCopySetDialog()
_G.ShowCopySetDialog = ShowCopySetDialog
--    print("[EquipBIS][DEBUG] Mostrando StaticPopup_Show EQUIPBIS_COPY_SET")
    StaticPopup_Show("EQUIPBIS_COPY_SET")
_G.CopyInspectedToEquipBIS = CopyInspectedToEquipBIS
--        print("[EquipBIS][DEBUG] Mostrando StaticPopup_Show EQUIPBIS_COPY_SET")
        StaticPopup_Show("EQUIPBIS_COPY_SET")
end




-- (Restaurado) Sin hook sobre el botón "Equipo BIS". El botón vuelve a abrir /equipobis como antes.

-- El comando y función para mostrar/ocultar el frame BIS solo se registran tras cargar el addon
function ToggleBISFrame()
    if BIS_GearFrame and BIS_GearFrame:IsShown() then
        BIS_GearFrame:Hide()
    -- print("[GearScore] Frame BIS ocultado.")
    elseif BIS_GearFrame then
        BIS_GearFrame:Show()
    -- print("[GearScore] Frame BIS mostrado.")
    else
    -- print("[GearScore] BIS_GearFrame no existe aún.")
    end
end

-- Declarar BIS_SetupButtons como local antes de BIS_Init para evitar problemas de hoisting en Lua
local BIS_SetupButtons -- forward declaration

-- Inicialización segura tras cargar el XML
local function BIS_Init()
    -- Restaurar posición original del frame BIS_GearFrame siempre al cargar
    if BIS_GearFrame then
        BIS_GearFrame:ClearAllPoints()
    BIS_GearFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- Cambia aquí si quieres otra posición por defecto
    BIS_GearFrame:SetUserPlaced(false)
    end
    -- Hacer el frame movible arrastrando desde la parte superior
    if BIS_GearFrame then
        BIS_GearFrame:SetMovable(true)
        BIS_GearFrame:EnableMouse(true)
        BIS_GearFrame:RegisterForDrag("LeftButton")
        BIS_GearFrame:SetScript("OnDragStart", function(self)
            self:StartMoving()
            self:SetUserPlaced(false) -- Forzar que no se guarde posición al empezar a mover
        end)
        BIS_GearFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetUserPlaced(false) -- Forzar que no se guarde posición al soltar
        end)
    end
    if not BIS_GearFrame then return end
    BIS_GearFrame:Hide()
    if tinsert and UISpecialFrames then
        tinsert(UISpecialFrames, "BIS_GearFrame")
    end
    BIS_SetupButtons()
    -- Botón Atrás para volver a /gs
    if not BIS_BackButton then
        BIS_BackButton = CreateFrame("Button", "BIS_BackButton", BIS_GearFrame, "UIPanelButtonTemplate")
        BIS_BackButton:SetSize(55, 24)
        BIS_BackButton:SetText("Atrás")
        -- Margen derecho: anclar TOPRIGHT con un pequeño margen
        BIS_BackButton:SetPoint("TOPRIGHT", BIS_GearFrame, "TOPRIGHT", -35, -10)
        BIS_BackButton:SetScript("OnClick", function()
            if BIS_GearFrame then BIS_GearFrame:Hide() end
            if GS_DisplayFrame then GS_DisplayFrame:Show() end
            if GS_SCANSET then GS_SCANSET("") end
        end)
    end
        -- Botón Copiar BIS en la ventana /gs (GS_DisplayFrame), parte baja a la derecha del botón Buscar
        if _G["GS_SearchButton"] and not BIS_CopyButton then
            BIS_CopyButton = CreateFrame("Button", "BIS_CopyButton", GS_DisplayFrame, "UIPanelButtonTemplate")
            BIS_CopyButton:SetSize(100, 24)
            BIS_CopyButton:SetText("Copiar BIS")
            BIS_CopyButton:SetPoint("BOTTOMLEFT", _G["GS_SearchButton"], "BOTTOMRIGHT", 10, 30)
            BIS_CopyButton:SetScript("OnClick", function()
                if ShowCopySetDialog then ShowCopySetDialog() end
            end)
        end
    -- Botón para guardar stats base eliminado
end

-- Tabla para guardar los ítems BIS por slot
-- Tabla manual de stats de gemas (ID de gema -> tabla de stats)
-- local BIS_GemStats = {
--     [3525] = { ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 20 }, -- Rubí cárdeno fracturado en ultimowow
--     -- Puedes añadir más gemas aquí si lo necesitas
-- }
-- Dropdown de clase para conversiones de stats
-- Guardar raza siempre disponible
function SaveRace()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    if type(BIS_SelectedRaceDB) ~= "table" then BIS_SelectedRaceDB = {} end
    if not BIS_CurrentSet then
--        print("[EquipBIS] Error: BIS_CurrentSet es nil. No se puede guardar la raza.")
        return
    end
    if not BIS_SelectedRaceDB[realm] then BIS_SelectedRaceDB[realm] = {} end
    if type(BIS_SelectedRaceDB[realm][name]) ~= "table" then BIS_SelectedRaceDB[realm][name] = {} end
    BIS_SelectedRaceDB[realm][name][BIS_CurrentSet] = BIS_SelectedRace
    -- Debug eliminado
end

function SaveClass()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    if type(BIS_SelectedClassDB) ~= "table" then BIS_SelectedClassDB = {} end
    if not BIS_CurrentSet then
--        print("[EquipBIS] Error: BIS_CurrentSet es nil. No se puede guardar la clase.")
        return
    end
    if not BIS_SelectedClassDB[realm] then BIS_SelectedClassDB[realm] = {} end
    if type(BIS_SelectedClassDB[realm][name]) ~= "table" then BIS_SelectedClassDB[realm][name] = {} end
    BIS_SelectedClassDB[realm][name][BIS_CurrentSet] = BIS_SelectedClass
    -- Debug eliminado
end
    -- Dropdown de clase eliminado completamente


local BIS_RaceModifiers = {
    ["Tauren"] = { STAMINA_PCT = 5 }, -- +5% aguante pasivo racial
    ["No-muerto"] = { SHADOWRES_PCT = 1 }, -- +1% resistencia a las sombras
    ["Elfo de sangre"] = {
        ARCANERES_PCT = 1,
        NATURERES_PCT = 1,
        SHADOWRES_PCT = 1,
        FROSTRES_PCT = 1,
        FIRERES_PCT = 1,
    }, -- +1% a todas las resistencias mágicas
    ["Humano"] = { SPIRIT_PCT = 3 }, 
    ["Enano"] = { FROSTRES_PCT = 1 }, -- +1% resistencia a la escarcha
    ["Elfo de la noche"] = {
        DODGE_PCT = 2, -- +2% esquiva
        NATURERES_PCT = 1, -- +1% resistencia a la naturaleza
    },
    ["Draenei"] = { SHADOWRES_PCT = 1, HIT_PCT = 1 }, -- +1% resistencia a las sombras y +1% índice de golpe
    -- Añade aquí los modificadores reales de cada raza
}
local BIS_Items = {}

-- Helper para extraer itemID, enchantID y gemas de un itemLink
local function ParseItemLink(link)
    if type(link) ~= "string" then return nil end
    -- Busca la parte Hitem:itemID:enchant:gem1:gem2:gem3
    local itemString = link:match("Hitem:([%d:]+)")
    if not itemString then return nil end
    local parts = {}
    for v in string.gmatch(itemString, "[^:]+") do table.insert(parts, v) end
    local itemID = tonumber(parts[1])
    local enchantID = tonumber(parts[2]) or 0
    local gem1 = tonumber(parts[3]) or 0
    local gem2 = tonumber(parts[4]) or 0
    local gem3 = tonumber(parts[5]) or 0
    return {
        item = itemID,
        enchant = enchantID,
        gems = {gem1, gem2, gem3}
    }
end

-- Crear un único InputBox reutilizable
local BIS_InputBox = CreateFrame("EditBox", "BIS_InputBox", UIParent, "InputBoxTemplate")
BIS_InputBox:SetAutoFocus(true)
BIS_InputBox:SetSize(120, 24)
BIS_InputBox:Hide()
BIS_InputBox:SetFrameStrata("TOOLTIP")

-- Crear un frame de fondo para el InputBox
local BIS_InputFrame = CreateFrame("Frame", "BIS_InputFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
BIS_InputFrame:SetSize(260, 70)
BIS_InputFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
BIS_InputFrame:SetBackdropColor(0, 0, 0, 0.85)
BIS_InputFrame:SetFrameStrata("TOOLTIP")
BIS_InputFrame:Hide()

-- Texto de ayuda sobre el InputBox (dos líneas)
local BIS_InputHelp = BIS_InputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
BIS_InputHelp:SetPoint("TOP", 0, -8)
BIS_InputHelp:SetText("Ingresa aquí la ID\no linkea la pieza que quieras")

-- Mostrar correctamente el InputBox
BIS_InputBox:SetParent(BIS_InputFrame)
BIS_InputBox:SetSize(220, 28)
BIS_InputBox:ClearAllPoints()
BIS_InputBox:SetPoint("BOTTOM", BIS_InputFrame, "BOTTOM", 0, 10)
BIS_InputBox:Show()
BIS_InputBox:Hide()

-- Modificar ShowInputBox para mostrar el frame de fondo y el input
local function ShowInputBox(slotButton)
    BIS_InputFrame:ClearAllPoints()
    BIS_InputFrame:SetPoint("CENTER", slotButton, "CENTER", 0, 0)
    BIS_InputFrame:Show()
    BIS_InputBox:Show()
    BIS_InputBox:SetText("")
    BIS_InputBox:SetFocus()
    BIS_InputBox.slotButton = slotButton
end

-- Ocultar ambos al cerrar
BIS_InputBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:Hide(); BIS_InputFrame:Hide() end)
BIS_InputBox:SetScript("OnEnterPressed", function(self) self:Hide(); BIS_InputFrame:Hide() end)

-- Ocultar el input al cerrar el frame BIS principal
local old_ToggleBISFrame = ToggleBISFrame
ToggleBISFrame = function(...)
    if old_ToggleBISFrame then old_ToggleBISFrame(...) end
    BIS_InputBox:Hide()
    BIS_InputFrame:Hide()
end

-- Soporte para dos sets: 'main' y 'dual'
local BIS_CurrentSet = "main"

-- Guardar y cargar el equipo BIS usando SavedVariables, ahora por set
local function getBISKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return realm, name
end

function LoadBIS()
    -- Restaurar selección de raza y clase por set
    local realm, name = UnitName("player") or "Unknown", GetRealmName() or "UnknownRealm"
    if BIS_SelectedRaceDB[realm] and BIS_SelectedRaceDB[realm][name] and BIS_SelectedRaceDB[realm][name][BIS_CurrentSet] then
        BIS_SelectedRace = BIS_SelectedRaceDB[realm][name][BIS_CurrentSet]
    else
        BIS_SelectedRace = "Ninguna raza"
    end
    if BIS_RaceDropdown then
        UIDropDownMenu_SetText(BIS_RaceDropdown, BIS_SelectedRace)
        UIDropDownMenu_Initialize(BIS_RaceDropdown, function(self, level, menuList)
            local info = UIDropDownMenu_CreateInfo()
            for _, race in ipairs(BIS_RaceList) do
                info.text = race
                info.checked = (BIS_SelectedRace == race)
                info.func = function()
                    BIS_SelectedRace = race
                    SaveRace()
                    UIDropDownMenu_SetText(BIS_RaceDropdown, race)
                    BIS_UpdateStatsText()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end

    local realm, name = getBISKey()
    if type(BIS_Equipment) ~= "table" then BIS_Equipment = {} end
    if type(BIS_Equipment[realm]) ~= "table" then BIS_Equipment[realm] = {} end
    if type(BIS_Equipment[realm][name]) ~= "table" then BIS_Equipment[realm][name] = {} end
    if type(BIS_Equipment[realm][name][BIS_CurrentSet]) ~= "table" then BIS_Equipment[realm][name][BIS_CurrentSet] = {} end
    for slotName, itemLink in pairs(BIS_Equipment[realm][name][BIS_CurrentSet]) do
        BIS_Items[slotName] = itemLink
        local slot = _G[slotName]
        if slot and itemLink then
            local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
            if itemTexture then
                slot:SetNormalTexture(itemTexture)
            else
                slot:SetNormalTexture(nil)
            end
        elseif slot then
            slot:SetNormalTexture(nil)
        end
    end
    -- Limpiar slots no usados
    for i=1,18 do
        local slotName = "BIS_Frame"..i
        if not BIS_Equipment[realm][name][BIS_CurrentSet][slotName] then
            BIS_Items[slotName] = nil
            local slot = _G[slotName]
            if slot then slot:SetNormalTexture(nil) end
        end
    end
end

function SaveBIS()
    local realm, name = getBISKey()
    if type(BIS_Equipment) ~= "table" then BIS_Equipment = {} end
    if type(BIS_Equipment[realm]) ~= "table" then BIS_Equipment[realm] = {} end
    if type(BIS_Equipment[realm][name]) ~= "table" then BIS_Equipment[realm][name] = {} end
    if type(BIS_Equipment[realm][name][BIS_CurrentSet]) ~= "table" then BIS_Equipment[realm][name][BIS_CurrentSet] = {} end
    for slotName, itemLink in pairs(BIS_Items) do
        BIS_Equipment[realm][name][BIS_CurrentSet][slotName] = itemLink
    end
end

-- Modificar el OnEnterPressed para guardar al asignar item
BIS_InputBox:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    local slotButton = self.slotButton
    self:Hide(); BIS_InputFrame:Hide()
    if not text or text == "" then return end
    -- Solo aceptar links completos para asegurar stats de gemas/enchants
    if not text:find("^|c") or not text:find("|Hitem:") then
    -- print("|cffff2222Por favor, linkea la pieza equipada con Shift+Click para guardar gemas y encantamientos.|r")
        return
    end
    -- Validar si el link tiene gemas/enchants (para slots que pueden llevarlos)
    local slotName = slotButton:GetName()
    local slotsWithGems = {
        ["BIS_Frame1"] = true,  -- Cabeza
        ["BIS_Frame3"] = true,  -- Hombros
        ["BIS_Frame5"] = true,  -- Pecho
        ["BIS_Frame6"] = true,  -- Cinturón
        ["BIS_Frame7"] = true,  -- Piernas
        ["BIS_Frame8"] = true,  -- Pies
        ["BIS_Frame9"] = true,  -- Muñecas
        ["BIS_Frame10"] = true, -- Manos
        ["BIS_Frame15"] = true, -- Espalda
        ["BIS_Frame16"] = true, -- Mano derecha
        ["BIS_Frame17"] = true, -- Mano izquierda
        ["BIS_Frame18"] = true, -- A distancia
    }
    local hasEnchantOrGem = false
    local itemString = text:match("Hitem:([%d:]+)")
    if itemString then
        local parts = {}
        for v in string.gmatch(itemString, "[^:]+") do table.insert(parts, v) end
        local enchant = tonumber(parts[2]) or 0
        local gem1 = tonumber(parts[3]) or 0
        local gem2 = tonumber(parts[4]) or 0
        local gem3 = tonumber(parts[5]) or 0
        if enchant > 0 or gem1 > 0 or gem2 > 0 or gem3 > 0 then
            hasEnchantOrGem = true
        end
    end
    if slotsWithGems[slotName] and not hasEnchantOrGem then
    -- print("|cffffff00Advertencia: El link guardado para este slot NO tiene gemas ni encantamiento. Si tu pieza lleva gemas o encantamiento, linkéala desde tu equipo con Shift+Click para que se sumen los stats.|r")
    end
    -- Guardar SIEMPRE el texto original (el link completo)
    BIS_Items[slotName] = text
    -- print("[BIS DEBUG] Guardado en slot "..tostring(slotName)..": "..tostring(text))
    SaveBIS()
    -- Mostrar icono
    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(text)
    if itemTexture then
        slotButton:SetNormalTexture(itemTexture)
    else
        slotButton:SetNormalTexture(nil)
        slotButton:SetBackdropBorderColor(1,0,0,1)
    end
end)

-- Cambiar set al pulsar los botones
local function UpdateSetText()
    if BIS_SetText then
        if BIS_CurrentSet == "main" then
            BIS_SetText:SetText("|cffff2222Main|r")
        elseif BIS_CurrentSet == "dual" then
            BIS_SetText:SetText("|cffff2222Dual|r")
        elseif BIS_CurrentSet == "pvp" then
            BIS_SetText:SetText("|cffff2222PvP|r")
        else
            BIS_SetText:SetText(BIS_CurrentSet)
        end
    end
end

BIS_SetupButtons = function()
    if BIS_MainButton and BIS_DualButton and BIS_PvPButton then
        local function RefreshDropdowns()
            if BIS_RaceDropdown then
                UIDropDownMenu_SetText(BIS_RaceDropdown, BIS_SelectedRace or "Ninguna raza")
                UIDropDownMenu_Initialize(BIS_RaceDropdown, function(self, level, menuList)
                    local info = UIDropDownMenu_CreateInfo()
                    for _, race in ipairs(BIS_RaceList) do
                        info.text = race
                        info.checked = (BIS_SelectedRace == race)
                        info.func = function()
                            BIS_SelectedRace = race
                            SaveRace()
                            UIDropDownMenu_SetText(BIS_RaceDropdown, race)
                            BIS_UpdateStatsText()
                        end
                        UIDropDownMenu_AddButton(info)
                    end
                end)
            end
        end
        BIS_MainButton:SetScript("OnClick", function()
            BIS_CurrentSet = "main"
            LoadBIS()
            UpdateSetText()
            RefreshDropdowns()
        end)
        BIS_DualButton:SetScript("OnClick", function()
            BIS_CurrentSet = "dual"
            LoadBIS()
            UpdateSetText()
            RefreshDropdowns()
        end)
        -- PvP button: mover 5px a la izquierda respecto a su posición original
        local point, relativeTo, relativePoint, xOfs, yOfs = BIS_PvPButton:GetPoint()
        BIS_PvPButton:ClearAllPoints()
        BIS_PvPButton:SetPoint(point or "TOPLEFT", relativeTo or BIS_GearFrame, relativePoint or "TOPLEFT", (xOfs or 0) - 5, yOfs or 0)
        BIS_PvPButton:SetScript("OnClick", function()
            BIS_CurrentSet = "pvp"
            LoadBIS()
            UpdateSetText()
            RefreshDropdowns()
        end)
    end
end

-- Cargar equipo guardado al cargar el addon
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "GearScore" then
        BIS_Init()
        LoadBIS()
        UpdateSetText()
        -- Registrar comando /equipobis SIEMPRE
        SLASH_EQUIPOBIS1 = "/equipobis"
        SLASH_EQUIPOBIS2 = "/Equipobis"
        SlashCmdList["EQUIPOBIS"] = ToggleBISFrame
    -- print("[GearScore] Comando /equipobis registrado correctamente.")
    end
end)

-- Calcular y mostrar los stats totales del set BIS configurado
--[[
local function BIS_CalculateStats()
    -- Función deshabilitada para evitar taint y problemas de estadísticas
    return {}, false
end
]]

-- Tabla de mapeo de stats a nombres amigables en español
-- local BIS_StatNames = {} -- Tabla de nombres de stats deshabilitada

-- local BIS_StatOrder = {} -- Orden de stats deshabilitado

-- Mostrar los stats en el frame BIS (solo los principales y con nombres legibles)
-- function BIS_UpdateStatsText() end -- Función deshabilitada

-- Actualizar stats al cambiar set, guardar/cargar equipo o editar slot
--[[
local old_LoadBIS = LoadBIS
function LoadBIS(...)
    if old_LoadBIS then old_LoadBIS(...) end
    -- BIS_UpdateStatsText() -- Deshabilitado
end
local old_SaveBIS = SaveBIS
function SaveBIS(...)
    if old_SaveBIS then old_SaveBIS(...) end
    -- BIS_UpdateStatsText() -- Deshabilitado
end
local old_ToggleBISFrame = ToggleBISFrame
ToggleBISFrame = function(...)
    if old_ToggleBISFrame then old_ToggleBISFrame(...) end
    -- BIS_UpdateStatsText() -- Deshabilitado
end
]]

-- Al pulsar Enter, buscar el ítem y mostrar el icono
BIS_InputBox:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    local slotButton = self.slotButton
    self:Hide(); BIS_InputFrame:Hide()
    if not text or text == "" then return end
    -- Solo aceptar links completos para asegurar stats de gemas/enchants
    if not text:find("^|c") or not text:find("|Hitem:") then
    -- print("|cffff2222Por favor, linkea la pieza equipada con Shift+Click para guardar gemas y encantamientos.|r")
        return
    end
    -- Guardar SIEMPRE el link original
    BIS_Items[slotButton:GetName()] = text
    SaveBIS()
    -- Mostrar icono
    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(text)
    if itemTexture then
        slotButton:SetNormalTexture(itemTexture)
    else
        slotButton:SetNormalTexture(nil)
        slotButton:SetBackdropBorderColor(1,0,0,1)
    end
end)

-- Asignar el evento OnClick a todos los slots BIS
for i=1,18 do
    local slot = _G["BIS_Frame"..i]
    if slot then
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
        slot:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                -- Borrar item del slot
                BIS_Items[self:GetName()] = nil
                local realm, name = getBISKey()
                if type(BIS_Equipment) ~= "table" then BIS_Equipment = {} end
                if type(BIS_Equipment[realm]) ~= "table" then BIS_Equipment[realm] = {} end
                if type(BIS_Equipment[realm][name]) ~= "table" then BIS_Equipment[realm][name] = {} end
                if type(BIS_Equipment[realm][name][BIS_CurrentSet]) ~= "table" then BIS_Equipment[realm][name][BIS_CurrentSet] = {} end
                BIS_Equipment[realm][name][BIS_CurrentSet][self:GetName()] = nil
                SaveBIS()
                BIS_UpdateStatsText()
                self:SetNormalTexture(nil)
                self:SetBackdropBorderColor(1,1,1,1)
            elseif button == "MiddleButton" then
                local itemLink = BIS_Items[self:GetName()]
                if itemLink and type(itemLink) == "string" and itemLink:find("^|c") and itemLink:find("|Hitem:") then
                    local parsed = ParseItemLink(itemLink)
                    if parsed then
                        local gemText = ""
                        for idx, gemID in ipairs(parsed.gems) do
                            if gemID and gemID > 0 then
                                gemText = gemText .. string.format("Gema %d: %d ", idx, gemID)
                            end
                        end
                        local itemName = GetItemInfo(itemLink) or "[Desconocido]"
                        if gemText == "" then gemText = "Sin gemas" end
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("[BIS] "..itemName.." | Gemas: "..gemText)
                        end
                    end
                end
            else
                ShowInputBox(self)
            end
        end)
        -- Restaurar borde al hacer click
        slot:SetScript("OnMouseDown", function(self)
            self:SetBackdropBorderColor(1,1,1,1)
        end)
    end
end

-- Mostrar tooltip del item al pasar el ratón por encima del slot
for i=1,18 do
    local slot = _G["BIS_Frame"..i]
    if slot then
        slot:HookScript("OnEnter", function(self)
            local itemLink = BIS_Items[self:GetName()]
            if itemLink and type(itemLink) == "string" and itemLink:find("^|c") and itemLink:find("|Hitem:") then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            elseif itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(tostring(itemLink))
                GameTooltip:Show()
            end
        end)
        slot:HookScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
end

-- Permitir que el InputBox BIS acepte enlaces de Shift+Click
local orig_ChatEdit_InsertLink = ChatEdit_InsertLink
function ChatEdit_InsertLink(link)
    if BIS_InputBox:IsVisible() and BIS_InputBox:HasFocus() then
        BIS_InputBox:Insert(link)
        return true
    end
    if orig_ChatEdit_InsertLink then
        return orig_ChatEdit_InsertLink(link)
    end
end

-- Comando /bisstats deshabilitado para evitar taint y problemas de estadísticas



