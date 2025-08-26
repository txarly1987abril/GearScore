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
StaticPopupDialogs = StaticPopupDialogs or {}
if not StaticPopupDialogs["EQUIPBIS_COPY_SET"] then
    StaticPopupDialogs["EQUIPBIS_COPY_SET"] = {
        text = "¿A qué set de EquipBIS quieres copiar el equipo inspeccionado?",
        button1 = "Main",
        button2 = "Dual",
        OnAccept = function()
            -- print("[EquipBIS][DEBUG] Botón Main pulsado (OnAccept)")
            _G.CopyInspectedToEquipBIS("main")
        end,
        OnCancel = function()
            -- print("[EquipBIS][DEBUG] Botón Dual pulsado (OnCancel)")
            _G.CopyInspectedToEquipBIS("dual")
        end,
        OnShow = function()
            -- print("[EquipBIS][DEBUG] StaticPopup EQUIPBIS_COPY_SET mostrado")
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
    -- Botón para guardar stats base eliminado
end

-- Tabla para guardar los ítems BIS por slot
-- Tabla manual de stats de gemas (ID de gema -> tabla de stats)
local BIS_GemStats = {
    [3525] = { ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 20 }, -- Rubí cárdeno fracturado en ultimowow
    -- Puedes añadir más gemas aquí si lo necesitas
}
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
local function BIS_CalculateStats()
    local totalStats = {}
    -- Copiar stats base por personaje y set si existen
    local realm, name = getBISKey()
    if BIS_BaseStats and BIS_BaseStats[realm] and BIS_BaseStats[realm][name] and BIS_BaseStats[realm][name][BIS_CurrentSet] then
        for k, v in pairs(BIS_BaseStats[realm][name][BIS_CurrentSet]) do
            totalStats[k] = v
        end
    end
    -- ...existing code...
    -- ...existing code...
    -- Sumar stats de las piezas configuradas
    for i=1,18 do
        local slotName = "BIS_Frame"..i
        local itemLink = BIS_Items and BIS_Items[slotName]
        if itemLink and type(itemLink) == "string" and itemLink:find("^|c") and itemLink:find("|Hitem:") then
            local itemName = GetItemInfo(itemLink)
            local stats
            if BonusScanner and BonusScanner.ScanItem then
                local ok, result = pcall(function()
                    return BonusScanner:ScanItem(itemLink)
                end)
                if ok and result and type(result) == "table" then
                    stats = result
                end
            end
            if not stats or (type(stats)=="table" and not next(stats)) then
                stats = GetItemStats(itemLink)
            end
            if stats and next(stats) then
                for stat, value in pairs(stats) do
                    if stat == "HIT_PCT" then
                        hitPct_equipo = (hitPct_equipo or 0) + value
                    else
                        totalStats[stat] = (totalStats[stat] or 0) + value
                    end
                end
            end
            -- ...existing code...
        end
    end
    -- Unificar STR y STRENGTH en ITEM_MOD_STRENGTH_SHORT después de sumar todo
    if totalStats["STR"] then
        totalStats["ITEM_MOD_STRENGTH_SHORT"] = (totalStats["ITEM_MOD_STRENGTH_SHORT"] or 0) + totalStats["STR"]
        totalStats["STR"] = nil
    end
    if totalStats["STRENGTH"] then
        totalStats["ITEM_MOD_STRENGTH_SHORT"] = (totalStats["ITEM_MOD_STRENGTH_SHORT"] or 0) + totalStats["STRENGTH"]
        totalStats["STRENGTH"] = nil
    end
    local missingCache = false
    local shadowResPct = 0
    local arcaneResPct = 0
    local natureResPct = 0
    local frostResPct = 0
    local fireResPct = 0
    local spiritPct = 0
    local dodgePct = 0
    local hitPct_equipo = 0
    local hitPct_racial = 0
    -- Sumar stats de las piezas configuradas
    for i=1,18 do
        local slotName = "BIS_Frame"..i
        local itemLink = BIS_Items and BIS_Items[slotName]
        if itemLink and type(itemLink) == "string" and itemLink:find("^|c") and itemLink:find("|Hitem:") then
            local itemName = GetItemInfo(itemLink)
            local stats
            if BonusScanner and BonusScanner.ScanItem then
                local ok, result = pcall(function()
                    return BonusScanner:ScanItem(itemLink)
                end)
                if ok and result and type(result) == "table" then
                    stats = result
                end
            end
            if not stats or (type(stats)=="table" and not next(stats)) then
                stats = GetItemStats(itemLink)
            end
            if stats and next(stats) then
                for stat, value in pairs(stats) do
                    totalStats[stat] = (totalStats[stat] or 0) + value
                end
            end
            -- Sumar stats de las gemas manualmente y marcar missingCache si alguna no está en caché
            local itemString = itemLink:match("Hitem:([%d:]+)")
            if itemString then
                local parts = {}
                for v in string.gmatch(itemString, "[^:]+") do table.insert(parts, v) end
                -- parts[3], [4], [5] = gem1, gem2, gem3
                for gemIdx=3,5 do
                    local gemID = tonumber(parts[gemIdx]) or 0
                    if gemID > 0 then
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("[BIS DEBUG] Gema detectada en slot "..tostring(slotName)..": ID="..tostring(gemID))
                        end
                        local gemLink = "item:"..gemID..":0:0:0:0:0:0:0"
                        local gemName = GetItemInfo(gemLink)
                        if not gemName then
                            missingCache = true
                            local loadCmd = "/run print(select(2,GetItemInfo("..gemID..")))"
                            -- print("[BIS] Gema ", gemID, "no está en caché. Copia y pega este comando en el chat para cargarla:", loadCmd)
                            if DEFAULT_CHAT_FRAME then
--                                DEFAULT_CHAT_FRAME:AddMessage("[BIS] Copia y pega en el chat para cargar la gema: "..loadCmd)
                            else
--                                SendChatMessage("[BIS] Copia y pega en el chat para cargar la gema: "..loadCmd, "SAY")
                            end
                        end
                        local gemStats = GetItemStats(gemLink)
                        if gemStats and next(gemStats) then
                            for k,v in pairs(gemStats) do
                                totalStats[k] = (totalStats[k] or 0) + v
                                if DEFAULT_CHAT_FRAME then
                                    DEFAULT_CHAT_FRAME:AddMessage("[BIS DEBUG] GemStat: "..tostring(k).." = "..tostring(v))
                                end
                                -- Ya no sumamos a ARMORPEN aquí para evitar doble conteo
                                if (k == "ARMOR_PENETRATION" or k == "ARMORPEN") then
                                    totalStats["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = (totalStats["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] or 0) + v
                                end
                            end
                        end
                        -- SIEMPRE sumar stats manuales de la tabla BIS_GemStats si existen
                        if BIS_GemStats[gemID] then
                            for k,v in pairs(BIS_GemStats[gemID]) do
                                totalStats[k] = (totalStats[k] or 0) + v
                                if DEFAULT_CHAT_FRAME then
                                    DEFAULT_CHAT_FRAME:AddMessage("[BIS DEBUG] GemStat (manual): "..tostring(k).." = "..tostring(v).." (Gema manual ID="..tostring(gemID)..")")
                                end
                                -- Ya no sumamos a ARMORPEN aquí para evitar doble conteo
                                if (k == "ARMOR_PENETRATION" or k == "ARMORPEN") then
                                    totalStats["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = (totalStats["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] or 0) + v
                                end
                            end
                        end
                        -- else
                        --     print("[BIS] Gem", gemID, "sin stats")
                        -- end
                    end
                end
            end
        else
            -- print("[BIS] Slot:", slotName, "NO LINK")
        end
    end
    -- Unificar STA en ITEM_MOD_STAMINA_SHORT antes de aplicar bonus racial
    if totalStats["STA"] then
        totalStats["ITEM_MOD_STAMINA_SHORT"] = (totalStats["ITEM_MOD_STAMINA_SHORT"] or 0) + totalStats["STA"]
        totalStats["STA"] = nil
    end
    -- Unificar SPI en ITEM_MOD_SPIRIT_SHORT antes de aplicar bonus racial (igual que aguante)
    if totalStats["SPI"] then
        totalStats["ITEM_MOD_SPIRIT_SHORT"] = (totalStats["ITEM_MOD_SPIRIT_SHORT"] or 0) + totalStats["SPI"]
        totalStats["SPI"] = nil
    end
    -- Aplica modificadores raciales, pero el bonus de % aguante se aplica al final y se redondea
    local staminaPct = 0
    -- Debug eliminado
    if BIS_RaceModifiers[BIS_SelectedRace] then
        for stat, value in pairs(BIS_RaceModifiers[BIS_SelectedRace]) do
            if stat == "STAMINA_PCT" then
                staminaPct = value
            elseif stat == "SHADOWRES_PCT" then
                shadowResPct = value
            elseif stat == "ARCANERES_PCT" then
                arcaneResPct = value
            elseif stat == "NATURERES_PCT" then
                natureResPct = value
            elseif stat == "FROSTRES_PCT" then
                frostResPct = value
            elseif stat == "FIRERES_PCT" then
                fireResPct = value
            elseif stat == "SPIRIT_PCT" then
                spiritPct = value
            elseif stat == "DODGE_PCT" then
                dodgePct = value
            elseif stat == "HIT_PCT" then
                hitPct_racial = (hitPct_racial or 0) + value
            else
--                totalStats[stat] = (totalStats[stat] or 0) + value
            end
        end
    end
    -- Bonus % esquiva elfo de la noche
    if dodgePct > 0 and totalStats["DODGE"] and totalStats["DODGE"] > 0 then
        local oldDodge = totalStats["DODGE"]
        totalStats["DODGE"] = math.floor(totalStats["DODGE"] * (1 + dodgePct/100) + 0.5)
    end
    -- Debug eliminado
    if staminaPct > 0 and totalStats["ITEM_MOD_STAMINA_SHORT"] and totalStats["ITEM_MOD_STAMINA_SHORT"] > 0 then
        local oldStam = totalStats["ITEM_MOD_STAMINA_SHORT"]
        totalStats["ITEM_MOD_STAMINA_SHORT"] = math.floor(totalStats["ITEM_MOD_STAMINA_SHORT"] * (1 + staminaPct/100) + 0.5)
    end
    -- Bonus % espíritu humano
    if spiritPct > 0 and totalStats["ITEM_MOD_SPIRIT_SHORT"] and totalStats["ITEM_MOD_SPIRIT_SHORT"] > 0 then
        local oldSpirit = totalStats["ITEM_MOD_SPIRIT_SHORT"]
        totalStats["ITEM_MOD_SPIRIT_SHORT"] = math.floor(totalStats["ITEM_MOD_SPIRIT_SHORT"] * (1 + spiritPct/100) + 0.5)
    end
    -- Aplicar bonus de % resistencia a las sombras como valor real
    if shadowResPct > 0 and totalStats["SHADOWRES"] and totalStats["SHADOWRES"] > 0 then
        local oldShadowRes = totalStats["SHADOWRES"]
        totalStats["SHADOWRES"] = math.floor(totalStats["SHADOWRES"] * (1 + shadowResPct/100) + 0.5)
    end
    -- Elfo de sangre: aplicar bonus de % a todas las resistencias mágicas
    if arcaneResPct > 0 and totalStats["ARCANERES"] and totalStats["ARCANERES"] > 0 then
        local oldArcane = totalStats["ARCANERES"]
        totalStats["ARCANERES"] = math.floor(totalStats["ARCANERES"] * (1 + arcaneResPct/100) + 0.5)
    end
    if natureResPct > 0 and totalStats["NATURERES"] and totalStats["NATURERES"] > 0 then
        local oldNature = totalStats["NATURERES"]
        totalStats["NATURERES"] = math.floor(totalStats["NATURERES"] * (1 + natureResPct/100) + 0.5)
    end
    if frostResPct > 0 and totalStats["FROSTRES"] and totalStats["FROSTRES"] > 0 then
        local oldFrost = totalStats["FROSTRES"]
        totalStats["FROSTRES"] = math.floor(totalStats["FROSTRES"] * (1 + frostResPct/100) + 0.5)
    end
    if fireResPct > 0 and totalStats["FIRERES"] and totalStats["FIRERES"] > 0 then
        local oldFire = totalStats["FIRERES"]
        totalStats["FIRERES"] = math.floor(totalStats["FIRERES"] * (1 + fireResPct/100) + 0.5)
    end
    -- Bonus % índice de golpe (Draenei), igual que resistencias mágicas
    local hitPct_total = (hitPct_equipo or 0) + (hitPct_racial or 0)
    if hitPct_total > 0 then
        local hitKeys = {"HIT", "HIT_RATING", "ITEM_MOD_HIT_RATING_SHORT", "TOHIT"}
        for _, key in ipairs(hitKeys) do
            if totalStats[key] and totalStats[key] > 0 then
                local oldHit = totalStats[key]
                totalStats[key] = math.floor(oldHit * (1 + hitPct_total/100) + 0.5)
            end
        end
    end
    -- Debug eliminado
    return totalStats, missingCache
end

-- Tabla de mapeo de stats a nombres amigables en español
local BIS_StatNames = {
    HEALTH = "Vida",
    FROSTRES = "Resistencia escarcha",
    SHADOWRES = "Resistencia a las sombras",
    ARCANERES = "Resistencia a lo arcano",
    NATURERES = "Resistencia a la naturaleza",
    FIRERES = "Resistencia al fuego",
    -- Alias cortos equivalentes para los stats largos oficiales
    STRENGTH = "Fuerza",
    AGILITY = "Agilidad",
    INTELLECT = "Intelecto",
    SPIRIT = "Espíritu",
    STAMINA = "Aguante",
    ATTACK_POWER = "Poder de ataque",
    SPELL_POWER = "Poder con hechizos",
    CRIT_RATING = "Crítico",
    HASTE_RATING = "Celeridad",
    HIT_RATING = "Índice de golpe",
    EXPERTISE = "Pericia",
    ARMOR_PENETRATION = "Penetración de armadura",
    MASTERY = "Maestría",
    DODGE_RATING = "Esquivar",
    PARRY_RATING = "Parar",
    RESILIENCE_RATING = "Temple",
    ARMOR = "Armadura",
    MANA_REGEN = "Regeneración de maná",
    SPELL_PENETRATION = "Penetración de hechizos",
    BLOCK_RATING = "Bloqueo",
    DEFENSE_SKILL = "Defensa",
    HIT_TAKEN = "Reducción de golpe recibido",
    CRIT_MELEE = "Crítico (Melee)",
    CRIT_RANGED = "Crítico (Distancia)",
    CRIT_SPELL = "Crítico (Hechizo)",
    -- Nombres largos oficiales
    ITEM_MOD_STRENGTH_SHORT = "Fuerza",
    ITEM_MOD_AGILITY_SHORT = "Agilidad",
    ITEM_MOD_INTELLECT_SHORT = "Intelecto",
    ITEM_MOD_SPIRIT_SHORT = "Espíritu",
    ITEM_MOD_STAMINA_SHORT = "Aguante",
    ITEM_MOD_ATTACK_POWER_SHORT = "Poder de ataque",
    ITEM_MOD_SPELL_POWER_SHORT = "Poder con hechizos",
    ITEM_MOD_CRIT_RATING_SHORT = "Crítico",
    ITEM_MOD_HASTE_RATING_SHORT = "Celeridad",
    ITEM_MOD_HIT_RATING_SHORT = "Índice de golpe",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "Pericia",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "Penetración de armadura",
    ITEM_MOD_MASTERY_RATING_SHORT = "Maestría",
    ITEM_MOD_DODGE_RATING_SHORT = "Esquivar",
    ITEM_MOD_PARRY_RATING_SHORT = "Parar",
    ITEM_MOD_RESILIENCE_RATING_SHORT = "Temple",
    ITEM_MOD_ARMOR_SHORT = "Armadura",
    ITEM_MOD_MANA_REGENERATION_SHORT = "Regeneración de maná",
    ITEM_MOD_SPELL_PENETRATION_SHORT = "Penetración de hechizos",
    ITEM_MOD_BLOCK_RATING_SHORT = "Bloqueo",
    ITEM_MOD_DEFENSE_SKILL_RATING = "Defensa",
    ITEM_MOD_HIT_TAKEN_RATING_SHORT = "Reducción de golpe recibido",
    ITEM_MOD_DODGE_RATING = "Esquivar",
    ITEM_MOD_PARRY_RATING = "Parar",
    ITEM_MOD_BLOCK_RATING = "Bloqueo",
    ITEM_MOD_CRIT_MELEE_RATING = "Crítico (Melee)",
    ITEM_MOD_CRIT_RANGED_RATING = "Crítico (Distancia)",
    ITEM_MOD_CRIT_SPELL_RATING = "Crítico (Hechizo)",
    -- Nombres cortos de GetItemStats/BonusScanner
    STR = "Fuerza",
    AGI = "Agilidad",
    INT = "Intelecto",
    SPI = "Espíritu",
    STA = "Aguante",
    CRIT = "Crítico",
    HASTE = "Celeridad",
    HIT = "Índice de golpe",
    EXP = "Pericia",
    ARMOR = "Armadura",
    MANAREG = "Reg de maná(MP5)",
    SPELLPEN = "Pen. de hechizos",
    BLOCK = "Bloqueo",
    DODGE = "Índice de esquivar",
    PARRY = "Parar",
    RESILIENCE = "Temple",
    SPELLPOW = "Poder con hechizos",
    ATTACKPOWER = "Poder de ataque",
    SPELLPOWER = "Poder con hechizos",
    -- Otros posibles
    MP5 = "Regeneración de maná (MP5)",
    ARMORPEN = "Penetración de armadura",
    MASTERY = "Maestría",
    DEFENSE = "Defensa",
    -- Puedes añadir más según lo que veas en el chat
}

local BIS_StatOrder = {
    "ITEM_MOD_STRENGTH_SHORT",
    "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_INTELLECT_SHORT",
    "ITEM_MOD_SPIRIT_SHORT",
    "ITEM_MOD_STAMINA_SHORT",
    "ITEM_MOD_ATTACK_POWER_SHORT",
    "ITEM_MOD_SPELL_POWER_SHORT",
    "ITEM_MOD_CRIT_RATING_SHORT",
    "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_HIT_RATING_SHORT",
    -- "ITEM_MOD_EXPERTISE_RATING_SHORT", -- Eliminado para no mostrar rating de pericia
    "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    "ITEM_MOD_MASTERY_RATING_SHORT",
    "ITEM_MOD_DODGE_RATING_SHORT",
    "ITEM_MOD_PARRY_RATING_SHORT",
    "ITEM_MOD_RESILIENCE_RATING_SHORT",
    "ITEM_MOD_ARMOR_SHORT",
    "ITEM_MOD_MANA_REGENERATION_SHORT",
    "ITEM_MOD_SPELL_PENETRATION_SHORT",
    "ITEM_MOD_BLOCK_RATING_SHORT",
}

-- Mostrar los stats en el frame BIS (solo los principales y con nombres legibles)
function BIS_UpdateStatsText()
    if not BIS_StatsText then return end
    -- Reducir el tamaño de fuente para los bonus raciales y limitar el ancho para ajuste automático
    if BIS_StatsText.SetFont then
        BIS_StatsText:SetFont("Fonts\\FRIZQT__.TTF", 13) -- tamaño más pequeño
    end
    if BIS_StatsText.SetWidth then
        BIS_StatsText:SetWidth(180) -- ajusta este valor si necesitas más o menos ancho
    end
    local lines = {}
    if BIS_SelectedRace == "Gnomo" then
        table.insert(lines, "|cff00bfffMaestro en escapar: Elimina efectos de enraizado o reducción de movimiento|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfff+5% al maná máximo.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffAumenta en 10 la resistencia a Arcano.")
    end
    if BIS_SelectedRace == "Trol" then
        table.insert(lines, "|cff00bfff+1% crit con Arcos/Arrojadizas.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffRabiar: Aumenta tu velocidad de ataque y lanzamiento un 20%.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffRegeneración: 10% más regeneración de vida; puedes regenerar en combate.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffMatanza de bestias: Infliges 5% más de daño a bestias.|r")
    end
    if BIS_SelectedRace == "Tauren" then
        table.insert(lines, "|cff00bfffPisotón de guerra: Aturde hasta 5 enemigos cercanos durante 2 s.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffResistencia a la Naturaleza: Aumenta en 10 tu resistencia a Naturaleza.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfff+5% salud base.|r")
    end
    if BIS_SelectedRace == "No-muerto" then
        table.insert(lines, "|cff00bfff+10 resistencia a sombras.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffVoluntad de los Renegados: Rompe miedo, sueño y encantamiento.|r")
    end
    if BIS_SelectedRace == "Humano" then
        table.insert(lines, "|cff00bfff+3 pericia en espadas y mazas.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfff+3% espiritu.|r")
    end
    if BIS_SelectedRace == "Elfo de sangre" then
        table.insert(lines, "|cff00bfffResistencia mágica: Aumenta en 2% tu resistencia a todas las escuelas mágicas.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffSilencia a los enemigos cercanos 2 s e interrumpe lanzamientos, y restaura energía/maná/poder rúnico.|r")
    end
    if BIS_SelectedRace == "Enano" then
        table.insert(lines, "|cff00bfff+5 pericia con mazas.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffEspecialización con armas de fuego: Aumenta en 1% la probabilidad de crítico con armas de fuego.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffForma de piedra: Elimina veneno, enfermedades y sangrados, y aumenta tu armadura un 10% durante 8 s.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfff+1% resistencia a la escarcha.|r")
    end
    if BIS_SelectedRace == "Elfo de la noche" then
        table.insert(lines, "|cff00bfff+2% esquivar.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfff+1% resistencia a la naturaleza.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffFusión de las Sombras: Te oculta, como Pícaro o Druida en sigilo.|r")
    end
    if BIS_SelectedRace == "Orco" then
        table.insert(lines, "|cff00bfff+5 pericia con hachas y armas de asta.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffFuria sangrienta: Aumenta tu poder de ataque y poder con hechizos durante 15 s, pero reduce sanación recibida un 50% mientras dura.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffDureza: Reduce la duración de aturdimientos un 15%.|r")
        table.insert(lines, "|cff00bfffMando: Tus mascotas infligen 5% más de daño.|r")
    end
        if BIS_SelectedRace == "Draenei" then
        table.insert(lines, "|cff00bfff+1% resistencia a las sombras.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffPresencia heroica: Aumenta en 1% la probabilidad de golpe de todo tu grupo de 5 jugadores.|r")
        table.insert(lines, "") -- línea vacía
        table.insert(lines, "|cff00bfffDon de los Naaru: Sana a lo largo de 15 s.|r")
    end
    BIS_StatsText:SetText(table.concat(lines, "\n"))
end

-- Actualizar stats al cambiar set, guardar/cargar equipo o editar slot
local old_LoadBIS = LoadBIS
function LoadBIS(...)
    if old_LoadBIS then old_LoadBIS(...) end
    BIS_UpdateStatsText()
end
local old_SaveBIS = SaveBIS
function SaveBIS(...)
    if old_SaveBIS then old_SaveBIS(...) end
    BIS_UpdateStatsText()
end
-- También actualizar al abrir el frame
local old_ToggleBISFrame = ToggleBISFrame
ToggleBISFrame = function(...)
    if old_ToggleBISFrame then old_ToggleBISFrame(...) end
    BIS_UpdateStatsText()
end

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

-- Comando para mostrar los stats totales en el chat
SLASH_BISSTATS1 = "/bisstats"
SlashCmdList["BISSTATS"] = function()
    local stats = BIS_CalculateStats()
    -- print("Resumen de stats del set BIS actual:")
    for stat, value in pairs(stats) do
    -- print(stat..": "..value)
    end
    if not next(stats) then
    -- print("No hay piezas válidas configuradas en el set BIS actual.")
    end
end

