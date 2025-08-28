-- Inicializar backup por personaje para que siempre exista y se guarde
if not GS_CharBackup then GS_CharBackup = {} end
-- ================== COPIA DE SEGURIDAD DE GS_DATA ===================
-- Copia profunda de tablas (no referencia)
local function GS_DeepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[GS_DeepCopy(orig_key)] = GS_DeepCopy(orig_value)
		end
		setmetatable(copy, GS_DeepCopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end


-- Comando para crear copia de seguridad en SavedVariablesPerCharacter
SLASH_GS_BACKUP1 = "/gsbackup"
SlashCmdList["GS_BACKUP"] = function()
	if GS_Data then
		GS_CharBackup = GS_DeepCopy(GS_Data)
		print("|cff00ff00[GearScore]|r Copia de seguridad creada en GS_CharBackup (por personaje).")
	else
		print("|cffff0000[GearScore]|r No hay datos para respaldar.")
	end
end

-- Comando para restaurar la copia de seguridad desde SavedVariablesPerCharacter
SLASH_GS_RESTORE1 = "/gsrestore"
SlashCmdList["GS_RESTORE"] = function()
	if GS_CharBackup then
		GS_Data = GS_DeepCopy(GS_CharBackup)
		-- Reparar estructura mínima necesaria
		if not GS_Data then GS_Data = {} end
		local realm = GetRealmName() or "UnknownRealm"
		if not GS_Data[realm] then GS_Data[realm] = { ["Players"] = {} } end
		if not GS_Data[realm].Players then GS_Data[realm].Players = {} end
		print("|cff00ff00[GearScore]|r GS_Data restaurado desde GS_CharBackup (por personaje).")
	else
		print("|cffff0000[GearScore]|r No hay copia de seguridad para restaurar en GS_CharBackup.")
	end
end


-------------------------------------------------------------------------------
--                              GearScore                                    --
--                    Version 3.2 mejorado por txarly                                 --
--								Mirrikat45                                   --
-------------------------------------------------------------------------------

-- Fixed a bug where you would see a target's equipment on mouseover instead of the intended player.
-- Fixed a bug where you couldn't see the Helm, Neck, Shoulders, and Back equipment of a player in the GS window.
-- Fixed a bug where "/gs <name>" would not work when the XP or Options frames were visible.
-- Fixed a similar bug when targeting a player with the options window open.
-- On the GS Window, GearScore will now display as "Raw GearScore".
-- I am still finding a large number of players who dont know about the /gs screen. I have added a message on the tooltip informing them of the /gs option. You can disable this message by visiting the options and unchecking the box.
-- THe new Show Help/Tips option will also enable/disable a few additional tooltips.
-- The Minimum Level option for the Database will now correctly set.
-- GearScore will no longer automatically update on mouseover. You must target a player to capture a new updated Score. While mousing over a player you will see a "*" next to the word "GearScore" to remind you that the info may be out of date.
-- Upgraded the DATE tooltip system. The tooltip will now show when the player was last scanned in the format "*Scanned X min/hour/days ago.".
-- The Date tooltip system is now on by default.
-- The Date tooltip system can now be turned on/off in the options menu.
-- New API for the Date system. For addon authors who use GearScore. You can now call:   GearScore_GetAge(ScanDate) - ScanDate should be the timestamp the player was scanned on. Timestamp is in teh format of  YYYYMMDDHHMM. Example: "December 28, 2010 at 12:45pm" is 200812281245.
-- This function returns: Message, Red, Green, Blue, Quantity, Scale. Message is the message shown on the tooltip such as "*Scanned 8 hours ago". Red, Green, and Blue return the color code for that message. Quantity is the amount of difference. For the previous example of 8 hours, Quantity would be returned as 8. Scale lets you know what the 8 represents. It will be either "minutes", "hours", "days", or "months".
-- Most functions of GearScore are disabled while in combat to prevent any lag or unwanted effects. I have decided to enable a function that requires manual operation to work.
-- If you're using the /gs window and target another player then the window will update for that player even if your in combat. However the addon will not inspect to request new information if your in combat. Mostly this will allow players to check gear/stats/expereince on a raid member while clearing trash.
-- Added Halion 10/25 to MISC group of the EXP tab.
GS_BlockAllInspects = false
GS_HookEnabled = true
------------------------------------------------------------------------------
function GearScore_OnUpdate(self, elapsed)
--Code use to Function Timing of Transmition Information--
	if not GSX_Timer then GSX_Timer = 0; end
	GSX_Timer = GSX_Timer + elapsed
	if GSX_Timer >= 0.5 then
		GSX_Timer = 0
		self:Hide()
		GearScore_ContinueExchange()
	end
end

function GearScore_ThrottleUpdate(self, elapsed)
--Code use to Function Timing of Transmition Information--
	if not GS_ThrottleTimer then GS_ThrottleTimer = 0; end
	GS_ThrottleTimer = GS_ThrottleTimer + elapsed
	if GS_ThrottleTimer >= 1 then
		GearScoreChatMessageThrottle = 0
		GS_ThrottleTimer = 0
	end
end

function GearScore_OnEvent(GS_Nil, GS_EventName, GS_Prefix, GS_AddonMessage, GS_Whisper, GS_Sender)
	if ( GS_EventName == "PLAYER_REGEN_ENABLED" ) then GS_PlayerIsInCombat = false; return; end
	if ( GS_EventName == "PLAYER_REGEN_DISABLED" ) then GS_PlayerIsInCombat = true; return; end
	if ( GS_EventName == "EQUIPMENT_SWAP_PENDING" ) then GS_PlayerIsSwitchingGear = true; GS_PlayerSwappedGear = 0; return; end
	if ( GS_EventName == "EQUIPMENT_SWAP_FINISHED" ) then
		GearScore_GetScore(UnitName("player"), "player");
		GearScore_Send(UnitName("player"), "ALL");
		local Red, Blue, Green = GearScore_GetQuality(GS_Data[GetRealmName()].Players[UnitName("player")].GearScore)
		PersonalGearScore:SetText(GS_Data[GetRealmName()].Players[UnitName("player")].GearScore); PersonalGearScore:SetTextColor(Red, Green, Blue, 1)
		GS_PlayerIsSwitchingGear = nil;
	return;
	end

	if ( GS_EventName == "CHAT_MSG_CHANNEL" ) then
		local Who = GS_AddonMessage; local Message = GS_Prefix; local ExtraMessage = ""; local ColorClass = ""; local Channel = GS_Sender
		if GS_Data[GetRealmName()].Players[Who] then
			if GS_Data[GetRealmName()].Players[Who].Class and GS_Classes[GS_Data[GetRealmName()].Players[Who].Class] and GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Who].Class]] then
				ColorClass = "|cff"..string.format("%02x%02x%02x", GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Who].Class]].Red * 255, GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Who].Class]].Green * 255, GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Who].Class]].Blue * 255)
			else
				ColorClass = "|cffffffff" -- Blanco por defecto
			end
			local Red, Green, Blue = GearScore_GetQuality(GS_Data[GetRealmName()].Players[Who].GearScore)
			local ColorGearScore = "|cff"..string.format("%02x%02x%02x", Red * 255, Blue * 255, Green * 255)
			ExtraMessage = "("..ColorGearScore..tostring(GS_Data[GetRealmName()].Players[Who].GearScore).."|r)" ;

		end

		if string.find(Channel, "Trade") then
			--print("StringFound!")
			local A, B = string.find(Channel, "Trade"); Channel = string.sub(Channel, 1, B)
		end
		Channel = "["..Channel.."] "

		local NewMessage = Channel..ExtraMessage.."|Hplayer:"..Who.."|h["..ColorClass..Who.."|r]|h: "..Message
		--print(NewMessage)

	end

	if ( GS_EventName == "INSPECT_ACHIEVEMENT_READY" ) then
		-- Verificar que tenemos un target válido antes de procesar achievements
		if UnitExists("target") and UnitName("target") then
			local success, err = pcall(GearScoreCalculateEXP)
			if not success then
				print("|cffff0000GearScore:|r Error al procesar achievements: " .. tostring(err))
			end
			if ( GS_DisplayFrame:IsVisible() ) then 
				GS_DisplayXP(UnitName("target")); 
				--GearScoreClassScan(UnitName("target"));
			end
		end
	end
	
	if ( GS_EventName == "INSPECT_READY" ) then
		-- Procesar la inspección completada para obtener el GearScore
		if UnitExists("target") and UnitName("target") and CanInspect("target") then
			GearScore_GetScore(UnitName("target"), "target");
			if ( GS_DisplayFrame and GS_DisplayFrame:IsVisible() ) then 
				GearScore_DisplayUnit(UnitName("target"), 1);
			end
		end
	end

	if ( GS_EventName == "PLAYER_EQUIPMENT_CHANGED" ) then
		
		if ( GS_PlayerIsSwitchingGear == true ) then GS_PlayerSwappedGear = GS_PlayerSwappedGear + 1; return; end
		if ( GS_PlayerSwappedGear ) then GS_PlayerSwappedGear = GS_PlayerSwappedGear - 1; if ( GS_PlayerSwappedGear == 0 ) then GS_PlayerSwappedGear = nil; end; return; end
		GearScore_GetScore(UnitName("player"), "player");
		--GearScore_Send(UnitName("player"), "ALL")
		local Red, Blue, Green = GearScore_GetQuality(GS_Data[GetRealmName()].Players[UnitName("player")].GearScore)
		PersonalGearScore:SetText(GS_Data[GetRealmName()].Players[UnitName("player")].GearScore); PersonalGearScore:SetTextColor(Red, Green, Blue, 1)
	end
	if ( GS_EventName == "PLAYER_TARGET_CHANGED" ) then
		if UnitName("target") then 	
			GS_Data[GetRealmName()]["CurrentPlayer"] = {}; 
			
			-- Mostrar el frame inmediatamente si está visible
			if ( GS_DisplayFrame and GS_DisplayFrame:IsVisible() ) then
				if CanInspect("target") then 
					-- Notificar inspección y mostrar datos inmediatamente
					NotifyInspect("target"); 
					-- Mostrar datos básicos inmediatamente si los tenemos
					if GS_Data[GetRealmName()].Players[UnitName("target")] then
						GearScore_DisplayUnit(UnitName("target"), 1);
					else
						GearScore_StoreBasicInfo(UnitName("target"), "target");
						GearScore_DisplayUnit(UnitName("target"), 1);
					end
				else
					-- Si no podemos inspeccionar, guardamos información básica
					GearScore_StoreBasicInfo(UnitName("target"), "target");
					GearScore_DisplayUnit(UnitName("target"), 1);
				end
				
				GS_ExPFrameUpdateCounter = 0;
				GS_SCANSET(UnitName("target"));
			end
		end
		
		-- Actualizar datos del target actual
		GS_Data["CurrentTarget"] = {}
		for i = 1, 18 do
			GS_Data["CurrentTarget"][i] = GetInventoryItemLink("target", i)
		end		
	end
	if ( GS_EventName == "CHAT_MSG_ADDON" ) then
			if not (GS_Whisper == "GUILD") then return; end
			if GS_Settings["BlackList"] then if GS_Settings["BlackList"][GS_Sender] then return; end; end
		if not ( GearScoreChatMessageThrottle ) then GearScoreChatMessageThrottle = 0; end
		GearScoreChatMessageThrottle = GearScoreChatMessageThrottle + 1
		if not ( GSMega ) then GSMega = 1; end
		if ( GS_Prefix == "GSY_Version" ) and ( tonumber(GS_AddonMessage) ) and ( GS_Settings["OldVer"] ) then
			if ( tonumber(GS_AddonMessage) > GS_Settings["OldVer"] ) then 
				print("|cffff0000GearScore Pro|r");
				print("|cff00ff00Versión desbugueada y mejorada por Txarly, para sugerencias o bug contactar en DC: |r|cff0080ff" .. "txarly2_22041|r");
				GS_Settings["OldVer"] = tonumber(GS_AddonMessage);
			end
		end
		if ( GS_Prefix == "GSY_Request" ) and ( GS_Settings["Communication"] == 1 ) and ( GS_Sender ~= UnitName("player") ) then
				if not ( GearScoreChatMessageThrottle ) then GearScoreChatMessageThrottle = 0; end
				if ( GearScoreChatMessageThrottle >= 1 ) then return; end
				if ( GS_Data[GetRealmName()].Players[GS_AddonMessage] ) then GearScore_Send(GS_AddonMessage, "GUILD", GS_Sender); end
		end
		if ( GS_Prefix == "GSY" ) and ( GS_Settings["Communication"] == 1 ) and ( GS_Sender ~= UnitName("player") ) then
			if ( GS_Whisper == "RAID" ) then GS_Whisper = "PARTY"; end
			local tbl = {}
			for v in string.gmatch(GS_AddonMessage, "[^$]+") do
				tinsert(tbl, v)
			end
			if ( tbl[1] == UnitName("player") ) or (( tbl[11] ~= GS_Sender ) and ( tbl[11] ~= " ") ) then return; end
			if ( tbl[1] ) and ( tbl[2] ) and ( tbl[3] ) then
				--IF No GearScore Record was Found
				if not ( GS_Data[GetRealmName()].Players[tbl[1]] ) then
					local TestAuthenticity = GearScore_ComposeRecord(tbl, GS_Sender)
					if TestAuthenticity then return end
					if ( UnitName("mouseover") == tbl[1] ) then GameTooltip:SetUnit(tbl[1]); end
					if ( GS_DisplayPlayer == tbl[1] ) and ( GS_DisplayFrame:IsVisible() ) then GearScore_DisplayUnit(tbl[1], 1); end
					-- Check if player record exists before accessing properties
					if GS_Data[GetRealmName()].Players[tbl[1]] then
						if ( ( GS_Factions[GS_Data[GetRealmName()].Players[tbl[1]].Faction] ~= UnitFactionGroup("player") ) and ( GS_Settings["KeepFaction"] == -1 ) ) or ( ( GS_Data[GetRealmName()].Players[tbl[1]].Level < GS_Settings["MinLevel"] ) and ( tbl[1] ~= UnitName("player") ) ) then GS_Data[GetRealmName()].Players[tbl[1]] = nil; end
					end
					if ( (type(tonumber(tbl[10]))) == "number" ) then GS_Data[GetRealmName()].Players[tbl[1]] = nil; end
					return
				end

				--If GearScore Record Needs Updating
				--if  ( tonumber(GS_Data[GetRealmName()].Players[tbl[1]].GearScore) ~= tonumber(tbl[2]) ) or ( tonumber(GS_Data[GetRealmName()].Players[tbl[1]].Date) ~= tonumber(tbl[3]) ) then
				if not ( tonumber(GS_Data[GetRealmName()].Players[tbl[1]].Date) >= tonumber(tbl[3]) ) then
					if ( tonumber(tbl[3]) > GearScore_GetTimeStamp() ) then return; end
				--not ( GS_Data[GetRealmName()].Players[tbl[1]].Date > tonumber(tbl[3]) ) then
					local PreviousRecord = GS_Data[GetRealmName()].Players[tbl[1]]
					local TestAuthenticity = GearScore_ComposeRecord(tbl, GS_Sender)
					if TestAuthenticity then return end
					local CurrentRecord = GS_Data[GetRealmName()].Players[tbl[1]]
					if ( GS_DisplayPlayer == tbl[1] ) and ( GS_DisplayFrame:IsVisible() ) then GearScore_DisplayUnit(tbl[1], 1); end
					-- Check if player record exists before accessing properties
					if GS_Data[GetRealmName()].Players[tbl[1]] then
						if ( ( GS_Factions[GS_Data[GetRealmName()].Players[tbl[1]].Faction] ~= UnitFactionGroup("player") ) and ( GS_Settings["KeepFaction"] == -1 ) ) or ( ( GS_Data[GetRealmName()].Players[tbl[1]].Level < GS_Settings["MinLevel"] ) and ( tbl[1] ~= UnitName("player") ) ) then GS_Data[GetRealmName()].Players[tbl[1]] = nil; end
					end
					if ( (type(tonumber(tbl[10]))) == "number" ) then GS_Data[GetRealmName()].Players[tbl[1]] = nil; end
					return
				end
			end
		end
	end


	if ( GS_EventName == "ADDON_LOADED" ) then
		if ( GS_Prefix == "GearScore" ) then
			if not ( GS_Settings ) then	GS_Settings = GS_DefaultSettings; GS_Talent = {}; GS_TimeStamp = {}; end
			GS_PVP = {}; GS_EquipTBL = {}; GS_Bonuses = {}; GS_Timer = {}; GS_Request = {}; GS_Average = {}
			if not ( GS_Data ) then GS_Data = {}; end; if not ( GS_Data[GetRealmName()] ) then GS_Data[GetRealmName()] = { ["Players"] = {} }; end
			GS_Settings["Developer"] = 0; GS_VersionNum = 30117; GS_Settings["OldVer"] = GS_VersionNum
			for i, v in pairs(GS_DefaultSettings) do if not ( GS_Settings[i] ) then GS_Settings[i] = GS_DefaultSettings[i]; end; end
			-- Forzar configuración de tooltips activada
			GS_Settings["Player"] = 1
			if ( GS_Settings["AutoPrune"] == 1 ) then GearScore_Prune(); end
			if ( GS_Settings["Developer"] == 0 ) then print("Bienvenido a GearScore 3.2. Escribe /gs para abrir el addon y ver funcionalidades reparadas."); end
			if ( GS_Settings["Restrict"] == 1 ) then GearScore_SetNone(); end
			if ( GS_Settings["Restrict"] == 2 ) then GearScore_SetLight(); end
			if ( GS_Settings["Restrict"] == 3 ) then GearScore_SetHeavy(); end
			if ( GetGuildInfo("player") ) then GuildRoster(); end
			GearScore_GetScore(UnitName("player"), "player"); GearScore_Send(UnitName("player"), "ALL")
			if ( GetGuildInfo("player") ) and ( GS_Settings["Developer"] ~= 1 )then SendAddonMessage( "GSY_Version", GS_Settings["OldVer"], "GUILD"); end
			
			-- Tablas de traducción al español
			if not GS_Races then
				GS_Races = {
					["HU"] = "Humano",
					["NE"] = "Elfo de la noche", 
					["DW"] = "Enano",
					["GN"] = "Gnomo",
					["DR"] = "Draenei",
					["WO"] = "Huargen",
					["OR"] = "Orco",
					["UD"] = "No-muerto",
					["TA"] = "Tauren",
					["TR"] = "Trol",
					["BE"] = "Elfo de sangre",
					["GO"] = "Goblin"
				}
			end
			
			if not GS_Classes then
				GS_Classes = {
					["WA"] = "Guerrero",
					["PA"] = "Paladín",
					["HU"] = "Cazador",
					["RO"] = "Pícaro",
					["PR"] = "Sacerdote",
					["DK"] = "Caballero de la muerte",
					["SH"] = "Chamán",
					["MA"] = "Mago",
					["WL"] = "Brujo",
					["DR"] = "Druida"
				}
			end
			
			if not GS_ClassInfo then
				GS_ClassInfo = {
					["Guerrero"] = {Red = 0.78, Green = 0.61, Blue = 0.43, Equip = {}},
					["Paladín"] = {Red = 0.96, Green = 0.55, Blue = 0.73, Equip = {}},
					["Cazador"] = {Red = 0.67, Green = 0.83, Blue = 0.45, Equip = {}},
					["Pícaro"] = {Red = 1.00, Green = 0.96, Blue = 0.41, Equip = {}},
					["Sacerdote"] = {Red = 1.00, Green = 1.00, Blue = 1.00, Equip = {}},
					["Caballero de la muerte"] = {Red = 0.77, Green = 0.12, Blue = 0.23, Equip = {}},
					["Chamán"] = {Red = 0.00, Green = 0.44, Blue = 0.87, Equip = {}},
					["Mago"] = {Red = 0.41, Green = 0.80, Blue = 0.94, Equip = {}},
					["Brujo"] = {Red = 0.58, Green = 0.51, Blue = 0.79, Equip = {}},
					["Druida"] = {Red = 1.00, Green = 0.49, Blue = 0.04, Equip = {}}
				}
			end
		end
--        if ( GS_Prefix == "GearScoreRecount" ) then
--            local f = CreateFrame("Frame", "GearScoreRecountErrorFrame", UIParent);
--            f:CreateFontString("GearScoreRecountWarning")
--			f:SetFrameStrata("TOOLTIP")
--			local s = GearScoreRecountWarning; s:SetFont("Fonts\\FRIZQT__.TTF", 30); s:SetText("WARNING! GearScoreRecount MUST be disabled to use GearScore. 3.1.x")
--			s:SetPoint("BOTTOMLEFT",UIParent,"CENTER",-600,200)
--			s:Show();f:Show()
--			print("WARNING! GearScoreRecount MUST be disabled to use GearScore. Please turn it off or remove it from your addons folder, Sorry for the inconvience")
			--error("WARNING! GearScoreRecount MUST be disabled to use GearScore. Please turn it off or remove it from your addons folder, Sorry for the inconvience")
--   		end
		
	end
end

function GearScore_CheckPartyGuild(Name)
	local Group = "party"
	if UnitName("raid1") then Group = "raid"; else Group = "party"; end
	for i = 1, 40 do
		if ( UnitName(Group..i) == Name ) then return true; else return false; end
	end
end

function GearScore_ComposeRecord(tbl, GS_Sender)
	local Name, GearScore, Date, Class, Average, Race, Faction, Location, Level, Sex, Guild, Scanned, Equip = tbl[1], tonumber(tbl[2]), tonumber(tbl[3]), tbl[4], tonumber(tbl[5]), tbl[6], tbl[7], tbl[8] or "", tostring(tbl[9]), 1, tbl[10], GS_Sender, {}
--	print(Name, GearScore, Date, Class, Average, Race, Faction, Location, Level, Sex, Guild, Scanned)
	if Scanned == "LOLGearScore" or Scanned == "GearScoreBreaker" then return "InValid"; end
	if ( Scanned == " " ) then Scanned = "Unknown"; end
	for i = 12, 30 do
		if ( i ~= 15 ) then Equip[i-11] = tbl[i]; end
	end	
	if ( GS_Data[GetRealmName()].Players[Name] ) then if ( GS_Data[GetRealmName()].Players[Name].StatString ) then local StatString = GS_Data[GetRealmName()].Players[Name].StatString; end end

	
	-- Guardar historial del equipo anterior antes de actualizar
	GS_SaveEquipmentHistory(Name, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Equip, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].GearScore, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Date, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Average, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Stats)
	
	-- Preservar el historial existente
	local existingHistory = GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].EquipHistory
	
	GS_Data[GetRealmName()].Players[Name] = { ["Name"] = Name, ["GearScore"] = GearScore, ["PVP"] = 1, ["Level"] = tonumber(Level), ["Faction"] = Faction, ["Sex"] = Sex, ["Guild"] = Guild,
	["Race"] = Race, ["Class"] =  Class, ["Spec"] = 1, ["Location"] = Location or "", ["Scanned"] = Scanned, ["Date"] = Date, ["Average"] = Average, ["Equip"] = Equip, ["StatString"] = StatString, ["Stats"] = nil, ["EquipHistory"] = existingHistory}
	
	-- Actualizar botón de historial después de guardar
	if GS_DisplayPlayer == Name then
		GearScore_UpdateHistoryButton(Name)
	end
end

function GearScore_Prune()
		--local time, monthago = GearScore_GetTimeStamp()
		for i, v in pairs(GS_Data[GetRealmName()].Players) do 
			--if ( tonumber(v.Level) < GS_Settings["MinLevel"] ) then GS_Data[GetRealmName()].Players[i] = nil; end;
			if ( ( GS_Factions[v.Faction] ~= UnitFactionGroup("player") ) and ( GS_Settings["KeepFaction"] == -1 ) ) or ( ( tonumber(v.Level) < GS_Settings["MinLevel"] ) and ( v.Name ~= UnitName("player") ) ) then GS_Data[GetRealmName()].Players[v.Name] = nil; end
			if not v.GearScore or not v.Name or not v.Sex or not v.Equip or v.Location == nil or not v.Level or not v.Faction or not v.Guild or not v.Race or not v.Class or not v.Date or not v.Average or not v.Scanned then GS_Data[GetRealmName()].Players[i] = nil; end
			if ( string.find(v.Scanned, "<") ) then GS_Data[GetRealmName()].Players[v.Name] = nil; end
			if v.Guild == "<>" or v.Guild == "" then GS_Data[GetRealmName()].Players[v.Name].Guild = "*"; end
			if ( string.find(v.Guild, "<") ) then GS_Data[GetRealmName()].Players[v.Name].Guild = string.sub(v.Guild, 2, strlen(v.Guild) - 1); end
			if ( (type(tonumber(v.Guild))) == "number" ) then GS_Data[GetRealmName()].Players[v.Name] = nil; end
			if v.Scanned == "LOLGearScore" then GS_Data[GetRealmName()].Players[v.Name] = nil; end
			--if ( GearScore_GetDate(v.Date) > 30 )
			   --if ( GearScore_GetDate(v.Date) > 30 ) then print("Old Record Found     "..i); end
			  --if v.Guild == "<>" then GS_Data[GetRealmName()].Players[v.Name].Guild = "*"; end
		end
end

-- Función para almacenar información básica cuando no podemos inspeccionar
function GearScore_StoreBasicInfo(Name, Target)
	if not ( UnitIsPlayer(Target) ) then return; end
	if not Name then Name = UnitName(Target); end
	
	-- Verificar que la base de datos esté inicializada
	if not ( GS_Data ) then GS_Data = {}; end
	if not ( GS_Data[GetRealmName()] ) then GS_Data[GetRealmName()] = { ["Players"] = {} }; end
	
	-- Solo almacenar si no existe ya un registro más completo
	if GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].GearScore and GS_Data[GetRealmName()].Players[Name].GearScore > 0 then
		return -- Ya tenemos datos del jugador
	end
	
	local __, RaceEnglish = UnitRace(Target);
	local __, ClassEnglish = UnitClass(Target);
	local currentzone = GetZoneText()
	if not ( GS_Zones[currentzone] ) then 
		currentzone = "Localizacion desconocida"
	end
	local GuildName = GetGuildInfo(Target); 
	if not ( GuildName ) then GuildName = "*"; end
	
	-- Crear equipo vacío
	local TempEquip = {}
	for i = 1, 18 do
		TempEquip[i] = fullLink
	end
	
	-- Almacenar información básica con GearScore = 0 (indica que necesita escaneo completo)
	GS_Data[GetRealmName()].Players[Name] = { 
		["Name"] = Name, 
		["GearScore"] = 0, -- 0 indica que necesita inspección
		["PVP"] = 1, 
		["Level"] = UnitLevel(Target), 
		["Faction"] = GS_Factions[UnitFactionGroup(Target)], 
		["Sex"] = UnitSex(Target), 
		["Guild"] = GuildName,
		["Race"] = GS_Races[RaceEnglish], 
		["Class"] =  GS_Classes[ClassEnglish], 
		["Spec"] = 1, 
		["Location"] = GS_Zones[currentzone], 
		["Scanned"] = UnitName("player").." (sin inspección)", 
		["Date"] = GearScore_GetTimeStamp(), 
		["Average"] = 0, 
		["Equip"] = TempEquip
	}
end

function GearScore_GetItemCode(ItemLink)
	if not ( ItemLink ) then return nil; end
	local found, _, ItemString = string.find(ItemLink, "^|c%x+|H(.+)|h%[.*%]"); local Table = {}
	for v in string.gmatch(ItemString, "[^:]+") do tinsert(Table, v); end
	return Table[2]..":"..Table[3], Table[2]
end

-------------------------- Get Mouseover Score -----------------------------------
function GearScore_GetScore(Name, Target)
	-- Refuerzo: asegurar estructura de la DB
	local realm = GetRealmName() or "UnknownRealm"
	if not GS_Data then GS_Data = {} end
	if not GS_Data[realm] then GS_Data[realm] = { ["Players"] = {} } end
	if not GS_Data[realm].Players then GS_Data[realm].Players = {} end

	if ( UnitIsPlayer(Target) ) then
		local PlayerClass, PlayerEnglishClass = UnitClass(Target);
		local GearScore = 0; local PVPScore = 0; local ItemCount = 0; local LevelTotal = 0; local TitanGrip = 1; local TempEquip = {}; local TempPVPScore = 0

		if ( GetInventoryItemLink(Target, 16) ) and ( GetInventoryItemLink(Target, 17) ) then
			local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(GetInventoryItemLink(Target, 16))
			local TitanGripGuess = 0
			if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) then TitanGrip = 0.5; end
		end

		if ( GetInventoryItemLink(Target, 17) ) then
			local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(GetInventoryItemLink(Target, 17))
			if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) then TitanGrip = 0.5; end
			TempScore, ItemLevel = GearScore_GetItemScore(GetInventoryItemLink(Target, 17));
			if ( PlayerEnglishClass == "HUNTER" ) then TempScore = TempScore * 0.3164; end
			GearScore = GearScore + TempScore * TitanGrip;	ItemCount = ItemCount + 1; LevelTotal = LevelTotal + ItemLevel
			TempEquip[17] = GearScore_GetItemCode(ItemLink)
		else
			TempEquip[17] = "0:0"
		end
		
		-- Acumulador de estadísticas
		local statTotals = {}
		for i = 1, 18 do
			if ( i ~= 4 ) and ( i ~= 17 ) then
				local fullLink = GetInventoryItemLink(Target, i)
				if ( fullLink ) then
					local ItemName, _, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(fullLink)
					TempScore, ItemLevel, a, b, c, d, TempPVPScore = GearScore_GetItemScore(fullLink);
					if ( i == 16 ) and ( PlayerEnglishClass == "HUNTER" ) then TempScore = TempScore * 0.3164; end
					if ( i == 18 ) and ( PlayerEnglishClass == "HUNTER" ) then TempScore = TempScore * 5.3224; end
					if ( i == 16 ) then TempScore = TempScore * TitanGrip; end
					GearScore = GearScore + TempScore;    ItemCount = ItemCount + 1; LevelTotal = LevelTotal + ItemLevel
					--PVPScore = PVPScore + TempPVPScore
					TempEquip[i] = fullLink -- Guardar siempre el enlace completo del objeto con gemas y encantamientos

				   -- Acumular estadísticas de forma segura
				   if BonusScanner and BonusScanner.ScanItem then
					   local ItemName, ItemLink = GetItemInfo(fullLink)
					   if ItemLink then
						   local stats = BonusScanner:ScanItem(ItemLink)
						   if stats then
							   for stat, value in pairs(stats) do
								   statTotals[stat] = (statTotals[stat] or 0) + value
							   end
						   end
					   end
				   end
				else
					TempEquip[i] = "0:0"
				end
			end
		end
		-- Mostrar totales por consola (puedes adaptarlo a tu UI)
		local statOrder = {
			"STR",
			"AGI",
			"STA",
			"INT",
			"SPI",
			"ARMOR",
			"AP",
			"RAP",
			"CRIT",
			"HIT",
			"DODGE",
			"PARRY",
			"BLOCK",
			"SP",
			"HASTE",
			"ARCANERESIST",
			"FIRERESIST",
			"FROSTRESIST",
			"NATURERESIST",
			"SHADOWRESIST",
			"DEFENSE",
			"EXPERTISE",
			"RESILIENCE",
			"MP5",
			"SPELLPEN",
			"ARCANEDMG",
			"FIREDMG",
			"FROSTDMG",
			"HOLYDMG",
			"NATUREDMG",
			"SHADOWDMG",
			"HEALTH",
			"MANA",
			"SPEED",
			"SPELLHIT",
			"SPELLCRIT",
			"SPELLHASTE"
		}
		local statNames = {
		STR = "Fuerza",
		AGI = "Agilidad",
		STA = "Aguante",
		INT = "Intelecto",
		SPI = "Espíritu",
		ARMOR = "Armadura",
		AP = "Poder de ataque",
		RAP = "Poder de ataque a distancia",
		CRIT = "Crítico físico",
		HIT = "Golpe físico",
		DODGE = "Esquivar",
		PARRY = "Parar",
		BLOCK = "Bloqueo",
		SP = "Poder con hechizos",
		HASTE = "Celeridad",
		ARCANERESIST = "Resistencia a Arcano",
		FIRERESIST = "Resistencia a Fuego",
		FROSTRESIST = "Resistencia a Escarcha",
		NATURERESIST = "Resistencia a Naturaleza",
		SHADOWRESIST = "Resistencia a Sombras",
		DEFENSE = "Defensa",
		EXPERTISE = "Pericia",
		RESILIENCE = "Temple",
		MP5 = "Maná cada 5s",
		SPELLPEN = "Penetración de hechizos",
		ARCANEDMG = "Daño Arcano",
		FIREDMG = "Daño de Fuego",
		FROSTDMG = "Daño de Escarcha",
		HOLYDMG = "Daño Sagrado",
		NATUREDMG = "Daño de Naturaleza",
		SHADOWDMG = "Daño de Sombras",
		HEALTH = "Salud",
		MANA = "Maná",
		SPEED = "Velocidad",
		SPELLHIT = "Golpe con hechizos",
		SPELLCRIT = "Crítico con hechizos",
		SPELLHASTE = "Celeridad con hechizos"
	}
		-- Eliminado para evitar duplicados: la visualización de stats solo debe hacerse en GearScore_DisplayUnit

		-- Depuración: imprimir todas las claves y valores devueltos por BonusScanner
		for k, v in pairs(statTotals) do
		end


	-- Permitir guardar aunque GearScore sea 0
	-- if ( GearScore <= 0 ) and ( Name ~= UnitName("player") ) then
	--     GearScore = 0; return;
	-- elseif ( Name == UnitName("player") ) and ( GearScore <= 0 ) then
	--     GearScore = 0; end
		
		--if ( GearScore < 0 ) and ( PVPScore < 0 ) then return 0, 0; end
		--if ( PVPScore < 0 ) then PVPScore = 0; end
		--print(GearScore, PVPScore)
		local __, RaceEnglish = UnitRace(Target);
		local __, ClassEnglish = UnitClass(Target);
		local currentzone = GetZoneText()
		if not ( GS_Zones[currentzone] ) then 
			--print("Alert! You have found a zone unknown to GearScore. Please report the zone '"..GetZoneText().." at gearscore.blogspot.com Thanks!"); 
			currentzone = "Localizacion desconocida"
		end
		local GuildName = GetGuildInfo(Target); if not ( GuildName ) then GuildName = "*"; else GuildName = GuildName; end
		-- Fusionar stats nuevos con los ya guardados, conservando el valor más alto para cada stat
		local prevStats = GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Stats or {}
		local mergedStats = {}
		for k, v in pairs(prevStats) do mergedStats[k] = v end
		for k, v in pairs(statTotals) do
			if not mergedStats[k] or v > mergedStats[k] then
				mergedStats[k] = v
			end
		end
		
		-- Guardar historial del equipo anterior antes de actualizar
		GS_SaveEquipmentHistory(Name, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Equip, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].GearScore, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Date, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Average, GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Stats)
		
		-- Preservar el historial existente
		local existingHistory = GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].EquipHistory
		
		GS_Data[GetRealmName()].Players[Name] = { ["Name"] = Name, ["GearScore"] = floor(GearScore), ["PVP"] = 1, ["Level"] = UnitLevel(Target), ["Faction"] = GS_Factions[UnitFactionGroup(Target)], ["Sex"] = UnitSex(Target), ["Guild"] = GuildName,
		["Race"] = GS_Races[RaceEnglish], ["Class"] =  GS_Classes[ClassEnglish], ["Spec"] = 1, ["Location"] = GS_Zones[currentzone], ["Scanned"] = UnitName("player"), ["Date"] = GearScore_GetTimeStamp(), ["Average"] = floor((LevelTotal / ItemCount)+0.5), ["Equip"] = TempEquip, ["Stats"] = mergedStats, ["EquipHistory"] = existingHistory }
		
		-- Actualizar botón de historial después de guardar
		if GS_DisplayPlayer == Name then
			GearScore_UpdateHistoryButton(Name)
		end
		
		-- Iniciar sistema de reintentos para gemas si es necesario
		-- Esperar un poco más antes de verificar gemas para dar tiempo a que se cargue el equipo básico
		local function delayedGemCheck()
			GearScore_CheckAndRetryGems(Name, Target)
		end
		
		-- Crear un frame temporal para retrasar la verificación de gemas
		local delayFrame = CreateFrame("Frame")
		local elapsed = 0
		delayFrame:SetScript("OnUpdate", function(self, deltaTime)
			elapsed = elapsed + deltaTime
			if elapsed >= 2.0 then -- Esperar 2 segundos antes de verificar gemas
				delayFrame:SetScript("OnUpdate", nil)
				delayedGemCheck()
			end
		end)
		
		-- Guardar las estadísticas calculadas en la base de datos del jugador
		if GS_Data[GetRealmName()].Players[Name] and statTotals then
			-- Verificar si tenemos estadísticas válidas
			local hasStats = false
			local statCount = 0
			for stat, value in pairs(statTotals) do
				if value and value > 0 then
					hasStats = true
					statCount = statCount + 1
				end
			end
			
			if hasStats then
				GS_Data[GetRealmName()].Players[Name].Stats = statTotals
				-- Estadísticas guardadas silenciosamente
			end
		end
	end
end

-- Sistema de reintentos automático para gemas
function GearScore_CheckAndRetryGems(playerName, target)
	if not playerName or not target then return end
	
	-- Solo intentar si las gemas están habilitadas
	if GS_Settings and GS_Settings["DisableGems"] then return end
	
	-- Verificar si necesitamos reintentar (si hay slots sin información completa de gemas)
	local needsRetry = false
	local incompleteSlots = {}
	
	for i = 1, 18 do
		if i ~= 4 and i ~= 17 then -- Excluir shirt y ranura
			local link = GetInventoryItemLink(target, i)
			if link then
				-- Método más robusto para detectar links incompletos
				local isIncomplete = false
				
				-- Verificar múltiples indicadores de links incompletos
				local colonCount = 0
				for c in link:gmatch(":") do
					colonCount = colonCount + 1
				end
				
				-- Un link completo típico tiene al menos 12-15 ":"
				-- Formato: |Hitem:id:ench:gem1:gem2:gem3:gem4:suffixid:unique:level:reforgeId:linkLevel|h[name]|h
				if colonCount < 10 then
					isIncomplete = true
				end
				
				-- Verificar si termina muy temprano (link truncado)
				if link:len() < 50 then
					isIncomplete = true
				end
				
				-- Verificar si no tiene gemas cuando debería (items de alto nivel)
				local itemString = link:match("|Hitem:([^|]+)|h")
				if itemString then
					local parts = {strsplit(":", itemString)}
					if #parts >= 7 then
						local itemId = tonumber(parts[1])
						local gem1, gem2, gem3, gem4 = parts[3], parts[4], parts[5], parts[6]
						
						-- Si es un item de raid/heroico y no tiene información de gemas, probablemente esté incompleto
						if itemId and itemId > 40000 then -- Items de WOTLK en adelante
							if (not gem1 or gem1 == "" or gem1 == "0") and 
							   (not gem2 or gem2 == "" or gem2 == "0") and
							   (not gem3 or gem3 == "" or gem3 == "0") and
							   (not gem4 or gem4 == "" or gem4 == "0") then
								-- Podría tener gemas pero no estar cargadas
								local itemName, itemLink, itemRarity, itemLevel = GetItemInfo(link)
								if itemLevel and itemLevel >= 200 then -- Items de nivel alto que podrían tener gemas
									isIncomplete = true
								end
							end
						end
					end
				end
				
				if isIncomplete then
					needsRetry = true
					table.insert(incompleteSlots, i)
				end
			end
		end
	end
	
	if needsRetry and #incompleteSlots > 0 then
		-- Mostrar mensaje solo si el debug está activado
		if GS_Settings and GS_Settings["DebugGems"] then
			print("|cffFFFF00GearScore:|r Detectados " .. #incompleteSlots .. " slots con gemas incompletas (slots: " .. table.concat(incompleteSlots, ", ") .. "). Reintentando automáticamente...")
		end
		
		-- Programar reintentos automáticos
		GearScore_ScheduleGemRetry(playerName, target, incompleteSlots, 1)
	end
end

-- Función para programar reintentos
function GearScore_ScheduleGemRetry(playerName, target, incompleteSlots, attempt)
	if attempt > 5 then return end -- Aumentado a 5 intentos máximo
	
	-- Esperar más tiempo en los primeros intentos para dar tiempo a cargar
	local delay = 1.5 + (attempt * 1.0) -- 1.5s, 2.5s, 3.5s, 4.5s, 5.5s
	
	-- Usar el sistema de timer clásico de WoW
	local function retryFunction()
		if not UnitExists(target) then return end
		
		local stillIncomplete = {}
		local updated = false
		
		-- Verificar qué slots siguen incompletos con detección mejorada
		for _, slot in ipairs(incompleteSlots) do
			local link = GetInventoryItemLink(target, slot)
			if link then
				local isComplete = true
				
				-- Usar la misma lógica mejorada de detección
				local colonCount = 0
				for c in link:gmatch(":") do
					colonCount = colonCount + 1
				end
				
				if colonCount < 10 or link:len() < 50 then
					isComplete = false
				end
				
				-- Verificar información de gemas más detalladamente
				local itemString = link:match("|Hitem:([^|]+)|h")
				if itemString and isComplete then
					local parts = {strsplit(":", itemString)}
					if #parts >= 7 then
						local itemId = tonumber(parts[1])
						local gem1, gem2, gem3, gem4 = parts[3], parts[4], parts[5], parts[6]
						
						if itemId and itemId > 40000 then
							-- Verificar si deberían tener gemas pero aparecen vacías
							local itemName, itemLink, itemRarity, itemLevel = GetItemInfo(link)
							if itemLevel and itemLevel >= 200 then
								-- Para items de alto nivel, verificar si las gemas están realmente cargadas
								if gem1 == "0" and gem2 == "0" and gem3 == "0" and gem4 == "0" then
									-- Podría estar incompleto, pero ser más conservador en reintentos avanzados
									if attempt <= 3 then
										isComplete = false
									end
								end
							end
						end
					end
				end
				
				if isComplete then
					-- Este slot ahora tiene información completa, actualizar
					if GS_Data[GetRealmName()].Players[playerName] and GS_Data[GetRealmName()].Players[playerName].Equip then
						local oldLink = GS_Data[GetRealmName()].Players[playerName].Equip[slot]
						GS_Data[GetRealmName()].Players[playerName].Equip[slot] = link
						
						-- Si el link cambió, recalcular GearScore del item
						if oldLink ~= link then
							-- Recalcular GearScore total si tenemos BonusScanner y el link cambió significativamente
							if BonusScanner and BonusScanner.ScanItem then
								-- Aquí podríamos recalcular el GearScore completo, pero por simplicidad
								-- dejamos que la actualización de la interfaz se encargue
							end
							updated = true
						end
					end
				else
					table.insert(stillIncomplete, slot)
				end
			else
				-- Si no hay link, el item podría haberse desequipado
				table.insert(stillIncomplete, slot)
			end
		end
		
		-- Si actualizamos algo y estamos viendo este jugador, refrescar display completamente
		if updated and GS_DisplayPlayer == playerName then
			-- Forzar actualización completa de la interfaz
			GearScore_DisplayUnit(playerName, true)
			
			-- Forzar recarga del modelo 3D si está habilitado
			if GS_Model and not (GS_Settings and GS_Settings["DisableGems"]) then
				-- Limpiar cache del modelo para forzar recarga
				if GS_ModelCache then
					GS_ModelCache[playerName] = nil
				end
				
				-- Recargar modelo con las gemas actualizadas
				local playerData = GS_Data[GetRealmName()].Players[playerName]
				if playerData and playerData.Equip then
					for slotNum, linkData in pairs(playerData.Equip) do
						if type(linkData) == "string" and linkData:find("|Hitem:") then
							-- Forzar carga del item actualizado en el modelo
							local itemName, itemLink = GetItemInfo(linkData)
							if itemLink then
								GS_Model:TryOn(itemLink)
							end
						end
					end
				end
			end
			
			-- Mensaje de éxito solo si debug está activado
			if GS_Settings and GS_Settings["DebugGems"] then
				local slotsUpdated = #incompleteSlots - #stillIncomplete
				print("|cffFFFF00GearScore:|r " .. slotsUpdated .. " slots actualizados e interfaz refrescada en intento " .. attempt)
			end
		end
		
		-- Si aún hay slots incompletos, programar otro intento
		if #stillIncomplete > 0 then
			if GS_Settings and GS_Settings["DebugGems"] then
				print("|cffFFFF00GearScore:|r Aún quedan " .. #stillIncomplete .. " slots incompletos, reintentando...")
			end
			GearScore_ScheduleGemRetry(playerName, target, stillIncomplete, attempt + 1)
		elseif GS_Settings and GS_Settings["DebugGems"] then
			print("|cffFFFF00GearScore:|r ¡Todas las gemas cargadas exitosamente!")
		end
	end
	
	-- Crear un frame temporal para el timer
	local timerFrame = CreateFrame("Frame")
	local elapsed = 0
	timerFrame:SetScript("OnUpdate", function(self, deltaTime)
		elapsed = elapsed + deltaTime
		if elapsed >= delay then
			timerFrame:SetScript("OnUpdate", nil)
			retryFunction()
		end
	end)
end

-------------------------------------------------------------------------------
	--attempt to obtain raid members GearScores
function GearScore_GetGroupScores()
	--Is this Called by anything?
end

-------------------------------------------------------------------------------
function GearScore_EquipCompare(Tooltip, ItemScore, ItemSlot, GS_ItemLink)
	if ( ItemSlot == 50 ) then return; end
	local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(GS_ItemLink)
	local HunterMultiplier = 1
	local TokenLink, TokenNumber = GearScore_GetItemCode(ItemLink)
	if ( GS_Tokens[TokenNumber] ) then
		ItemSlot = GS_Tokens[TokenNumber].ItemSlot
		ItemScore = GS_Tokens[TokenNumber].ItemScore
		ItemSubType = GS_Tokens[TokenNumber].ItemSubType
	end
	local X = ""; local Red = 0; local Blue = 0; local Green = 0; local Table = {};	local NoTable = {}; local Count = 1; local PartySize = 0; local Group = "party"; local CompareScore = 0; local Percent = 0
	-- Determine if we're in a raid or party
	if UnitName("raid1") then 
		Group = "raid"
		PartySize = GetNumRaidMembers()
	else 
		Group = "party"
		PartySize = GetNumPartyMembers()
	end
	Tooltip:AddLine("Mejor mejora para:")
	local GSL_DataBase = GearScore_BuildDatabase("Party")
	
	for i,v in pairs(GSL_DataBase) do
	local Difference = 0
				--print( ItemSubType )
			if ( v.Class and GS_Classes[v.Class] and GS_ClassInfo[GS_Classes[v.Class]] and GS_ClassInfo[GS_Classes[v.Class]].Equip and GS_ClassInfo[GS_Classes[v.Class]].Equip[ItemSubType] ) or ( ItemEquipLoc == "INVTYPE_CLOAK" )  then
				if ( ItemSlot == 18 ) and v.Class == "HU" then HunterMultiplier = 5.3224; end
				if ( ( ItemSlot == 17 ) or ( ItemSlot == 16 ) or ( ItemSlot == 36 ) ) and ( v.Class == "HU" ) then HunterMultiplier = 0.3164; end
				
				--Code To fix 2H issue.

					if ( ItemSlot > 20 ) or ( ItemSlot == 16 ) then
					if ( ItemSlot == 16 ) then ItemSlot = 36; end
					local ItemName2, ItemLink2, ItemRarity2, ItemLevel2, ItemMinLevel2, ItemType2, ItemSubType2, ItemStackCount2, ItemEquipLoc2, ItemTexture2 = GetItemInfo("item:"..v.Equip[ItemSlot - 20])
					local ItemName3, ItemLink3, ItemRarity3, ItemLevel3, ItemMinLevel3, ItemType3, ItemSubType3, ItemStackCount3, ItemEquipLoc3, ItemTexture3 = GetItemInfo("item:"..v.Equip[ItemSlot - 19])
					if ( ItemLink2 ) then ItemScore2 = GearScore_GetItemScore(ItemLink2); else ItemScore2 = 0; end
					if ( ItemLink3 ) then ItemScore3 = GearScore_GetItemScore(ItemLink3); else ItemScore3 = 0; end
					if ( ItemScore2 > ItemScore3 ) then CompareScore = ItemScore3; else CompareScore = ItemScore2; end
					--if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) then
					if ( ItemSlot ~= 31 ) and ( ItemSlot ~= 32 ) and ( ItemSlot ~= 33 ) and ( ItemSlot ~= 34 ) then
						Difference = floor((ItemScore - ( ItemScore2 + ItemScore3 )) * HunterMultiplier)
					else
						Difference = floor((ItemScore - ( CompareScore )) * HunterMultiplier)
					end
				else
					local ItemName2, ItemLink2, ItemRarity2, ItemLevel2, ItemMinLevel2, ItemType2, ItemSubType2, ItemStackCount2, ItemEquipLoc2, ItemTexture2 = GetItemInfo("item:"..v.Equip[ItemSlot])
					if ( ItemLink2 ) then ItemScore2 = GearScore_GetItemScore(ItemLink2); else ItemScore2 = 0; end
					Difference = floor(((ItemScore) - (ItemScore2)) * HunterMultiplier )
				end
				Percent = floor((Difference / v.GearScore) * 10000 ) / 100
				if ( Percent > 99.99 ) or ( v.GearScore == ( 4/0 ) ) then Percent = 99.99; end
				Table[Count] = { ["Name"] = v.Name, ["Percent"] = Percent, ["Difference"] = Difference, ["Class"] = GS_Classes[v.Class] }
				Count = Count + 1
			end
		--end
	end
	table.sort(Table, function(a, b) return a.Percent > b.Percent end)
	for i, v in ipairs(Table) do
		local Red = 0; local Blue = 0; local Green = 0; local X = ""
		if ( v.Percent > 0 ) then Green = 1; X = "+"; end
		if ( v.Percent < 0 ) then Red = 1; end
		if ( v.Percent == 0 ) then Red = 1; Green = 1; v.Percent = "0.00"; end
		-- Verificar que existe la información de clase antes de usarla
		local classInfo = GS_ClassInfo and GS_ClassInfo[v.Class]
		if classInfo then
			Tooltip:AddDoubleLine(v.Name, X..v.Percent.."% ("..X..v.Difference..")", classInfo.Red, classInfo.Green, classInfo.Blue, Red, Green, Blue)
		else
			-- Si no hay información de clase, usar color blanco por defecto
			Tooltip:AddDoubleLine(v.Name, X..v.Percent.."% ("..X..v.Difference..")", 1, 1, 1, Red, Green, Blue)
		end
	end
	for i = 1, PartySize do 
		local unitName = UnitName(Group..i)
		if unitName and not GS_Data[GetRealmName()].Players[unitName] then 
			-- Verificar información de clase para UnitClass
			local _, unitClass = UnitClass(Group..i)
			local classInfo = GS_ClassInfo and GS_ClassInfo[unitClass]
			if classInfo then
				Tooltip:AddDoubleLine(unitName, "No Data", classInfo.Red, classInfo.Green, classInfo.Blue, 1, 1, 1)
			else
				Tooltip:AddDoubleLine(unitName, "No Data", 1, 1, 1, 1, 1, 1)
			end
		elseif unitName and GS_Data[GetRealmName()].Players[unitName] then
			local playerClass = GS_Data[GetRealmName()].Players[unitName].Class
			local classInfo = GS_ClassInfo and GS_ClassInfo[playerClass]
			if not (classInfo and classInfo.Equip and classInfo.Equip[ItemSubType]) then
				local _, unitClass = UnitClass(Group..i)
				local unitClassInfo = GS_ClassInfo and GS_ClassInfo[unitClass]
				if unitClassInfo then
					Tooltip:AddDoubleLine(unitName, "No Data", unitClassInfo.Red, unitClassInfo.Green, unitClassInfo.Blue, 1, 1, 1)
				else
					Tooltip:AddDoubleLine(unitName, "No Data", 1, 1, 1, 1, 1, 1)
				end
			end
		end
	end
end

------------------------------ Get Item Score ---------------------------------
function GearScore_GetItemScore(ItemLink)
	local QualityScale = 1; local PVPScale = 1; local PVPScore = 0; local GearScore = 0
	if not ( ItemLink ) then return 0, 0; end
	local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(ItemLink); local Table = {}; local Scale = 1.8618
	if ( ItemRarity == 5 ) then QualityScale = 1.3; ItemRarity = 4;
	elseif ( ItemRarity == 1 ) then QualityScale = 0.005;  ItemRarity = 2
	elseif ( ItemRarity == 0 ) then QualityScale = 0.005;  ItemRarity = 2 end
	if ( ItemRarity == 7 ) then ItemRarity = 3; ItemLevel = 187.05; end
	local TokenLink, TokenNumber = GearScore_GetItemCode(ItemLink)
	if ( GS_Tokens[TokenNumber] ) then return GS_Tokens[TokenNumber].ItemScore, GS_Tokens[TokenNumber].ItemLevel, GS_Tokens[TokenNumber].ItemSlot; end
	if ( GS_ItemTypes[ItemEquipLoc] ) then
		if ( ItemLevel > 120 ) then Table = GS_Formula["A"]; else Table = GS_Formula["B"]; end
		if ( ItemRarity >= 2 ) and ( ItemRarity <= 4 )then
			local Red, Green, Blue = GearScore_GetQuality((floor(((ItemLevel - Table[ItemRarity].A) / Table[ItemRarity].B) * 1 * Scale)) * 12.25 )
			GearScore = floor(((ItemLevel - Table[ItemRarity].A) / Table[ItemRarity].B) * GS_ItemTypes[ItemEquipLoc].SlotMOD * Scale * QualityScale)
			if ( ItemLevel == 187.05 ) then ItemLevel = 0; end
			if ( GearScore < 0 ) then GearScore = 0;   Red, Green, Blue = GearScore_GetQuality(1); end
			GearScoreTooltip:SetOwner(GS_Frame1, "ANCHOR_Right")
			if ( PVPScale == 0.75 ) then PVPScore = 1; GearScore = GearScore * 1; 
			else PVPScore = GearScore * 0; end
			GearScore = floor(GearScore)
			PVPScore = floor(PVPScore)
			return GearScore, ItemLevel, GS_ItemTypes[ItemEquipLoc].ItemSlot, Red, Green, Blue, PVPScore, ItemEquipLoc;
		end
	end
	return -1, ItemLevel, 50, 1, 1, 1, PVPScore, ItemEquipLoc
end
-------------------------------------------------------------------------------

---------------------------- Request Information ------------------------------
function GearScore_Request(GS_Target)
	if not ( GearScoreChatMessageThrottle ) then GearScoreChatMessageThrottle = 0; end
	if ( GearScoreChatMessageThrottle >= 5 ) then return; end
	if ( GS_Settings["Communication"] == 1 ) then
			if ( GetGuildInfo("player") ) then SendAddonMessage( "GSY_Request", GS_Target, "GUILD"); --SendAddonMessage( "GSY_Version", GS_Settings["OldVer"], "GUILD"); 
			end
	end
end
-------------------------------------------------------------------------------
												
---------------------------- Send Information ------------------------------
function GearScore_Send(Name, Group, Target)
	if Group == "RAID" then Group = "GUILD"; end --Command to convert info to only Guild Channel
	if not ( GearScoreChatMessageThrottle ) then GearScoreChatMessageThrottle = 0; end
	if ( GearScoreChatMessageThrottle >= 1 ) then return; end
		
	if ( GS_PlayerIsInCombat ) then return; end
	local GS_MessageA, GS_MessageB, GS_MessageC, GS_MessageD, GS_Lenght = "", "", "", "", 0
	if ( GS_Settings["Communication"] == 1 ) then
		GS_TempVersion = GS_VersionNum
		if ( GS_Settings["Developer"] ) then GS_TempVersion = ""; end
			if ( Name ) and ( GS_Data[GetRealmName()].Players[Name] ) then
				local A = GetRealmName()
				local playerData = GS_Data[A].Players[Name]
				-- Protección contra valores nil
				local location = playerData.Location or ""
				local race = playerData.Race or ""
				local faction = playerData.Faction or ""
				
				GS_MessageA = playerData.Name.."$"..playerData.GearScore.."$"..playerData.Date.."$"..playerData.Class.."$"
				GS_MessageB = tostring(playerData.Average or 0).."$"..race.."$"..faction.."$"..location.."$"
				--GS_MessageC = GS_Data[A].Players[Name].Level.."$"..GS_Data[A].Players[Name].Sex.."$"..GS_Data[A].Players[Name].Guild.."$"..GS_Data[A].Players[Name].Scanned
				local guild = playerData.Guild or ""
				local scanned = playerData.Scanned or ""
				GS_MessageC = playerData.Level.."$"..guild.."$"..scanned
				--print( GS_MessageC )
				GS_MessageD = "$"
				for i = 1, 18 do
					if ( i ~= 4 ) then
						local equipItem = playerData.Equip[i] or "0:0"
						GS_MessageD = GS_MessageD..equipItem.."$"
					else
						GS_MessageD = GS_MessageD.."0:0".."$"
					end
				end       
			if ( strlen(GS_MessageA..GS_MessageB..GS_MessageC..GS_MessageD) >= 252 ) then 
				GS_MessageC = playerData.Level.."$"..guild.."$".." "; 
			end
			GS_Length = strlen(GS_MessageA..GS_MessageB..GS_MessageC..GS_MessageD);
			end
			if not ( GS_Length ) then return; end
		if ( GS_Length ) and ( GS_Length < 252 ) then
			if ( Group == "ALL" ) then
				if ( GetGuildInfo("player") ) then SendAddonMessage( "GSY", GS_MessageA..GS_MessageB..GS_MessageC..GS_MessageD, "Guild"); end
				SendAddonMessage( "GSY", GS_MessageA..GS_MessageB..GS_MessageC..GS_MessageD, "RAID")
			else
				if ( Group == "GUILD" ) and not ( GetGuildInfo("player") ) then return; end
				SendAddonMessage( "GSY", GS_MessageA..GS_MessageB..GS_MessageC..GS_MessageD, Group, Target)
			end
		end
	end
end
-------------------------------------------------------------------------------

-------------------------------- Get Quality ----------------------------------

function GearScore_GetQuality(ItemScore)
	--if not ItemScore then return; end
	local Red = 0.1; local Blue = 0.1; local Green = 0.1; local GS_QualityDescription = "Legendary"
	if not ( ItemScore ) then return 0, 0, 0, "Trash"; end
	if ( ItemScore > 5999 ) then ItemScore = 5999; end
	for i = 0,6 do
		if ( ItemScore > i * 1000 ) and ( ItemScore <= ( ( i + 1 ) * 1000 ) ) then
			local Red = GS_Quality[( i + 1 ) * 1000].Red["A"] + (((ItemScore - GS_Quality[( i + 1 ) * 1000].Red["B"])*GS_Quality[( i + 1 ) * 1000].Red["C"])*GS_Quality[( i + 1 ) * 1000].Red["D"])
			local Blue = GS_Quality[( i + 1 ) * 1000].Green["A"] + (((ItemScore - GS_Quality[( i + 1 ) * 1000].Green["B"])*GS_Quality[( i + 1 ) * 1000].Green["C"])*GS_Quality[( i + 1 ) * 1000].Green["D"])
			local Green = GS_Quality[( i + 1 ) * 1000].Blue["A"] + (((ItemScore - GS_Quality[( i + 1 ) * 1000].Blue["B"])*GS_Quality[( i + 1 ) * 1000].Blue["C"])*GS_Quality[( i + 1 ) * 1000].Blue["D"])
			return Red, Green, Blue, GS_Quality[( i + 1 ) * 1000].Description
		end
	end
return 0.1, 0.1, 0.1
end
-------------------------------------------------------------------------------

------------------------------Get Date ----------------------------------------
function GearScore_GetDate(TimeStamp)
	if not (TimeStamp) then return; end
	--Example Time Stamp 12/28/1985 10:45am--> 198512281045
	local min, hour, day, month, year, GS_Date = 0; CopyStamp = TimeStamp; meridian = "am"
	local Red, Green, Blue = 0
	year = floor(TimeStamp / 100000000); TimeStamp = TimeStamp - (year * 100000000)
	month = floor(TimeStamp / 1000000); TimeStamp = TimeStamp - (month * 1000000)
	day = floor(TimeStamp / 10000); TimeStamp = TimeStamp - (day * 10000)
	hour = floor(TimeStamp / 100); TimeStamp = TimeStamp - (hour * 100)
	min = TimeStamp
	if ( hour == 24 ) then hour = 0; end
	--if ( hour >= 12 ) then
--	    meridian = "pm"; hour = hour - 12
--		if ( hour == 0 ) then hour = 12; end
--	end
	if ( min < 10 ) then min = "0"..tonumber(min); end
	GS_Date = month.."/"..day--.."/"..year
	local TempDate = GearScore_GetTimeStamp();
	--print(floor(CopyStamp / 10000), floor(TempDate / 10000))
	if ( floor(CopyStamp / 10000) == floor(TempDate / 10000) ) then GS_Date = hour..":"..min.." "--..meridian; 
	end

	--Add Color!
	local CurrentTime = GearScore_GetTimeStamp()
	local currentyear = floor(CurrentTime / 100000000); CurrentTime = CurrentTime - (currentyear * 100000000)
	local currentmonth = floor(CurrentTime / 1000000); CurrentTime = CurrentTime - (currentmonth * 1000000)
	local currentday = floor(CurrentTime / 10000); CurrentTime = CurrentTime - (currentday * 10000)
	local currenthour = floor(CurrentTime / 100); CurrentTime = CurrentTime - (currenthour * 100)
	local currentmin = CurrentTime
	local currentdays = ( currentmonth * 30 ) + currentday
	--print(currentyear, currentmonth, currentday, currenthour, currentmin)
	local totaldays = (month * 30 ) + day
	if currentdays < totaldays then currentdays = currentdays + 365; end
	Blue = 0; Red = 0; Green = 1
	--if ( (currentdays - totaldays) >= 1 ) then Red = 0; Green = 1; Blue = 0; end
	--if ( (currentdays - totaldays) > 3 ) then Green = 1; Red = 0; Blue = 0; end
	if ( (currentdays - totaldays) >= 7 ) then Green = 0.9; Red = .9; Blue = .0; end  
	if ( (currentdays - totaldays) >= 14 ) then Green = .5; Red = 1; Blue = .25; end
	if ( (currentdays - totaldays) >= 21 ) then Green = 0; Red = 1; Blue = 0; end
	--print("CurrentDay:", currentdays, "    RecordedDays:", totaldays)
	
	--365
	--1


	return currentdays - totaldays, Red, Green, Blue
end
-------------------------------------------------------------------------------


---------------------------- Get TimeStamp ------------------------------------
function GearScore_GetTimeStamp()
	local GS_Hour, GS_Minute = GetGameTime(); local monthago = 0
	local GS_Weekday, GS_Month, GS_Day, GS_Year = CalendarGetDate()
	local GS_TimeStamp = (GS_Year * 100000000) + (GS_Month * 1000000) + (GS_Day * 10000) + (GS_Hour * 100) + (GS_Minute)
	if ( GS_Month == 1 ) then
		monthago = ( ( GS_Year - 1 ) *100000000 ) + ( 12 * 1000000 ) + (GS_Day * 10000) + (GS_Hour * 100) + (GS_Minute)
	else
		monthago = (GS_Year * 100000000) + ((GS_Month - 1) * 1000000) + (GS_Day * 10000) + (GS_Hour * 100) + (GS_Minute)
	end
	return GS_TimeStamp, monthago
end
-------------------------------------------------------------------------------

-- Nueva función para convertir timestamp a fecha legible
function GearScore_GetReadableDate(TimeStamp)
	if not TimeStamp then return "Fecha desconocida", 0.5, 0.5, 0.5 end
	
	local originalTimeStamp = TimeStamp
	
	-- Extraer componentes del timestamp
	local year = floor(TimeStamp / 100000000); TimeStamp = TimeStamp - (year * 100000000)
	local month = floor(TimeStamp / 1000000); TimeStamp = TimeStamp - (month * 1000000)
	local day = floor(TimeStamp / 10000); TimeStamp = TimeStamp - (day * 10000)
	local hour = floor(TimeStamp / 100); TimeStamp = TimeStamp - (hour * 100)
	local min = TimeStamp
	
	-- Formatear minutos
	if min < 10 then min = "0"..tonumber(min) end
	
	-- Crear fecha legible en formato español
	local meses = {
		"Ene", "Feb", "Mar", "Abr", "May", "Jun",
		"Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
	}
	
	local fechaTexto = day .. " " .. (meses[month] or "???") .. " " .. year
	
	-- Calcular color basado en antigüedad usando la función original
	local Date, DateRed, DateGreen, DateBlue = GearScore_GetDate(originalTimeStamp)
	
	-- Si es del mismo día, añadir la hora
	local CurrentTime = GearScore_GetTimeStamp()
	local currentyear = floor(CurrentTime / 100000000)
	local currentmonth = floor((CurrentTime - currentyear * 100000000) / 1000000)
	local currentday = floor((CurrentTime - currentyear * 100000000 - currentmonth * 1000000) / 10000)
	
	if year == currentyear and month == currentmonth and day == currentday then
		fechaTexto = "Hoy " .. hour .. ":" .. min
	end
	
	return fechaTexto, DateRed, DateGreen, DateBlue
end

-- Función para convertir SaveTime (GetTime()) a fecha legible
function GearScore_GetReadableSaveTime(saveTime)
	if not saveTime then return "Fecha desconocida" end
	
	-- GetTime() es en segundos desde el inicio de la sesión, necesitamos convertir a fecha actual
	local currentTime = GetTime()
	local diffSeconds = currentTime - saveTime
	
	-- Si es menos de una hora, mostrar minutos
	if diffSeconds < 3600 then
		local minutes = math.floor(diffSeconds / 60)
		if minutes < 1 then
			return "hace menos de 1 min"
		else
			return "hace " .. minutes .. " min"
		end
	end
	
	-- Si es menos de un día, mostrar horas
	if diffSeconds < 86400 then
		local hours = math.floor(diffSeconds / 3600)
		return "hace " .. hours .. " hora" .. (hours > 1 and "s" or "")
	end
	
	-- Si es más de un día, usar la fecha actual menos los días
	local days = math.floor(diffSeconds / 86400)
	local GS_Weekday, GS_Month, GS_Day, GS_Year = CalendarGetDate()
	
	-- Calcular fecha aproximada (simplificado)
	local targetDay = GS_Day - days
	local targetMonth = GS_Month
	local targetYear = GS_Year
	
	-- Ajustar si el día es negativo (simplificado para demostración)
	if targetDay <= 0 then
		targetMonth = targetMonth - 1
		if targetMonth <= 0 then
			targetMonth = 12
			targetYear = targetYear - 1
		end
		targetDay = targetDay + 30  -- Aproximación simple
	end
	
	local meses = {
		"Ene", "Feb", "Mar", "Abr", "May", "Jun",
		"Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
	}
	
	return targetDay .. " " .. (meses[targetMonth] or "???")
end
-------------------------------------------------------------------------------


----------------------------- Show Tooltip ------------------------------------
function GearScore_ShowTooltip(GS_Target)
	GameTooltip:SetUnit(GS_Target)
	GameTooltip:Show()
end
-------------------------------------------------------------------------------

function GearScore_GetAge(ScanDate)
	local CurrentDate = GearScore_GetTimeStamp();
	local DateSpread = CurrentDate - ScanDate;
	if ( DateSpread == 0 ) then return "*Escaneado hace < 1 min.", 0,1,0, 0, "minutes"; end;
	if ( DateSpread < 60 ) then	return "*Escaneado hace "..DateSpread.." minutos.", 0,1,0, DateSpread, "minutes"; end;
	DateSpread = floor((DateSpread + 40) / 100);
	if ( DateSpread < 24 ) then	return "*Escaneado hace "..DateSpread.." horas.", 1,1,0, DateSpread, "hours"; end;
	DateSpread = floor(DateSpread / 100) + floor(mod(DateSpread, 100) / 24);
	if ( DateSpread < 31 ) then	return "*Escaneado hace "..DateSpread.." días.", 1,0.5,0, DateSpread, "days"; end;
	return "*Escaneado hace más de 1 mes.", 1,0,0, floor(DateSpread / 30), "months";
	
end----------------------------- Hook Set Unit -----------------------------------
function GearScore_HookSetUnit(arg1, arg2)
	GS_GearScore = nil; local Name = GameTooltip:GetUnit(); GearScore_GetGroupScores(); local PreviousRecord = {}; 
	local Age = " ";
	local Realm = ""; if UnitName("mouseover") == Name then _, Realm = UnitName("mouseover"); if not Realm then Realm = GetRealmName(); end; end
	if ( CanInspect("mouseover") ) and ( UnitName("mouseover") == Name ) and not ( GS_PlayerIsInCombat ) then 
		Age = " ";
		if (GS_DisplayFrame and GS_DisplayFrame:IsVisible()) and GS_DisplayPlayer and UnitName("mouseover") then if GS_DisplayPlayer == UnitName("mouseover") then return; end; end			
		if ( GS_Data[GetRealmName()].Players[Name] ) then PreviousRecord = GS_Data[GetRealmName()].Players[Name]; end 
		
		-- Crear registro básico del jugador si no existe (necesario para guardar estadísticas)
		if not GS_Data[GetRealmName()].Players[Name] then
			local PlayerClass, PlayerEnglishClass = UnitClass("mouseover")
			local PlayerRace, RaceEnglish = UnitRace("mouseover")
			local GuildName = GetGuildInfo("mouseover") or "Sin guild"
			local currentzone = GetZoneText()
			if not ( GS_Zones[currentzone] ) then 
				currentzone = "Localizacion desconocida"
			end
			
			GS_Data[GetRealmName()].Players[Name] = {
				["Name"] = Name,
				["GearScore"] = 0,
				["PVP"] = 1,
				["Level"] = UnitLevel("mouseover") or 1,
				["Faction"] = GS_Factions[UnitFactionGroup("mouseover")] or 1,
				["Sex"] = UnitSex("mouseover") or 1,
				["Guild"] = GuildName,
				["Race"] = GS_Races[RaceEnglish] or 1,
				["Class"] = GS_Classes[PlayerEnglishClass] or 1,
				["Spec"] = 1,
				["Location"] = GS_Zones[currentzone] or 1,
				["Scanned"] = UnitName("player"),
				["Date"] = GearScore_GetTimeStamp(),
				["Average"] = 0,
				["Equip"] = {},
				["Stats"] = nil
			}
		end
		
		NotifyInspect("mouseover"); GearScore_GetScore(Name, "mouseover"); --GS_Data[GetRealmName()]["CurrentPlayer"] = GS_Data[GetRealmName()]["Players"][Name]
		if not ( GearScore_IsRecordTheSame(GS_Data[GetRealmName()].Players[Name], PreviousRecord) ) then GearScore_Send(Name, "ALL"); end
	elseif ( CanInspect("target") ) and ( UnitName("target") == Name ) and not ( GS_PlayerIsInCombat ) then 
		Age = " ";
		if (GS_DisplayFrame and GS_DisplayFrame:IsVisible()) and GS_DisplayPlayer and UnitName("target") then if GS_DisplayPlayer == UnitName("target") then return; end; end			
		if ( GS_Data[GetRealmName()].Players[Name] ) then PreviousRecord = GS_Data[GetRealmName()].Players[Name]; end 
		
		-- Crear registro básico del jugador si no existe (necesario para guardar estadísticas)
		if not GS_Data[GetRealmName()].Players[Name] then
			local PlayerClass, PlayerEnglishClass = UnitClass("target")
			local PlayerRace, RaceEnglish = UnitRace("target")
			local GuildName = GetGuildInfo("target") or "Sin guild"
			local currentzone = GetZoneText()
			if not ( GS_Zones[currentzone] ) then 
				currentzone = "Localizacion desconocida"
			end
			
			GS_Data[GetRealmName()].Players[Name] = {
				["Name"] = Name,
				["GearScore"] = 0,
				["PVP"] = 1,
				["Level"] = UnitLevel("target") or 1,
				["Faction"] = GS_Factions[UnitFactionGroup("target")] or 1,
				["Sex"] = UnitSex("target") or 1,
				["Guild"] = GuildName,
				["Race"] = GS_Races[RaceEnglish] or 1,
				["Class"] = GS_Classes[PlayerEnglishClass] or 1,
				["Spec"] = 1,
				["Location"] = GS_Zones[currentzone] or 1,
				["Scanned"] = UnitName("player"),
				["Date"] = GearScore_GetTimeStamp(),
				["Average"] = 0,
				["Equip"] = {},
				["Stats"] = nil
			}
		end
		
		NotifyInspect("target"); GearScore_GetScore(Name, "target"); --GS_Data[GetRealmName()]["CurrentPlayer"] = GS_Data[GetRealmName()]["Players"][Name]
		if not ( GearScore_IsRecordTheSame(GS_Data[GetRealmName()].Players[Name], PreviousRecord) ) then GearScore_Send(Name, "ALL"); end
	end
	if ( GS_Data[GetRealmName()].Players[Name] ) and ( GS_Data[GetRealmName()].Players[Name].GearScore > 0 ) and ( GS_Settings["Player"] == 1 ) then 
		local Red, Blue, Green = GearScore_GetQuality(GS_Data[GetRealmName()].Players[Name].GearScore)
		
		-- Mejorar el indicador de edad basado en disponibilidad para inspección
		local canInspectNow = false
		if ( CanInspect("mouseover") ) and ( UnitName("mouseover") == Name ) and not ( GS_PlayerIsInCombat ) then
			canInspectNow = true
		elseif ( CanInspect("target") ) and ( UnitName("target") == Name ) and not ( GS_PlayerIsInCombat ) then
			canInspectNow = true
		end
		
		-- Actualizar el indicador de Age
		if canInspectNow then
			Age = " "  -- Indica que se puede actualizar
		else
			Age = " "   -- Indica datos antiguos o no disponible para inspección
		end
		
		if ( GS_Settings["Level"] == 1 ) then 
			GameTooltip:AddDoubleLine(Age.."GearScore: "..GS_Data[GetRealmName()].Players[Name].GearScore, "(iLevel: "..GS_Data[GetRealmName()].Players[Name].Average..")", Red, Green, Blue, Red, Green, Blue)
			if ( GS_Settings["Date2"] == 1 ) and ( Age ~= " " ) then 
				local NoWDate, DateRed, DateGreen, DateBlue = GearScore_GetAge(GS_Data[GetRealmName()].Players[Name].Date); 
				--print(GearScore_GetAge(GS_Data[GetRealmName()].Players[Name].Date));
				GameTooltip:AddLine(NoWDate, DateRed, DateGreen, DateBlue);
				if not canInspectNow and UnitName("mouseover") == Name then
					GameTooltip:AddLine("|cffFFFF00Haz click para targetear e inspeccionar|r", 1, 1, 0);
				end
			end
		else
			GameTooltip:AddLine(Age.."GearScore: "..GS_Data[GetRealmName()].Players[Name].GearScore, Red, Green, Blue)
			if ( GS_Settings["Date2"] == 1 ) and ( Age == "*" ) then 
				local NoWDate, DateRed, DateGreen, DateBlue = GearScore_GetAge(GS_Data[GetRealmName()].Players[Name].Date); 
				--print(GearScore_GetAge(GS_Data[GetRealmName()].Players[Name].Date));
				GameTooltip:AddLine(NoWDate, DateRed, DateGreen, DateBlue); 
			end
		end
		if ( GS_Settings["Compare"] == 1 ) then
			local MyGearScore = GS_Data[GetRealmName()].Players[UnitName("player")].GearScore
			local TheirGearScore = GS_Data[GetRealmName()].Players[Name].GearScore
			if ( MyGearScore  > TheirGearScore  ) then GameTooltip:AddDoubleLine("YourScore: "..MyGearScore  , "(+"..(MyGearScore - TheirGearScore  )..")", 0,1,0, 0,1,0); end
			if ( MyGearScore   < TheirGearScore   ) then GameTooltip:AddDoubleLine("YourScore: "..MyGearScore, "(-"..(TheirGearScore - MyGearScore  )..")", 1,0,0, 1,0,0); end	
			if ( MyGearScore   == TheirGearScore   ) then GameTooltip:AddDoubleLine("YourScore: "..MyGearScore  , "(+0)", 0,1,1,0,1,1); end	
		end
		
		if ( GS_Settings["Detail"] == 1 ) then GearScore_SetDetails(GameTooltip, Name); end
		if ( GS_Settings["Special"] == 1 ) and ( GS_Special[Name] ) then if ( GS_Special[Name]["Realm"] == Realm ) then GameTooltip:AddLine(GS_Special[GS_Special[Name].Type], 1, 0, 0 ); end; end
		if ( GS_Settings["Special"] == 1 ) and ( GS_Special[GS_Data[GetRealmName()].Players[Name].Guild] ) then GameTooltip:AddLine(GS_Special[GS_Special[GS_Data[GetRealmName()].Players[Name].Guild].Type], 1, 0, 0 ); end
		local EnglishFaction, Faction = UnitFactionGroup("player")
		--print(EnglishFaction)
		if ( ( GS_Factions[GS_Data[GetRealmName()].Players[Name].Faction] ~= UnitFactionGroup("player") ) and ( GS_Settings["KeepFaction"] == -1 ) ) or ( ( GS_Data[GetRealmName()].Players[Name].Level < GS_Settings["MinLevel"] ) and ( Name ~= UnitName("player") ) ) then GS_Data[GetRealmName()].Players[Name] = nil; end
--		if ( ( GS_Data[GetRealmName()].Players[Name].Level < GS_Settings["MinLevel"] ) and ( Name ~= UnitName("player") ) ) then GS_Data[GetRealmName()].Players[Name] = nil; end
		if ( GS_Settings["ShowHelp"] == 1 ) then GameTooltip: AddLine("Target this player and type /gs for detailed information. You can turn this msg off in the options screen. (/gs)", 1,1,1,1); end
	end
	--GearScore_Request(Name)
end

function GearScoreChatAdd(self, event, msg, arg1, ...)
    -- Ignorar mensajes de sistema específicos
    if msg == "No estas en grupo." then 
        return true 
    end  

    if GS_ExchangeName and msg == ("No player named '"..GS_ExchangeName.."' is currently playing.") then
        GS_ExchangeCount = nil
        print("¡Transmisión interrumpida!")
        return true
    end

    if GS_Settings["CHAT"] == 1 then
        local Who = arg1
        local Message = msg
        local ExtraMessage = ""
        local ColorClass = "|cffffffff" -- Blanco por defecto

        if GS_Data[GetRealmName()].Players[Who] then
            local playerData = GS_Data[GetRealmName()].Players[Who]
            local classToken = GS_Classes[playerData.Class]
            local classInfo = GS_ClassInfo[classToken]

            if classInfo then
                ColorClass = "|cff"..string.format("%02x%02x%02x", classInfo.Red*255, classInfo.Green*255, classInfo.Blue*255)
            end

            local Red, Green, Blue = GearScore_GetQuality(playerData.GearScore)
            local ColorGearScore = "|cff"..string.format("%02x%02x%02x", Red*255, Green*255, Blue*255)

            ExtraMessage = (ColorGearScore.."|Hplayer:X33"..Who.."|h("..tostring(playerData.GearScore)..")|h|r ")
        end

        local NewMessage = ExtraMessage..Message
        return false, NewMessage, arg1, ...
    end

    return false, msg, arg1, ...
end

-- El hook debe ir después de la función y variables globales
-- Coloca este bloque aquí para evitar el error de función no definida


--function GearScoreChatAddddd(self,event,msg,arg1,...)
--print("Captured Info: ", msg)
--return true
--end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL",GearScoreChatAdd)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY",GearScoreChatAdd)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID",GearScoreChatAdd)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD",GearScoreChatAdd)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM",GearScoreChatAdd)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",GearScoreChatAdd)
--ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_LIST",GearScoreChatAddddd)






function GearScoreSetItemRef(arg1, arg2, ...)
	if string.find(arg1, "player:X33") then
		local playerName = string.sub(arg1, 11)
		GearScore_DisplayUnit(playerName, 1)
		return
	end
	--return OriginalSetItemRef(arg1, arg2, ...)
end



function GearScore_IsRecordTheSame(Current, Previous)
	if not ( Previous.Name ) or not ( Current.Name ) then return true; end
	if ( Previous.GearScore ~= Current.GearScore ) then return false; end
	if ( Previous.Date + 10000 <= Current.Date ) then return false; end
	if ( Previous.Guild ~= Current.Guild ) then return false; end
	if ( Previous.Level ~= Current.Level ) then return false; end
	for i = 1, 18 do
		if ( i ~= 4 ) then 
			if ( Previous.Equip[i] ~= Current.Equip[i] ) then return false; end
		end
	end
	return true
end


function GearScore_SetDetails(tooltip, Name)
	if not ( GS_Data[GetRealmName()].Players[Name] ) then return; end
	for i = 1,18 do
		if not ( i == 4 ) then
		local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(GS_Data[GetRealmName()].Players[Name].Equip[i])
		if ( ItemLink ) then
			local GearScore, ItemLevel, EquipLoc, Red, Green, Blue = GearScore_GetItemScore(ItemLink)
			if ( GS_Data[GetRealmName()].Players[Name].Equip[i] ) and ( i ~= 4 ) then
				local Add = ""
				if ( GS_Settings["Level"] == 1 ) then Add = " (iLevel "..tostring(ItemLevel)..")"; end
				tooltip:AddDoubleLine("["..ItemName.."]", tostring(GearScore)..Add, GS_Rarity[ItemRarity].Red, GS_Rarity[ItemRarity].Green, GS_Rarity[ItemRarity].Blue, Red, Blue, Green)
			end
		end
		end
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function GearScore_HookSetItem() ItemName, ItemLink = GameTooltip:GetItem(); GearScore_HookItem(ItemName, ItemLink, GameTooltip); end
function GearScore_HookRefItem() ItemName, ItemLink = ItemRefTooltip:GetItem(); GearScore_HookItem(ItemName, ItemLink, ItemRefTooltip); end
function GearScore_HookCompareItem() ItemName, ItemLink = ShoppingTooltip1:GetItem(); GearScore_HookItem(ItemName, ItemLink, ShoppingTooltip1); end
function GearScore_HookCompareItem2() ItemName, ItemLink = ShoppingTooltip2:GetItem(); GearScore_HookItem(ItemName, ItemLink, ShoppingTooltip2); end
function GearScore_HookItem(ItemName, ItemLink, Tooltip)
	local PlayerClass, PlayerEnglishClass = UnitClass("player");
	local TokenLink, TokenNumber = GearScore_GetItemCode(ItemLink)
	if not ( IsEquippableItem(ItemLink) ) and not GS_Tokens[TokenNumber] then return; end
	local ItemScore, ItemLevel, EquipLoc, Red, Green, Blue, PVPScore, ItemEquipLoc = GearScore_GetItemScore(ItemLink);
	if ( ItemScore >= 0 ) then
		if ( GS_Settings["Item"] == 1 ) then
			if ( ItemLevel ) and ( GS_Settings["Level"] == 1 ) then Tooltip:AddDoubleLine("GearScore: "..ItemScore, "(iLevel "..ItemLevel..")", Red, Blue, Green, Red, Blue, Green);
				if ( PlayerEnglishClass == "HUNTER" ) then
					if ( ItemEquipLoc == "INVTYPE_RANGEDRIGHT" ) or ( ItemEquipLoc == "INVTYPE_RANGED" ) then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 5.3224), Red, Blue, Green)
					end
					if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) or ( ItemEquipLoc == "INVTYPE_WEAPONMAINHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPONOFFHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPON" ) or ( ItemEquipLoc == "INVTYPE_HOLDABLE" )  then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 0.3164), Red, Blue, Green)
					end
				end
			else
				Tooltip:AddLine("GearScore: "..ItemScore, Red, Blue, Green)
				if ( PlayerEnglishClass == "HUNTER" ) then
					if ( ItemEquipLoc == "INVTYPE_RANGEDRIGHT" ) or ( ItemEquipLoc == "INVTYPE_RANGED" ) then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 5.3224), Red, Blue, Green)
					end
					if ( ItemEquipLoc == "INVTYPE_2HWEAPON" ) or ( ItemEquipLoc == "INVTYPE_WEAPONMAINHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPONOFFHAND" ) or ( ItemEquipLoc == "INVTYPE_WEAPON" ) or ( ItemEquipLoc == "INVTYPE_HOLDABLE" )  then
						Tooltip:AddLine("HunterScore: "..floor(ItemScore * 0.3164), Red, Blue, Green)
					end
				end
			end
			-- Solo calcular scores de especializaciones si el usuario lo tiene habilitado y no es un tooltip de compras
			if ( Tooltip ~= ShoppingTooltip1 ) and ( Tooltip ~= ShoppingTooltip2 ) and ( GS_Settings["ShowSpecScores"] ) then 
				CalculateClasicItemScore(ItemLink, Tooltip, Red, Green, Blue); 
			end
		   if ( GS_Settings["ML"] == 1 ) then GearScore_EquipCompare(Tooltip, ItemScore, EquipLoc, ItemLink); end
		end
	else
		if ( GS_Settings["Level"] == 1 ) and ( ItemLevel ) then
			Tooltip:AddLine("iLevel "..ItemLevel)
		end
	end
end
function GearScore_OnEnter(Name, ItemSlot, Argument)
	if ( UnitName("target") ) then NotifyInspect("target"); GS_LastNotified = UnitName("target"); end
	local OriginalOnEnter = GearScore_Original_SetInventoryItem(Name, ItemSlot, Argument); return OriginalOnEnter
end
function MyPaperDoll()
	GearScore_GetScore(UnitName("player"), "player"); GearScore_Send(UnitName("player"), "ALL"); 
	--SendAddonMessage( "GSY_Version", GS_Settings["OldVer"], "GUILD")
	local Red, Blue, Green = GearScore_GetQuality(GS_Data[GetRealmName()].Players[UnitName("player")].GearScore)
	PersonalGearScore:SetText(GS_Data[GetRealmName()].Players[UnitName("player")].GearScore); PersonalGearScore:SetTextColor(Red, Green, Blue, 1)
end
-------------------------------------------------------------------------------

----------------------------- Reports -----------------------------------------
function GearScore_ManualReport(Group, Who, Target)   --Please Rewrite All of this Code. It sucks.

--/gspam raid whisper bob
--
--	GearScore_BuildDatabase()	
--	GearScore_SendReport("Manual", Group, Who, G_Direction)
		
end	

---------------GS-SPAM Slasch Command--------------------------------------
function GS_SPAM(Command)
	local tbl = {}
	for v in string.gmatch(Command, "[^ ]+") do tinsert(tbl, v); end
	if ( strlower(Command) == "group" ) then
		if ( UnitName("raid1") ) then Command = "raid"; else Command = "party"; end
	end
	if ( strlower(Command) == "party" ) then
		local GspamDatabase = GearScore_BuildDatabase("Party"); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end);
		GearScore_SendSpamReport("PARTY", nil, GspamDatabase)
		--GearScore_SendSpamReport(Target, Who, Database)
	end
	if ( strlower(Command) == "raid" ) then
		local GspamDatabase = GearScore_BuildDatabase("Party"); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end);
		GearScore_SendSpamReport("RAID", nil, GspamDatabase)
	end
	if ( tbl[1] == "party" ) or ( tbl[1] == "raid" ) then
		if ( tbl[2] ) then
			tbl[1] = strupper(string.sub(tbl[1], 1, 1))..strlower(string.sub(tbl[1], 2))
			tbl[2] = strupper(string.sub(tbl[2], 1, 1))..strlower(string.sub(tbl[2], 2))
			if ( tbl[2] == "Party" ) then local GspamDatabase = GearScore_BuildDatabase(tbl[1]); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end); GearScore_SendSpamReport("PARTY", nil, GspamDatabase); end
			if ( tbl[2] == "Raid" ) then local GspamDatabase = GearScore_BuildDatabase(tbl[1]); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end); GearScore_SendSpamReport("RAID", nil, GspamDatabase); end
			if ( tbl[2] == "Guild" ) then local GspamDatabase = GearScore_BuildDatabase(tbl[1]); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end); GearScore_SendSpamReport("GUILD", nil, GspamDatabase); end
			if ( tbl[2] == "Officer" ) then local GspamDatabase = GearScore_BuildDatabase(tbl[1]); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end); GearScore_SendSpamReport("OFFICER", nil, GspamDatabase); end
			if ( tbl[2] == "Say" ) then local GspamDatabase = GearScore_BuildDatabase(tbl[1]); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end); GearScore_SendSpamReport("SAY", nil, GspamDatabase); end
			if ( tbl[2] == "Whisper" ) then local GspamDatabase = GearScore_BuildDatabase(tbl[1]); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end); GearScore_SendSpamReport("WHISPER", tbl[3], GspamDatabase); end
			if ( tbl[2] == "Channel" ) then local GspamDatabase = GearScore_BuildDatabase(tbl[1]); table.sort(GspamDatabase, function(a, b) return a.GearScore > b.GearScore end); GearScore_SendSpamReport("CHANNEL", tbl[3], GspamDatabase); end
		 end
	end
end

function GS_BANSET(Command)
	if not ( GS_Settings["BlackList"] ) then GS_Settings["BlackList"] = {}; end
	if ( GS_Settings["BlackList"][Command] ) then GS_Settings["BlackList"][Command] = nil; print(Command.." eliminado de la lista de bloqueo de comunicación de GearScore.")
	else GS_Settings["BlackList"][Command] = 1; print(Command.." añadido a la lista de bloqueo de comunicación de GearScore."); end
end

function GS_MANSET(Command)
	-- Mostrar estado del modelo si es el comando estado o info
	if (strlower(Command) == "estado") or (strlower(Command) == "informacion") then
		if not GS_Settings then GS_Settings = {} end
		local modelStatus = (GS_Settings["EnableModel"] == false) and "Desactivado (Máximo rendimiento)" or "Activado"
		local gemsStatus = GS_Settings["DisableGems"] and "Desactivadas (Carga rápida)" or "Activadas"
		print("|cffFFFF00GearScore:|r Estado del modelo 3D: " .. modelStatus .. " - Usa |cff00FF00/gs3d|r para cambiar")
		print("|cffFFFF00GearScore:|r Estado de las gemas: " .. gemsStatus .. " - Usa |cff00FF00/gsgemas|r para cambiar")
		return
	end
	
	if ( strlower(Command) == "" ) or ( strlower(Command) == "opciones" ) or ( strlower(Command) == "option" ) or ( strlower(Command) == "help" ) then 
		-- Añadir comando del modelo a la lista de ayuda
		print("|cff00FF00/gs3d|r - Activar/desactivar modelo 3D para máximo rendimiento")
		print("|cff00FF00/gsgemas|r - Activar/desactivar gemas en modelo 3D (más velocidad)")
		print("|cff00FF00/gscargar|r o |cff00FF00/gsforzargemas|r - Forzar carga de gemas (útil si estás lejos)")
		print("|cff00FF00/gsprev|r o |cff00FF00/gshistorico|r - Ver equipo anterior del jugador actual")
		print("|cff00FF00/gsactual|r - Volver al equipo actual")
		print("|cff00FF00/gslista|r - Listar todos los historiales del jugador (máximo 5)")
		print("|cff00FF00/gset estado|r - Ver estado actual del modelo")
		for i,v in ipairs(GS_CommandList) do print(v); end; 
		return 
	end
	if ( strlower(Command) == "show" ) then GS_Settings["Player"] = GS_ShowSwitch[GS_Settings["Player"]]; if ( GS_Settings["Player"] == 1 ) or ( GS_Settings["Player"] == 2 ) then print("Puntuaciones de Jugador: Activadas"); else print("Puntuaciones de Jugador: Desactivadas"); end; return; end
	if ( strlower(Command) == "player" ) then GS_Settings["Player"] = GS_ShowSwitch[GS_Settings["Player"]]; if ( GS_Settings["Player"] == 1 ) or ( GS_Settings["Player"] == 2 ) then print("Puntuaciones de Jugador: Activadas"); else print("Puntuaciones de Jugador: Desactivadas"); end; return; end
	if ( strlower(Command) == "item" ) then GS_Settings["Item"] = GS_ItemSwitch[GS_Settings["Item"]]; if ( GS_Settings["Item"] == 1 ) or ( GS_Settings["Item"] == 3 ) then print("Puntuaciones de Objetos: Activadas"); else print("Puntuaciones de Objetos: Desactivadas"); end; return; end
	if ( strlower(Command) == "describe" ) then GS_Settings["Description"] = GS_Settings["Description"] * -1; if ( GS_Settings["Description"] == 1 ) then print ("Descripciones: Activadas"); else print ("Descripciones: Desactivadas"); end; return; end
	if ( strlower(Command) == "level" ) then GS_Settings["Level"] = GS_Settings["Level"] * -1; if ( GS_Settings["Level"] == 1 ) then print ("Niveles de Objetos: Activados"); else print ("Niveles de Objetos: Desactivados"); end; return; end
	if ( strlower(Command) == "communicate" ) then GS_Settings["Communication"] = GS_Settings["Communication"] * -1; if ( GS_Settings["Communication"] == 1 ) then print ("Comunicación: Activada"); else print ("Comunicación: Desactivada"); end; return; end
	if ( strlower(Command) == "compare" ) then GS_Settings["Compare"] = GS_Settings["Compare"] * -1; if ( GS_Settings["Compare"] == 1 ) then print ("Comparaciones: Activadas"); else print ("Comparaciones: Desactivadas"); end; return; end
	--if ( strlower(Command) == "average" ) then GS_Settings["Average"] = GS_Settings["Average"] * -1; if ( GS_Settings["Average"] == 1 ) then print ("Average ItemLevels: On"); else print ("Average ItemLevels: Off"); end; return; end
	if ( strlower(Command) == "date" ) then GS_Settings["Date"] = GS_Settings["Date"] * -1; if ( GS_Settings["Date"] == 1 ) then print ("Fecha/Hora: Activada"); else print ("Fecha/Hora: Desactivada"); end; return; end
	if ( strlower(Command) == "chat" ) then GS_Settings["CHAT"] = GS_Settings["CHAT"] * -1; if ( GS_Settings["CHAT"] == 1 ) then print ("Puntuaciones en Chat: Activadas"); else print ("Puntuaciones en Chat: Desactivadas"); end; return; end
	if ( strlower(Command) == "time" ) then GS_Settings["Date"] = GS_Settings["Date"] * -1; if ( GS_Settings["Date"] == 1 ) then print ("Fecha/Hora: Activada"); else print ("Fecha/Hora: Desactivada"); end; return; end
	if ( strlower(Command) == "ml" ) then GS_Settings["ML"] = GS_Settings["ML"] * -1; if ( GS_Settings["ML"] == 1 ) then print ("Master Looting: Activado"); else print ("Master Looting: Desactivado"); end; return; end
	if ( strlower(Command) == "detail" ) then GS_Settings["Detail"] = GS_Settings["Detail"] * -1; if ( GS_Settings["Detail"] == 1 ) then print ("Detalles: Activados"); else print ("Detalles: Desactivados"); end; return; end
	if ( strlower(Command) == "details" ) then GS_Settings["Detail"] = GS_Settings["Detail"] * -1; if ( GS_Settings["Detail"] == 1 ) then print ("Detalles: Activados"); else print ("Detalles: Desactivados"); end; return; end
	if ( strlower(Command) == "reset" ) then GS_Settings = GS_DefaultSettings; print("Todas las configuraciones restauradas por defecto"); return end
	if ( strlower(Command) == "purge" ) then print ("¡ADVERTENCIA! Esto eliminará toda tu base de datos de GearScore. Para continuar escribe '/gset purge 314159265'"); return; end
	if ( strlower(Command) == "purge 314159265" ) then GS_Data = nil; ReloadUI(); return; end
	local tbl = {}
	for v in string.gmatch(Command, "[^ ]+") do tinsert(tbl, v); end
	if ( strlower(tbl[1]) == "transmit" ) and (tbl[2]) then
	   if tbl[2] == "end" then GS_ExchangeCount = nil; print("Finalizando transmisión"); return; end
		 if  GS_ExchangeDatabase then print("¡Ya estás transmitiendo tu base de datos!"); return; end

--		if
--	        	tbl[2] = (strupper(string.sub(tbl[2], 1, 1))..strlower(string.sub(tbl[2], 2)))
--				local Message = floor(GearScore_GetTimeStamp()/314159265)
--				print(Message)
--				SendAddonMessage("GSYTRANSMIT", Message, "WHISPER", tbl[2])
		GearScore_Exchange("DATABASE", tbl[2])
		return
	end
	print("GearScore: Comando desconocido. Escribe '/gset' para ver la lista de opciones")
	
end
function GS_SCANSET(Command)
		if ( GS_OptionsFrame:IsVisible() ) then GearScore_HideOptions(); end		
		PanelTemplates_SetTab(GS_DisplayFrame, 1)
		GS_DisplayFrame:Hide();
		GS_ExPFrame:Hide();
		GS_GearFrame:Show(); GS_NotesFrame:Hide(); GS_DefaultFrame:Show(); GS_ExPFrame:Hide()
		GS_GearScoreText:Show(); GS_LocationText:Show(); GS_DateText:Show(); GS_AverageText:Show();
		if GS_HistoryButton then GS_HistoryButton:Show() end
		
		if ( UnitName("target") ) and ( Command == "" ) then 
			 if not ( UnitIsPlayer("target") ) then 
				-- Proteger la llamada con pcall
				local success, err = pcall(GearScore_DisplayUnit, UnitName("player"))
				if not success then
					print("GearScore Error: No se pudo mostrar información del jugador")
				end
			 else 
				local success, err = pcall(GearScore_DisplayUnit, UnitName("target"))
				if not success then
					print("GearScore Error: No se pudo mostrar información del objetivo")
				end
			 end
		else
			if ( Command == "" ) then Command = UnitName("player"); end
			local playerName = strupper(string.sub(Command, 1, 1))..strlower(string.sub(Command, 2))
			-- Proteger la llamada con pcall
			local success, err = pcall(GearScore_DisplayUnit, playerName)
			if not success then
				print("GearScore Error: No se pudo mostrar información de '"..playerName.."'")
				print("Es posible que haya datos corruptos.")
			end
		end
end

------------------------ GUI PROGRAMS -------------------------------------------------------
function GearScore_GetRaidColor(Raid, Score)
	local Red = 0; local Blue = 0; local Green = 0
		if not (Raid) then return; end
		if ( (Raid - Score) >= 200 ) then return 1, 0, 0; end
		if ( (Score - Raid) >= 400 ) then return 0, 1, 0; end
		if ( (Score - Raid) >= 0 ) and ( (Score - Raid) <= 300 ) then return 1, 1, 0; end
		if ( (Score - Raid) >= 0 ) and ( (Score - Raid) > 300 ) then return ( 400 - (Score - Raid) )/200 , 1, 0; end
		if ( (Raid - Score) < 200 ) then return 1, ((Score - (Raid - 200))/200), 0; end
	return 0, 0, 0
end
													

function GearScore_DisplayUnit(Name, Auto)
	-- Medir tiempo de respuesta para optimización automática
	local startTime = GetTime()
	
	-- Cache para evitar recalcular BonusScanner múltiples veces
	if not GS_StatCache then GS_StatCache = {} end
	if not GS_StatCacheTime then GS_StatCacheTime = 0 end
	
	-- Limpiar cache cada 5 minutos para evitar acumulación
	local currentTime = GetTime()
	if currentTime - GS_StatCacheTime > 300 then
		GS_StatCache = {}
		GS_StatCacheTime = currentTime
	end
	
	local cacheKey = Name .. "_" .. (GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Date or "0")
	
	-- Mostrar estadísticas del jugador (recalcular o usar guardadas)
	do
		local statTotals = {}
		
		-- Comprobar si ya tenemos las stats en cache
		if GS_StatCache[cacheKey] then
			statTotals = GS_StatCache[cacheKey]
		else
			-- Recalcular solo si no está en cache
			local equipoCount = 0
		local itemsPending = false
		if GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Equip then
			for i = 1, 18 do
				local equipValue = GS_Data[GetRealmName()].Players[Name].Equip[i]
				-- Ignorar slots vacíos o con valor '0:0' o nil
				if (i ~= 4) and equipValue and equipValue ~= "0:0" and equipValue ~= "" then
					local itemQuery = equipValue
					if type(equipValue) == "string" and not equipValue:find("|Hitem:") then
						itemQuery = "item:"..equipValue
					end
					if BonusScanner and BonusScanner.ScanItem then
						local itemName, itemLink = GetItemInfo(itemQuery)
						if not itemLink then
							itemsPending = true
						else
							local stats = BonusScanner:ScanItem(itemLink)
							if stats then
								equipoCount = equipoCount + 1
								for stat, value in pairs(stats) do
									statTotals[stat] = (statTotals[stat] or 0) + value
								end
							else
								print("[GearScore] BonusScanner no devolvió estadísticas para:", itemLink)
							end
						end
					end
				end
			end
		end
		-- Si hay objetos pendientes de cargar, reintentar hasta que todos estén disponibles
		if itemsPending then
			-- Usar método clásico para reintentos
			local retryFrame = CreateFrame("Frame")
			local elapsed = 0
			retryFrame:SetScript("OnUpdate", function(self, dt)
				elapsed = elapsed + dt
				if elapsed >= 0.5 then
					GearScore_DisplayUnit(Name, Auto)
					self:SetScript("OnUpdate", nil)
				end
			end)
			return
		end
		-- Si estamos viendo el historial, usar las estadísticas de ese momento
		if GS_CurrentHistoryIndex and GS_CurrentHistoryIndex > 0 and GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].EquipHistory then
			local historyEntry = GS_Data[GetRealmName()].Players[Name].EquipHistory[GS_CurrentHistoryIndex]
			if historyEntry and historyEntry.Stats then
				statTotals = historyEntry.Stats
			elseif equipoCount == 0 and GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Stats then
				statTotals = GS_Data[GetRealmName()].Players[Name].Stats
			end
		-- Si no hay equipo almacenado, usar las stats guardadas (solo como último recurso)
		elseif equipoCount == 0 and GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Stats then
			statTotals = GS_Data[GetRealmName()].Players[Name].Stats
		end
		
		-- Guardar en cache solo si se recalculó correctamente
		if equipoCount > 0 then
			GS_StatCache[cacheKey] = statTotals
			
			-- También guardar las estadísticas en la base de datos del jugador
			if GS_Data[GetRealmName()].Players[Name] then
				GS_Data[GetRealmName()].Players[Name].Stats = statTotals
			end
		end
		end -- Fin del bloque de recálculo
		
		-- Mostrar estadísticas en el texto de la UI
		local statOrder = {
			"STR",
			"AGI",
			"STA",
			"INT",
			"SPI",
			"ARMOR",
			"AP",
			"RAP",
			"CRIT",
			"HIT",
			"DODGE",
			"PARRY",
			"BLOCK",
			"SP",
			"HASTE",
			"ARCANERESIST",
			"FIRERESIST",
			"FROSTRESIST",
			"NATURERESIST",
			"SHADOWRESIST",
			"DEFENSE",
			"EXPERTISE",
			"RESILIENCE",
			"MP5",
			"SPELLPEN",
			"ARCANEDMG",
			"FIREDMG",
			"FROSTDMG",
			"HOLYDMG",
			"NATUREDMG",
			"SHADOWDMG",
			"HEALTH",
			"MANA",
			"SPEED",
			"SPELLHIT",
			"SPELLCRIT",
			"SPELLHASTE"
		}
		local statNames = {
		STR = "Fuerza",
		AGI = "Agilidad",
		STA = "Aguante",
		INT = "Intelecto",
		SPI = "Espíritu",
		ARMOR = "Armadura",
		AP = "Poder de ataque",
		RAP = "Poder de ataque a distancia",
		CRIT = "Crítico físico",
		HIT = "Golpe físico",
		DODGE = "Esquivar",
		PARRY = "Parar",
		BLOCK = "Bloqueo",
		SP = "Poder con hechizos",
		HASTE = "Celeridad",
		ARCANERESIST = "Resistencia a Arcano",
		FIRERESIST = "Resistencia a Fuego",
		FROSTRESIST = "Resistencia a Escarcha",
		NATURERESIST = "Resistencia a Naturaleza",
		SHADOWRESIST = "Resistencia a Sombras",
		DEFENSE = "Defensa",
		EXPERTISE = "Pericia",
		RESILIENCE = "Temple",
		MP5 = "Maná cada 5s",
		SPELLPEN = "Penetración de hechizos",
		ARCANEDMG = "Daño Arcano",
		FIREDMG = "Daño de Fuego",
		FROSTDMG = "Daño de Escarcha",
		HOLYDMG = "Daño Sagrado",
		NATUREDMG = "Daño de Naturaleza",
		SHADOWDMG = "Daño de Sombras",
		HEALTH = "Salud",
		MANA = "Maná",
		SPEED = "Velocidad",
		SPELLHIT = "Golpe con hechizos",
		SPELLCRIT = "Crítico con hechizos",
		SPELLHASTE = "Celeridad con hechizos"
	}
		local statText = ""
		for _, stat in ipairs(statOrder) do
			local value = statTotals[stat] or 0
			if value ~= 0 then
				statText = statText .. statNames[stat] .. ": " .. value .. "\n"
			end
		end
		if GS_StatText then
			if statText ~= "" then
				GS_StatText:SetText(statText)
			else
				GS_StatText:SetText("No hay estadísticas disponibles")
			end
			GS_StatText:Show()
		end
	end
	if not ( Name ) then Name = UnitName("player"); end
	if ( Name == UnitName("player") ) then GearScore_GetScore(UnitName("player"), "player"); end
	
	-- Verificar que GS_Data existe y está inicializado
	if not GS_Data or not GS_Data[GetRealmName()] or not GS_Data[GetRealmName()].Players then
		print("GearScore Error: Base de datos no inicializada")
		return
	end
	
	-- Si no existe el jugador en la base de datos, mostrar ventana vacía con mensaje
	if not ( GS_Data[GetRealmName()].Players[Name] ) then 
		GearScore_HideDatabase(1)
		GS_DisplayPlayer = Name
		GS_CurrentHistoryIndex = 0  -- Resetear historial al cambiar de jugador
		GS_DisplayFrame:Show()
		
		-- Mostrar información de "no encontrado"
		GS_InfoText:SetText("Jugador no encontrado")
		GS_InfoText:SetTextColor(1, 0, 0, 1)
		GS_NameText:SetText(Name)
		GS_NameText:SetTextColor(1, 1, 1, 1)
		GS_GuildText:SetText("No disponible")
		GS_GuildText:SetTextColor(1, 1, 1, 1)
		GS_DateText:SetText("El jugador '"..Name.."' no está en la base de datos")
		GS_AverageText:SetText("Usa /gscanear "..Name.." para escanearlo")
		GS_LocationText:SetText("O busca a alguien diferente")
		GS_GearScoreText:SetText("GearScore: No disponible")
		GS_GearScoreText:SetTextColor(1, 1, 1)
		
		-- Mostrar texturas por defecto
		local backdrop = {}
		for i = 1, 18 do 
			if ( i ~= 4 ) then 
				backdrop = { bgFile = GS_TextureFiles[i] }
				_G["GS_Frame"..i]:SetBackdrop(backdrop)
			end
		end
		return
	end
	GearScore_HideDatabase(1)
	
	-- Solo resetear historial si estamos cambiando de jugador
	if GS_DisplayPlayer ~= Name then
		GS_CurrentHistoryIndex = 0  -- Resetear historial al cambiar de jugador
	end
	GS_DisplayPlayer = Name
	--GS_DisplayXP(Name); 
	-- Solo ejecutar cálculos pesados de weights si el usuario los tiene habilitados
	if ( GS_Settings["ShowSpecScores"] ) then
		GearScoreClassScan(Name)
	end
--	if GS_GearFrame:IsVisible() then GS_DatabaseFrame.tooltip:Show(); end
	--GearScore_Send(Name, "ALL")
	if not ( Auto ) then GearScore_Request(Name); end
	local Textures = {}
--	if ( Race == "Orc" ) then Scale = 0.8; end
	GS_EditBox1:SetText(Name)
	GS_DisplayFrame:Show()
	
	-- Opción para desactivar modelo 3D completamente (para máximo rendimiento)
	local enableModel = GS_Settings and GS_Settings["EnableModel"] ~= false
	
	-- Cache para evitar recargar el mismo equipo en el modelo
	if not GS_ModelCache then GS_ModelCache = {} end
	local modelCacheKey = Name .. "_" .. (GS_Data[GetRealmName()].Players[Name] and GS_Data[GetRealmName()].Players[Name].Date or "0")
	local shouldUpdateModel = not GS_ModelCache[modelCacheKey]
	
	-- Si el modelo fue desactivado y luego reactivado, forzar actualización
	if enableModel and GS_Settings and GS_Settings["ModelJustEnabled"] then
		shouldUpdateModel = true
		GS_Settings["ModelJustEnabled"] = nil
	end
	
	-- Configurar modelo 3D solo si está habilitado
	if enableModel then
		-- Obtener información actualizada de gemas
		GS_GetPlayerGems(Name)
		
		GS_Model:SetModelScale(1)
		GS_Model:SetCamera(1)
		GS_Model:SetLight(1, 0, 0, -0.707, -0.707, 0.7, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.8)
		if Name == UnitName("target") then GS_Model:SetUnit("target"); else GS_Model:SetUnit("player"); end
		GS_Model:Undress()
		GS_Model:EnableMouse(1)
		GS_Model:SetPosition(0,0,0)
		GS_Model:Show()
	end

	if ( GS_Data[GetRealmName()].Players[Name] ) then
		-- Determinar qué datos usar: actual o historial
		local playerData = GS_Data[GetRealmName()].Players[Name]
		local equipData = playerData.Equip
		local gearScore = playerData.GearScore
		local playerDate = playerData.Date
		local playerAverage = playerData.Average
		
		-- Si estamos viendo historial, usar esos datos
		if GS_CurrentHistoryIndex > 0 and playerData.EquipHistory and #playerData.EquipHistory > 0 then
			local historyIndex = #playerData.EquipHistory - GS_CurrentHistoryIndex + 1
			if historyIndex > 0 and playerData.EquipHistory[historyIndex] then
				equipData = playerData.EquipHistory[historyIndex].Equip
				gearScore = playerData.EquipHistory[historyIndex].GearScore
				playerDate = playerData.EquipHistory[historyIndex].Date
				playerAverage = playerData.EquipHistory[historyIndex].Average
			end
		end
		
		for i = 1, 18 do
			if ( i ~= 4 ) then
				-- Verificar que Equip existe y que el slot tiene un item
				if equipData and equipData[i] then
					local equipValue = equipData[i]
					local itemQuery = equipValue
					if type(equipValue) == "string" and not equipValue:find("|Hitem:") then
						itemQuery = "item:"..equipValue
					end
					local ItemName, ItemLink, ItemRarity, ItemLevel, ItemMinLevel, ItemType, ItemSubType, ItemStackCount, ItemEquipLoc, ItemTexture = GetItemInfo(itemQuery)
					local backdrop = {}
					
					-- Solo cargar en el modelo si está habilitado
					if enableModel and (ItemLink or (type(equipValue) == "string" and equipValue ~= "" and equipValue ~= "0")) then 
						-- Priorizar el link completo del equipValue si tiene más información
						local itemToLoad = nil
						if type(equipValue) == "string" and equipValue:find("|Hitem:") then
							-- Si el equipValue ya es un link completo, usarlo directamente (incluye gemas)
							itemToLoad = equipValue
						elseif ItemLink then
							-- Si tenemos ItemLink de GetItemInfo, usarlo
							itemToLoad = ItemLink
						else
							-- Como último recurso, crear un link básico
							itemToLoad = "item:"..equipValue
						end
						
						pcall(function() GS_Model:TryOn(itemToLoad) end)
					end
					
					if ( ItemTexture ) then backdrop = { bgFile = ItemTexture }; _G["GS_Frame"..i]:SetBackdrop(backdrop); else backdrop = { bgFile = GS_TextureFiles[i] }; _G["GS_Frame"..i]:SetBackdrop(backdrop);end
					-- Tooltip para objetos de la base de datos
					_G["GS_Frame"..i]:SetScript("OnEnter", function(self)
						if equipValue and type(equipValue) == "string" and equipValue:find("|Hitem:") then
							GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
							GameTooltip:SetHyperlink(equipValue)
						elseif equipValue then
							GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
							GameTooltip:SetHyperlink("item:"..equipValue)
						end
					end)
					_G["GS_Frame"..i]:SetScript("OnLeave", function(self)
						GameTooltip:Hide()
					end)
				else
					-- Si no hay equipo en este slot, usar textura por defecto
					local backdrop = { bgFile = GS_TextureFiles[i] }
					_G["GS_Frame"..i]:SetBackdrop(backdrop)
				end
			end
		end
		
		-- Marcar como cargado en el cache del modelo solo si realmente se cargó
		if shouldUpdateModel and enableModel then
			GS_ModelCache[modelCacheKey] = true
			-- Limpiar cache del modelo cada 10 minutos
			if not GS_ModelCacheTime then GS_ModelCacheTime = 0 end
			local currentTime = GetTime()
			if currentTime - GS_ModelCacheTime > 600 then
				GS_ModelCache = {}
				GS_ModelCacheTime = currentTime
			end
			
			-- Iniciar carga diferida de gemas después de cargar el equipo base
			GS_LoadGemsDelayed(Name)
		end
		
		-- Verificar que las propiedades básicas existen antes de acceder a ellas
		-- Simplificado: mostrar directamente los datos traducidos
		local playerData = GS_Data[GetRealmName()].Players[Name]
		
		-- Tabla de razas simple
		local razas = {
			["NE"] = "Elfo de la noche", ["HU"] = "Humano", ["DW"] = "Enano", ["GN"] = "Gnomo", 
			["DR"] = "Draenei", ["WO"] = "Huargen", ["OR"] = "Orco", ["UD"] = "No-muerto", 
			["TA"] = "Tauren", ["TR"] = "Trol", ["BE"] = "Elfo de sangre", ["GO"] = "Goblin"
		}
		
		-- Tabla de clases simple
		local clases = {
			["WA"] = "Guerrero", ["PA"] = "Paladín", ["HU"] = "Cazador", ["RO"] = "Pícaro", 
			["PR"] = "Sacerdote", ["DK"] = "Caballero de la muerte", ["SH"] = "Chamán", 
			["MA"] = "Mago", ["WL"] = "Brujo", ["DR"] = "Druida"
		}
		
		-- Si tenemos los datos básicos, intentar mostrarlos traducidos
		if playerData.Level and playerData.Race and playerData.Class then
			local raza = razas[playerData.Race] or playerData.Race
			local clase = clases[playerData.Class] or playerData.Class
			
			GS_InfoText:SetText(playerData.Level.." "..raza.." "..clase)
			
			-- Colores específicos para cada clase (colores oficiales de WoW)
			if playerData.Class == "WA" then -- Guerrero
				GS_InfoText:SetTextColor(0.78, 0.61, 0.43, 1) -- Marrón
			elseif playerData.Class == "PA" then -- Paladín  
				GS_InfoText:SetTextColor(0.96, 0.55, 0.73, 1) -- Rosa
			elseif playerData.Class == "HU" then -- Cazador
				GS_InfoText:SetTextColor(0.67, 0.83, 0.45, 1) -- Verde
			elseif playerData.Class == "RO" then -- Pícaro
				GS_InfoText:SetTextColor(1.00, 0.96, 0.41, 1) -- Amarillo
			elseif playerData.Class == "PR" then -- Sacerdote
				GS_InfoText:SetTextColor(1.00, 1.00, 1.00, 1) -- Blanco
			elseif playerData.Class == "DK" then -- Caballero de la muerte
				GS_InfoText:SetTextColor(0.77, 0.12, 0.23, 1) -- Rojo oscuro
			elseif playerData.Class == "SH" then -- Chamán
				GS_InfoText:SetTextColor(0.00, 0.44, 0.87, 1) -- Azul oscuro
			elseif playerData.Class == "MA" then -- Mago
				GS_InfoText:SetTextColor(0.41, 0.80, 0.94, 1) -- Azul claro
			elseif playerData.Class == "WL" then -- Brujo
				GS_InfoText:SetTextColor(0.58, 0.51, 0.79, 1) -- Púrpura
			elseif playerData.Class == "DR" then -- Druida
				GS_InfoText:SetTextColor(1.00, 0.49, 0.04, 1) -- Naranja
			else
				GS_InfoText:SetTextColor(1, 1, 1, 1) -- Blanco por defecto
			end
		else
			GS_InfoText:SetText("Nivel:" .. (playerData.Level or "?") .. " Raza:" .. (playerData.Race or "?") .. " Clase:" .. (playerData.Class or "?"))
			GS_InfoText:SetTextColor(1, 1, 1, 1)
		end
		
		if GS_Data[GetRealmName()].Players[Name].Name then
			GS_NameText:SetText(GS_Data[GetRealmName()].Players[Name].Name)
		else
			GS_NameText:SetText(Name)
		end
		
		if GS_Data[GetRealmName()].Players[Name].Class and GS_Classes[GS_Data[GetRealmName()].Players[Name].Class] and 
		   GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Name].Class]] then
			GS_NameText:SetTextColor(GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Name].Class]].Red, GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Name].Class]].Green, GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Name].Class]].Blue, 1)
			GS_GuildText:SetTextColor(GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Name].Class]].Red, GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Name].Class]].Green, GS_ClassInfo[GS_Classes[GS_Data[GetRealmName()].Players[Name].Class]].Blue, 1)
		else
			GS_NameText:SetTextColor(1, 1, 1, 1)
			GS_GuildText:SetTextColor(1, 1, 1, 1)
		end
		
		if gearScore then
			Red, Green, Blue = GearScore_GetQuality(gearScore)
			local historyText = (GS_CurrentHistoryIndex > 0) and " (Historial)" or ""
			GS_GearScoreText:SetText("GS Bruto: "..gearScore..historyText)
			GS_GearScoreText:SetTextColor(Red,Blue,Green)
		else
			GS_GearScoreText:SetText("GS: No disponible")
			GS_GearScoreText:SetTextColor(1, 1, 1)
		end
		
		if GS_Data[GetRealmName()].Players[Name].Guild then
			GS_GuildText:SetText(GS_Data[GetRealmName()].Players[Name].Guild)
		else
			GS_GuildText:SetText("Sin guild")
		end
		
		if playerDate then
			-- Usar la nueva función para mostrar fecha legible
			local fechaTexto, DateRed, DateGreen, DateBlue = GearScore_GetReadableDate(playerDate)
			ColorStringDate = "|cff"..string.format("%02x%02x%02x", DateRed * 255, DateGreen * 255, DateBlue * 255) 
			local historyText = (GS_CurrentHistoryIndex > 0) and " (Historial)" or ""
			local scannedBy = GS_Data[GetRealmName()].Players[Name].Scanned or "Desconocido"
			GS_DateText:SetText(ColorStringDate..fechaTexto..historyText.." escaneado por "..scannedBy.."|r")
			GS_DateText:SetJustifyH("LEFT")
		else
			GS_DateText:SetText("Fecha de escaneo: Desconocida")
		end
		
		if playerAverage then
			local historyText = (GS_CurrentHistoryIndex > 0) and " (Historial)" or ""
			GS_AverageText:SetText("Nivel Promedio de Objeto:|cFFFFFFFF "..playerAverage..historyText)
		else
			GS_AverageText:SetText("Nivel Promedio de Objeto:|cFFFFFFFF No disponible")
		end
		
		local location = GS_Data[GetRealmName()].Players[Name].Location or ""
		if location ~= "" and GS_Zones[location] then
			GS_LocationText:SetText(GS_Zones[location])
		else
			GS_LocationText:SetText("Ubicación: Desconocida")
		end
		GearScore_UpdateRaidColors(Name)
	else
		GS_InfoText:SetText("")
		GS_NameText:SetText(Name)
		GS_GuildText:SetText("")
		GS_DateText:SetText("")
		GS_AverageText:SetText("")
		GS_LocationText:SetText("")
		GS_GearScoreText:SetText("Sin registro")
		local backdrop = {}
		for i = 1, 18 do if ( i ~=4 ) then backdrop = { bgFile = GS_TextureFiles[i] }; _G["GS_Frame"..i]:SetBackdrop(backdrop); end; end
		--GS_Slot1:Hide(); GS_Slot2:Hide(); GS_Slot3:Hide(); GS_Slot5:Hide(); GS_Slot6:Hide(); GS_Slot7:Hide(); GS_Slot8:Hide(); GS_Slot9:Hide(); GS_Slot10:Hide(); GS_Slot11:Hide(); GS_Slot12:Hide(); GS_Slot13:Hide(); GS_Slot14:Hide(); GS_Slot15:Hide(); GS_Slot16:Hide(); GS_Slot17:Hide(); GS_Slot18:Hide()
	end


	GS_EditBox1:SetAutoFocus(0)
	
	-- Actualizar botón de historial
	GearScore_UpdateHistoryButton(Name)
	
	-- Detección automática de rendimiento y sugerencia
	local endTime = GetTime()
	local duration = endTime - startTime
	
	-- Si la función tarda más de 0.5 segundos y el modelo está habilitado, sugerir desactivarlo
	if duration > 0.5 and enableModel and not GS_Settings["ModelWarningShown"] then
		print("|cffFFFF00GearScore:|r Consulta lenta detectada (" .. string.format("%.2f", duration) .. "s). Considera usar |cff00FF00/gs3d|r para desactivar el modelo 3D y mejorar el rendimiento.")
		GS_Settings["ModelWarningShown"] = true
	end
	
	-- Intentar reintentos de gemas si el jugador está targetado y existe en la base de datos
	if UnitExists("target") and UnitName("target") == Name and GS_Data[GetRealmName()].Players[Name] then
		-- Esperar un poco antes de verificar gemas para dar tiempo a que se actualice la información del target
		local function delayedTargetGemCheck()
			GearScore_CheckAndRetryGems(Name, "target")
		end
		
		local delayFrame = CreateFrame("Frame")
		local elapsed = 0
		delayFrame:SetScript("OnUpdate", function(self, deltaTime)
			elapsed = elapsed + deltaTime
			if elapsed >= 1.5 then -- Esperar 1.5 segundos para targets ya cargados
				delayFrame:SetScript("OnUpdate", nil)
				delayedTargetGemCheck()
			end
		end)
	end
 end

 function GearScore_UpdateRaidColors(Name)
	local RealmName = GetRealmName()
	GS_InstanceText1:SetTextColor(GearScore_GetRaidColor(2600, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText2:SetTextColor(GearScore_GetRaidColor(2896, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText3:SetTextColor(GearScore_GetRaidColor(3353, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText4:SetTextColor(GearScore_GetRaidColor(3563, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText5:SetTextColor(GearScore_GetRaidColor(3809, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText6:SetTextColor(GearScore_GetRaidColor(4019, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText7:SetTextColor(GearScore_GetRaidColor(4475, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText8:SetTextColor(GearScore_GetRaidColor(4932, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText9:SetTextColor(GearScore_GetRaidColor(4686, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText10:SetTextColor(GearScore_GetRaidColor(5142, GS_Data[RealmName].Players[Name].GearScore))
	GS_InstanceText11:SetTextColor(GearScore_GetRaidColor(5598, GS_Data[RealmName].Players[Name].GearScore))			
end

function GearScore_ShowOptions()
	GS_OptionalDisplayed = 	GS_Displayed
	GS_Displayed = nil
	if ( GS_Settings["Restrict"] == 1 ) then GS_None:SetChecked(true); GS_Light:SetChecked(false); GS_Heavy:SetChecked(false); end
	if ( GS_Settings["Restrict"] == 2 ) then GS_Light:SetChecked(true); GS_None:SetChecked(false); GS_Heavy:SetChecked(false);end
	if ( GS_Settings["Restrict"] == 3 ) then GS_Heavy:SetChecked(true); GS_Light:SetChecked(false); GS_None:SetChecked(false);end
	if ( GS_Settings["Player"] == 1 ) then GS_ShowPlayerCheck:SetChecked(true); else GS_ShowPlayerCheck:SetChecked(false); end
	if ( GS_Settings["Item"] == 1 ) then GS_ShowItemCheck:SetChecked(true); else GS_ShowItemCheck:SetChecked(false); end
	if ( GS_Settings["Detail"] == 1 ) then GS_DetailCheck:SetChecked(true); else GS_DetailCheck:SetChecked(false); end
	if ( GS_Settings["Level"] == 1 ) then GS_LevelCheck:SetChecked(true); else GS_LevelCheck:SetChecked(false); end
	if ( GS_Settings["Date2"] == 1 ) then GS_DateCheck:SetChecked(true); else GS_DateCheck:SetChecked(false); end
	if ( GS_Settings["AutoPrune"] == 1 ) then GS_PruneCheck:SetChecked(true); else GS_PruneCheck:SetChecked(false); end	
	if ( GS_Settings["ShowHelp"] == 1 ) then GS_HelpCheck:SetChecked(true); else GS_HelpCheck:SetChecked(false); end
	if ( GS_Settings["KeepFaction"] == 1 ) then GS_FactionCheck:SetChecked(true); else GS_FactionCheck:SetChecked(false); end
	if ( GS_Settings["ML"] == 1 ) then GS_MasterlootCheck:SetChecked(true); else GS_MasterlootCheck:SetChecked(false); end
	if ( GS_Settings["CHAT"] == 1 ) then GS_ChatCheck:SetChecked(true); else GS_ChatCheck:SetChecked(false); end
	GS_DatabaseAgeSliderText:SetText("Conservar datos por: "..(GS_Settings["DatabaseAgeSlider"] or 365).." días.")
	-- Configurar rango del slider: 0 a 365 días
	GS_DatabaseAgeSlider:SetMinMaxValues(0, 365)
	GS_DatabaseAgeSlider:SetValueStep(1)
	GS_DatabaseAgeSlider:SetValue(GS_Settings["DatabaseAgeSlider"] or 365)
	GS_LevelEditBox:SetText(GS_Settings["MinLevel"])
	--Set SpecScore Options--
	local class, englishClass = UnitClass("player")
	for i = 1,4 do _G["GS_SpecFontString"..i]:Hide(); _G["GS_SpecScoreCheck"..i]:Hide(); end
	for i, v in ipairs(GearScoreClassSpecList[englishClass]) do
	_G["GS_SpecFontString"..i]:SetText("Mostrar SpecScores de "..GearScore_GetTranslatedSpecName(GearScoreClassSpecList[englishClass][i]))
		_G["GS_SpecScoreCheck"..i]:SetText(GearScore_GetTranslatedSpecName(GearScoreClassSpecList[englishClass][i]))
		_G["GS_SpecFontString"..i]:Show(); _G["GS_SpecScoreCheck"..i]:Show()
		if not ( GS_Settings["ShowSpecScores"] ) then GS_Settings["ShowSpecScores"] = {}; end
		if not ( GS_Settings["ShowSpecScores"][GearScoreClassSpecList[englishClass][i]] ) then GS_Settings["ShowSpecScores"][GearScoreClassSpecList[englishClass][i]] = 1; end
		if ( GS_Settings["ShowSpecScores"][GearScoreClassSpecList[englishClass][i]] == 1 ) then _G["GS_SpecScoreCheck"..i]:SetChecked(1); else _G["GS_SpecScoreCheck"..i]:SetChecked(0); end
	end
	
	GS_Displayed = 1; GS_OptionsFrame:Show(); GS_GearFrame:Hide(); GS_ExPFrame:Hide()
end 
 
function GearScore_HideOptions()
	if ( GS_ShowItemCheck:GetChecked() ) then GS_Settings["Item"] = 1; else GS_Settings["Item"] = -1; end
	if ( GS_None:GetChecked() ) then GearScore_SetNone(); end												
	if ( GS_Light:GetChecked() ) then GearScore_SetLight(); end												
	if ( GS_Heavy:GetChecked() ) then GearScore_SetHeavy(); end	
	if ( GS_HelpCheck:GetChecked() ) then GS_Settings["ShowHelp"] = 1; else GS_Settings["ShowHelp"] = -1; end
	if ( GS_ShowPlayerCheck:GetChecked() ) then GS_Settings["Player"] = 1; else GS_Settings["Player"] = -1; end											
	if ( GS_DetailCheck:GetChecked() ) then GS_Settings["Detail"] = 1; else GS_Settings["Detail"] = -1; end											
	if ( GS_LevelCheck:GetChecked() ) then GS_Settings["Level"] = 1; else GS_Settings["Level"] = -1; end	
	if ( GS_ChatCheck:GetChecked() ) then GS_Settings["CHAT"] = 1; else GS_Settings["CHAT"] = -1; end
	if ( GS_ShowItemCheck:GetChecked() ) then GS_Settings["Item"] = 1; else GS_Settings["Item"] = -1; end
	if ( GS_DateCheck:GetChecked() ) then GS_Settings["Date2"] = 1; else GS_Settings["Date2"] = -1; end
	if ( GS_PruneCheck:GetChecked() ) then GS_Settings["AutoPrune"] = 1; else GS_Settings["AutoPrune"] = -1; end		
	if ( GS_FactionCheck:GetChecked() ) then GS_Settings["KeepFaction"] = 1; else GS_Settings["KeepFaction"] = -1; end
	if ( GS_MasterlootCheck:GetChecked() ) then GS_Settings["ML"] = 1; else GS_Settings["ML"] = -1; end
	GS_Settings["MinLevel"] = tonumber(GS_LevelEditBox:GetText());
	GS_Settings["DatabaseAgeSlider"] = ( GS_DatabaseAgeSlider:GetValue() or 365 )
	GS_OptionsFrame:Hide()		
	if (GS_Displayed) then GearScore_DisplayUnit(GS_DisplayPlayer); end
	GS_Displayed = nil
	
	--Update Settings for new SpecScore Options--
	local class, englishClass = UnitClass("player")
	for i, v in ipairs(GearScoreClassSpecList[englishClass]) do
		if ( _G["GS_SpecScoreCheck"..i]:GetChecked() ) then GS_Settings["ShowSpecScores"][GearScoreClassSpecList[englishClass][i]] = 1; else GS_Settings["ShowSpecScores"][GearScoreClassSpecList[englishClass][i]] = 0; end
	end
	
	
end
 

function GearScore_SetHeavy()
	GS_Settings["Restrict"] = 3
	GS_ClassInfo["Warrior"].Equip["Cloth"] = nil
	GS_ClassInfo["Warrior"].Equip["Mail"] = nil
	GS_ClassInfo["Warrior"].Equip["Leather"] = nil
	GS_ClassInfo["Paladin"].Equip["Cloth"] = nil
	GS_ClassInfo["Paladin"].Equip["Mail"] = nil
	GS_ClassInfo["Paladin"].Equip["Leather"] = nil
	GS_ClassInfo["Death Knight"].Equip["Cloth"] = nil
	GS_ClassInfo["Death Knight"].Equip["Mail"] = nil
	GS_ClassInfo["Death Knight"].Equip["Leather"] = nil
	GS_ClassInfo["Hunter"].Equip["Cloth"] = nil
	GS_ClassInfo["Hunter"].Equip["Leather"] = nil
	GS_ClassInfo["Shaman"].Equip["Cloth"] = nil
	GS_ClassInfo["Shaman"].Equip["Leather"] = nil
	GS_ClassInfo["Rogue"].Equip["Cloth"] = nil
	GS_ClassInfo["Druid"].Equip["Cloth"] = nil
end

function GearScore_SetLight()
	GS_Settings["Restrict"] = 2
	GS_ClassInfo["Warrior"].Equip["Cloth"] = nil
	GS_ClassInfo["Warrior"].Equip["Mail"] = nil
	GS_ClassInfo["Warrior"].Equip["Leather"] = nil
	GS_ClassInfo["Paladin"].Equip["Cloth"] = 1
	GS_ClassInfo["Paladin"].Equip["Mail"] = 1
	GS_ClassInfo["Paladin"].Equip["Leather"] = 1
	GS_ClassInfo["Death Knight"].Equip["Cloth"] = nil
	GS_ClassInfo["Death Knight"].Equip["Mail"] = nil
	GS_ClassInfo["Death Knight"].Equip["Leather"] = nil
	GS_ClassInfo["Hunter"].Equip["Cloth"] = nil
	GS_ClassInfo["Hunter"].Equip["Leather"] = 1
	GS_ClassInfo["Shaman"].Equip["Cloth"] = 1
	GS_ClassInfo["Shaman"].Equip["Leather"] = 1
	GS_ClassInfo["Rogue"].Equip["Cloth"] = nil
	GS_ClassInfo["Druid"].Equip["Cloth"] = 1
end

function GearScore_SetNone()
	GS_Settings["Restrict"] = 1
	GS_ClassInfo["Warrior"].Equip["Cloth"] = 1
	GS_ClassInfo["Warrior"].Equip["Mail"] = 1
	GS_ClassInfo["Warrior"].Equip["Leather"] = 1
	GS_ClassInfo["Paladin"].Equip["Cloth"] = 1
	GS_ClassInfo["Paladin"].Equip["Mail"] = 1
	GS_ClassInfo["Paladin"].Equip["Leather"] = 1
	GS_ClassInfo["Death Knight"].Equip["Cloth"] = 1
	GS_ClassInfo["Death Knight"].Equip["Mail"] = 1
	GS_ClassInfo["Death Knight"].Equip["Leather"] = 1
	GS_ClassInfo["Hunter"].Equip["Cloth"] = 1
	GS_ClassInfo["Hunter"].Equip["Leather"] = 1
	GS_ClassInfo["Shaman"].Equip["Cloth"] = 1
	GS_ClassInfo["Shaman"].Equip["Leather"] = 1
	GS_ClassInfo["Rogue"].Equip["Cloth"] = 1
	GS_ClassInfo["Druid"].Equip["Cloth"] = 1
end

function GearScore_DisplayDatabase(Group, SortType, Auto, GSX_StartPage)
	--GS_HighlightedColNum = 1
	if not ( Group ) then Group = "Party"; end
	GS_StartPage = GSX_StartPage
	if not ( GS_StartPage ) or ( GS_StartPage < 0 ) then GS_StartPage = 0; end
	
	GS_DisplayedGroup = Group; GS_DisplayFrame:Hide(); 	GS_DatabaseFrame:Show(); GS_DatabaseDisplayed =  1 
	if not ( SortType ) then SortType = "GearScore"; end
	GS_SortedType = SortType
	LibQTip:Release(GS_DatabaseFrame.tooltip)
	GS_DatabaseFrame.tooltip = nil
	local tooltip = LibQTip:Acquire("GearScoreTooltip", 10, "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER")
	tooltip:SetCallback("OnMouseUp", GearScore_DatabaseOnClick)
	GS_DatabaseFrame.tooltip = tooltip 
	
--	GS_DatabaseFrame.tooltip:SetCell(lineNum, GS_HighlightedColNum, value[, font][, justification][, colSpan][, provider][, left][, rightPadding][, maxWidth, ...][, minWidth])

	tooltip:SetPoint("TOPLEFT", GS_DatabaseFrame, 10, -10)
				--tooltip:SetFrameStrata("LOW");
	tooltip:SetPoint("TOPRIGHT", GS_DatabaseFrame, -10, 0)
			--tooltip:SetPoint("BOTTOMLEFT", GS_DatabaseFrame, 0, 40)
	tooltip:SetFrameStrata("DIALOG")
	tooltip:SetHeight(420)
	tooltip:SetAlpha(100)
	tooltip:SetScale(1)
	tooltip:AddLine('#', 'GearScore', 'Nombre', "Nivel de objeto", 'Nivel', 'Raza', 'Clase', 'Hermandad', 'Días', 'Enviado por'); tooltip:AddSeparator(1, 1, 1, 1)
	tooltip:SetColumnLayout(10, "CENTER", "CENTER", "LEFT", "CENTER", "CENTER", "LEFT", "LEFT", "CENTER", "CENTER", "LEFT") 


	local count = 1; local ColorString1 = ""; local ColorString2 = ""; local gsfunc = ""; local PartySize = 0; local GroupType = ""; local FactionColor = nil
	if not ( GSX_DataBase ) then GSX_DataBase = {}; GSX_DataBase = GearScore_BuildDatabase(Group); Auto = 0; end
	
	if not ( GS_SortDirection ) then GS_SortDirection = {}; end
	if ( Auto ~= 1 ) then 
		if ( GS_SortDirection[SortType] ) then GS_SortDirection[SortType] = GS_SortDirection[SortType] * -1; else GS_SortDirection[SortType] = 1; end
		if ( SortType == "Name" ) then GS_HighlightedColNum = 3; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return a.Name < b.Name end); else table.sort(GSX_DataBase, function(a, b) return a.Name > b.Name end); end; end
		if ( SortType == "GearScore" ) then GS_HighlightedColNum = 2; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return a.GearScore > b.GearScore end); else table.sort(GSX_DataBase, function(a, b) return a.GearScore < b.GearScore end); end; end
		if ( SortType == "iLevel" ) then GS_HighlightedColNum = 4; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return a.Average > b.Average end); else table.sort(GSX_DataBase, function(a, b) return a.Average < b.Average end); end; end
		if ( SortType == "Level" ) then GS_HighlightedColNum = 5; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return tonumber(a.Level) > tonumber(b.Level) end); else table.sort(GSX_DataBase, function(a, b) return tonumber(a.Level) < tonumber(b.Level) end); end; end
		if ( SortType == "Guild" ) then GS_HighlightedColNum = 8; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return a.Guild < b.Guild end); else table.sort(GSX_DataBase, function(a, b) return a.Guild > b.Guild end); end; end
		if ( SortType == "Class" ) then GS_HighlightedColNum = 7; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return GS_Classes[a.Class] < GS_Classes[b.Class] end); else table.sort(GSX_DataBase, function(a, b) return GS_Classes[a.Class] > GS_Classes[b.Class] end); end; end
		if ( SortType == "Date" ) then GS_HighlightedColNum = 9; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return a.Date > b.Date end); else table.sort(GSX_DataBase, function(a, b) return a.Date < b.Date end); end; end
		if ( SortType == "Race" ) then GS_HighlightedColNum = 6; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return GS_Races[a.Race] < GS_Races[b.Race] end); else table.sort(GSX_DataBase, function(a, b) return GS_Races[a.Race] > GS_Races[b.Race] end); end; end
		if ( SortType == "Scanned" ) then GS_HighlightedColNum = 10; if ( GS_SortDirection[SortType] == 1 ) then table.sort(GSX_DataBase, function(a, b) return a.Scanned < b.Scanned end); else table.sort(GSX_DataBase, function(a, b) return a.Scanned > b.Scanned end); end; end
	end		
	if ( GS_StartPage > (#(GSX_DataBase))) then GS_StartPage = GS_StartPage - 25; end
	local Recount = GS_StartPage
	for i,v in pairs(GSX_DataBase) do
	if ( i > GS_StartPage ) then
		local Red, Green, Blue = GearScore_GetQuality(v.GearScore) 
	
		--if ( Red ) and ( Green ) and ( Blue ) then
			Recount = Recount + 1
			if ( v.Faction == "H" ) then FactionColor = "|cff"..string.format("%02x%02x%02x", 1 * 255, 0 * 255, 0 * 255); else  FactionColor = "|cff"..string.format("%02x%02x%02x", 0 , 162, 255); end   
			
			-- Verificar que las tablas de clase existen antes de acceder
			if v.Class and GS_Classes[v.Class] and GS_ClassInfo[GS_Classes[v.Class]] then
				ColorString1 = "|cff"..string.format("%02x%02x%02x", GS_ClassInfo[GS_Classes[v.Class]].Red * 255, GS_ClassInfo[GS_Classes[v.Class]].Green * 255, GS_ClassInfo[GS_Classes[v.Class]].Blue * 255)
			else
				ColorString1 = "|cffffffff" -- Blanco por defecto
			end
			
			local NowDate, NoWRed, NowGreen, NowBlue = GearScore_GetDate(v.Date) 
--  			print(NowDate, NoWRed, NowGreen, NowBlue)
			ColorStringDate = "|cff"..string.format("%02x%02x%02x", NoWRed * 255, NowGreen * 255, NowBlue * 255) 
--			ColorStringDate..NowDate
			local Red, Green, Blue = GearScore_GetQuality(v.GearScore) 
			ColorString2 = "|cff"..string.format("%02x%02x%02x", Red * 255, Blue * 255, Green * 255)
			
			-- Verificar las tablas antes de usarlas en AddLine
			local raceName = (v.Race and GS_Races[v.Race]) and GS_Races[v.Race] or "Desconocida"
			local className = (v.Class and GS_Classes[v.Class]) and GS_Classes[v.Class] or "Desconocida"
			
			tooltip:AddLine(Recount, ColorString2..v.GearScore, ColorString1..v.Name, v.Average, ColorString1..v.Level, ColorString1..raceName, ColorString1..className, FactionColor.."<"..v.Guild..">", ColorStringDate..NowDate, v.Scanned)
			if ( i >= ( GS_StartPage + 25 ) ) then break; end
		--else
		  -- print(v.Name, "doesn't have a GearScore!") 
	end
	end
	local SubRecount = ((Recount - (floor(Recount/25) * 25) ))
	if SubRecount == 0 then SubRecount = 25; end
	
	
	for i = count + SubRecount, 25 do 
		if ( i >= 26 ) then break; end
		tooltip:AddLine("    ", "                        ", "   ", "  ", "       ", "            ", "          "); 
	end
	tooltip:Show()
	--tooltip:SetColumnColor(GS_HighlightedColNum, 1, 1, 1, .5);
	tooltip:SetBackdropColor(.1,.1,.2,1)
end

function GearScore_SetSortingColor(ColNum, AlphaDirection, tooltip)

end

function GearScore_HideDatabase(erase)
	LibQTip.OnLeave()
	--GearScoreTooltip:ClearLines()
	local keepreport = nil
	if ( GS_ReportFrame:IsVisible() ) then keepreport = 1; end
	--LibQTip:ReleaseAllCallbacks(GS_DatabaseFrame.tooltip)
	LibQTip:Release(GS_DatabaseFrame.tooltip)
	GS_DatabaseFrame.tooltip = nil
	GS_SortDirection = nil
	GS_DatabaseFrame:Hide()
	GS_ReportFrame:Hide()
	
	if ( keepreport == 1 ) then GS_ReportFrame:Show(); end
	if not (erase) then GS_DatabaseDisplayed =  nil; GSX_DataBase = nil; end
   
 end
 
 function GearScore_BuildDatabase(Group, Auto)
	--print("Compiling Database")
	local count = 1; local GSL_DataBase = {}
	if ( Group == "Party" ) then 
		if ( UnitName("raid1") ) then GroupType = "raid"; PartySize = 40; else GroupType = "party"; PartySize = 5; end
		count = 0; for i = 1, PartySize do 
			if ( GS_Data[GetRealmName()].Players[UnitName(GroupType..i)] ) then 
				count = count + 1; GSL_DataBase[count] = GS_Data[GetRealmName()].Players[UnitName(GroupType..i)]; 
			else
				--GearScore_Request(UnitName(GroupType..i))
			end; 
		end
		if ( GroupType == "party" ) then GSL_DataBase[count+1] = GS_Data[GetRealmName()].Players[UnitName("player")]; end
	end
	if ( Group == "All" ) then count = 0;
		for i,v in pairs(GS_Data[GetRealmName()].Players) do
			if ( GS_Settings["AutoPrune"] == 1 ) then
				if ( GearScore_GetDate(v.Date) > (GS_Settings["DatabaseAgeSlider"] or 365 ) ) then
					GS_Data[GetRealmName()].Players[i] = nil
				else
					count = count+1; GSL_DataBase[count] = v;
				end
			else
			count = count+1; GSL_DataBase[count] = v;
			end
		end;
	end

	if ( Group == "Guild" ) then
	GuildRoster(); for i = 1, GetNumGuildMembers(1) do	if ( GS_Data[GetRealmName()].Players[GetGuildRosterInfo(i)] ) then GSL_DataBase[count] = GS_Data[GetRealmName()].Players[GetGuildRosterInfo(i)]; count = count + 1; end; end; end
 if ( Group == "Search" ) then count = 0; for i,v in pairs(GS_Data[GetRealmName()].Players) do local DataString = tostring(v.GearScore..v.Name..v.Level..v.Guild..GS_Classes[v.Class]..GS_Races[v.Race]); if string.find(strlower(DataString), strlower(GS_SearchXBox:GetText())) then count = count + 1; GSL_DataBase[count] = v; end; end; end
	if ( Group == "Friends" ) then GuildRoster(); for i = 1, GetNumFriends(1) do	if ( GS_Data[GetRealmName()].Players[GetFriendInfo(i)] ) then GSL_DataBase[count] = GS_Data[GetRealmName()].Players[GetFriendInfo(i)]; count = count + 1; end; end; end
	
	if Group == "All" then GSDatabaseInfoString:SetText("Base de Datos: "..count.." entradas. (Aprox "..floor(0.8372131704586988304093567251462 * count).."Kb)"); GS_Settings["DatabaseSize"] = count;
	else if GS_Settings["DatabaseSize"] then GSDatabaseInfoString:SetText("Base de Datos: "..GS_Settings["DatabaseSize"].." entradas. (Aprox "..floor(0.8372131704586988304093567251462 * GS_Settings["DatabaseSize"]).."Kb)"); end
	end
	return GSL_DataBase
end

 function GearScore_ShowReport()
	GS_ReportFrame:Show()
	GS_SliderText:SetText("Mejores: "..GS_Settings["Slider"])
	GS_Slider:SetValue(GS_Settings["Slider"])
 end
 
 function GearScore_SendReport(Manual, G_Target, G_Who, G_Direction)
	local Target = ""; local Who = ""; local Direction = ""; local Extra = ""
	if ( GSXSayCheck:GetChecked() ) then Target = "SAY"; end
	if ( GSXPartyCheck:GetChecked() ) then Target = "PARTY"; end
	if ( GSXRaidCheck:GetChecked() ) then Target = "RAID"; end
	if ( GSXGuildCheck:GetChecked() ) then Target = "GUILD"; end
	if ( GSXOfficerCheck:GetChecked() ) then Target = "OFFICER"; end
	if ( GSXWhisperCheck:GetChecked() ) then Target = "WHISPER"; Who = GSX_WhisperEditBox:GetText(); end 	
	if ( GSXWhisperTargetCheck:GetChecked() ) then Target = "WHISPER"; Who = UnitName("target"); end 	
	if ( GSXChannelCheck:GetChecked() ) then Target = "CHANNEL"; Who = GSX_ChannelEditBox:GetText(); end 


	if ( Target == "" ) then print("Por favor marca la casilla de donde quieres que vaya el reporte."); return; end
	if not ( Who ) then return; end	
	if ( GS_SortDirection[GS_SortedType] == 1 ) then Direction = "Mejores"; else Direction = "Peores"; end
	if ( GS_DisplayedGroup == "Search" ) then Extra = "'"..GS_SearchXBox:GetText().."'"; else Extra = GS_DisplayedGroup; end
	if ( GS_DisplayedGroup == "All" ) then Extra = "Base de Datos Completa"; end
	if ( Manual ) then Target = G_Target; Who = G_Who; Direction = "Mejores"; Extra = "GearScore"; end

	SendChatMessage(Direction.." ".." Reportes de GearScore para "..Extra.." ordenados por "..GS_SortedType..".", Target, nil, Who);


	for i,v in ipairs(GSX_DataBase) do
		local DaysOld = GearScore_GetDate(v.Date)
		SendChatMessage("#"..i..".  "..v.GearScore.."    (iLevel "..v.Average..")     "..v.Name, Target, nil, Who)
	--	SendChatMessage("#"..i.." "..v.Name.."   "..v.GearScore.."  ("..v.Average..")   "..v.Level.." "..GS_Races[v.Race].." "..GS_Classes[v.Class], Target, nil, Who)
		if ( i >= GS_Settings["Slider"] ) then break; end
	end
 end
 
 function GearScore_SendSpamReport(Target, Who, Database)
	SendChatMessage("Mejores".." ".." Reportes de GearScore para ".."grupo".." ordenados por ".."GearScore"..".", Target, nil, Who);
	for i,v in ipairs(Database) do
		local DaysOld = GearScore_GetDate(v.Date)
		SendChatMessage("#"..i..".  "..v.GearScore.."    (iLevel "..v.Average..")     "..v.Name, Target, nil, Who)
		--SendChatMessage("#"..i.." "..v.Name.."   "..v.GearScore.."  ("..v.Average..")   "..v.Level.." "..GS_Races[v.Race].." "..GS_Classes[v.Class], Target, nil, Who)
		if ( i >= 26 ) then break; end
	end
 end
 
--------------------------------SETUP-----------------------------------------

function GearScore_TextureOnEnter()
--print("OnEnter!")
end

function GearScore_DatabaseOnClick(Event, Cell, Misc, Button)
	--LibQTip:Release(GearScoreTooltip)
	if ( Button == "RightButton" ) and ( Cell["_line"] > 2 ) and ( Cell["_column"] == 3 ) and ( GSX_DataBase[Cell["_line"]-2+GS_StartPage] )	then ChatFrameEditBox:Show(); ChatFrameEditBox:Insert("/t "..GSX_DataBase[Cell["_line"]-2+GS_StartPage].Name.." "); return; end
	
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 2 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "GearScore", nil, GS_StartPage); return; end
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 3 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "Name", nil, GS_StartPage); return; end
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 4 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "iLevel", nil, GS_StartPage); return; end
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 5 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "Level", nil, GS_StartPage); return; end
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 6 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "Race", nil, GS_StartPage); return; end
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 7 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "Class", nil, GS_StartPage); return; end
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 8 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "Guild", nil, GS_StartPage); return; end
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 9 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "Date", nil, GS_StartPage); return; end	
	if ( Cell["_line"] == 1 ) and ( Cell["_column"] == 10 ) then GearScore_DisplayDatabase(GS_DisplayedGroup, "Scanned", nil, GS_StartPage); return; end
	--print("pie", Cell["_line"], Cell["_column"]) 
	local LineCount = GS_DatabaseFrame.tooltip:GetLineCount(); if not ( LineCount ) then LineCount = 0; end
	--print(LineCount)
	if ( Cell["_line"] > 2 ) and ( Cell["_column"] == 3 ) and ( GSX_DataBase[Cell["_line"]-2] ) and ( Cell["_line"] ~= 28 ) then --GearScore_Send(GSX_DataBase[Cell["_line"]-2+GS_StartPage].Name, "ALL"); 
	GearScore_DisplayUnit(GSX_DataBase[Cell["_line"]-2+GS_StartPage].Name); return; end
	if ( Cell["_line"] > 2 ) and ( Cell["_column"] == 6 ) and ( GSX_DataBase[Cell["_line"]-2] ) then GS_SearchXBox:SetText(GS_Races[(GSX_DataBase[Cell["_line"]-2+GS_StartPage].Race)]); GearScore_HideDatabase(); GearScore_DisplayDatabase("Search"); return; end
	if ( Cell["_line"] > 2 ) and ( Cell["_column"] == 7 ) and ( GSX_DataBase[Cell["_line"]-2] ) then GS_SearchXBox:SetText(GS_Classes[(GSX_DataBase[Cell["_line"]-2+GS_StartPage].Class)]); GearScore_HideDatabase(); GearScore_DisplayDatabase("Search"); return; end
	if ( Cell["_line"] > 2 ) and ( Cell["_column"] == 8 ) and ( GSX_DataBase[Cell["_line"]-2] ) then GS_SearchXBox:SetText((GSX_DataBase[Cell["_line"]-2+GS_StartPage].Guild)); GearScore_HideDatabase(); GearScore_DisplayDatabase("Search"); return; end
--tooltip:AddHeader('#', 'GearScore', '  Name ', "iLevel", 'Level', '  Race   ', ' Class   ', 'Date'); tooltip:AddSeparator(1, 1, 1, 1)
end

function GearScore_Exchange(Type, Who)
	if Type == "DATABASE" then
		GS_ExchangeDatabase =  GearScore_BuildDatabase("All")
		GS_ExchangeName = Who
		GS_ExchangeCount = 1
		GearScore_ContinueExchange()
		print("Transmisión de base de datos de GearScore en progreso")
	end
end

function GearScore_ContinueExchange()
	for i = 1,5 do
	if not GS_ExchangeCount then return; end
	if ( GS_ExchangeDatabase[GS_ExchangeCount] ) then
			GearScore_Send(GS_ExchangeDatabase[GS_ExchangeCount].Name, "WHISPER", GS_ExchangeName)
			GS_ExchangeCount = GS_ExchangeCount + 1
		else
		print("¡Transmisión de base de datos de GearScore completada!")
		GS_ExchangeCount = nil
		GS_ExchangeName = nil
		GS_ExchangeDatabase = nil
		GearScore_TimerFrame:Hide()
		end
	end
	GearScore_TimerFrame:Show()
end


if not GearScore_TimerFrame then GearScore_TimerFrame = CreateFrame("Frame") end

function GearScoreCalculateEXP()
	STable = nil
	local STable = {}
	local TotalPoints = 0
	local count = 0
	local SuperCount = 0
	local StatString = ""
	local id = 0
	--local BackString = {}
	
	-- Verificar que las tablas necesarias existen
	if not GS_AchInfo or not GS_BackString then
		print("|cffff0000GearScore:|r Datos de achievements no inicializados correctamente")
		return
	end
	
	-- Protección contra errores de achievement categories
	local function safeGetAchievementInfo(categoryID, index)
		if not categoryID or categoryID <= 0 or not index or index <= 0 then
			return nil
		end
		
		-- Verificar que la categoría existe antes de intentar obtener información
		local success, result = pcall(GetAchievementInfo, categoryID, index)
		if success then
			return result
		else
			return nil
		end
	end
	
	for j = 1, 61 do
		id = safeGetAchievementInfo(14823, j)
		if id then
			for i,v in pairs(GS_AchInfo) do
				if v[id] then
				 --   SuperCount = SuperCount + 1
					count = GetComparisonStatistic(id);
					if ( count == "--" ) then count = 0; end
					if ( tonumber(count) > 5 ) then count = 5; end
					STable[GS_BackString[id]] = count
				end
			end
		end
		--BackString[id] = SuperCount
	end
	for j = 1, 30 do
		id = safeGetAchievementInfo(14963, j)
		if id then
			for i,v in pairs(GS_AchInfo) do
				if v[id] then
			--	SuperCount = SuperCount + 1
					count = GetComparisonStatistic(id);
					if ( count == "--" ) then count = 0; end
					if ( tonumber(count) > 5 ) then count = 5; end
					STable[GS_BackString[id]] = count
				 end
			end
		end
		--BackString[id] = SuperCount
	end
	for j = 15, 38 do
		id = safeGetAchievementInfo(15021, j)
		if id then
			for i,v in pairs(GS_AchInfo) do
				if v[id] then
			--	SuperCount = SuperCount + 1
					--print(count,i,v[id])
					count = GetComparisonStatistic(id);
					--print(count,i,v[id])
					if ( count == "--" ) then count = 0; end
					if ( tonumber(count) > 5 ) then count = 5; end
					STable[GS_BackString[id]] = count
					--print(GS_BackString[id], count, id)
				end
			end
		end
	--BackString[id] = SuperCount
	end

	for j = 17, 68 do
		id = safeGetAchievementInfo(15062, j)
		if id then
			for i,v in pairs(GS_AchInfo) do
				if v[id] then
			--	SuperCount = SuperCount + 1
					--print(count,i,v[id])
					count = GetComparisonStatistic(id);
					--print(count,i,v[id])
					if ( count == "--" ) then count = 0; end
					if ( tonumber(count) > 5 ) then count = 5; end
					STable[GS_BackString[id]] = count
					--print(GS_BackString[id], count, id)
				end
			end
		end
	--BackString[id] = SuperCount
	end	
	
	
	
	
	if GS_Settings["BackString"] then GS_Settings["BackString"] = nil; end
	--GS_Settings["BackString"] = BackString
	StatString = ""
	for i,v in ipairs(STable) do
		StatString = StatString..v
	end
	--print(StatString)
	
	--	if UnitName("target") then

			if not ( GS_Data[GetRealmName()]["CurrentPlayer"] ) then GS_Data[GetRealmName()]["CurrentPlayer"] = {}; end
			
		--	if GS_Data[GetRealmName()].Players[UnitName("mouseover")] then
			   GS_Data[GetRealmName()]["CurrentPlayer"]["EXP"] = StatString
				--SendAddonMessage("GSZZZ", StatString, "GUILD")
				--SendAddonMessage("GSZZZ", StatString, "PARTY")
	--		end
	--	end

end

function GS_DisplayXP(Name)
	--print("Displaying", Name)
	GS_XpedName = Name
	local StatTable = {}; --local RangeCheck = nil
	StatTable, RangeCheck = GS_DecodeStats(Name)
	local barcount = 0
	if not StatTable  then print("Fuera de alcance"); return; end
	for i,v in ipairs(GS_InstanceOrder) do
		local RangeCheck = nil
		if not (StatTable[v]) then StatTable[v] = 0; end
		barcount = barcount + 1
		local PPValue = (floor(( StatTable[v] / GS_AchMax[v] ) * 100 ))
		local red,green,blue = 0,0,0
		_G["GS_XpBar"..barcount]:SetValue(PPValue )

		
		if ( PPValue < 50 ) then  red, green, blue = 1,(PPValue / 50),(PPValue / 100); end
		if ( PPValue >= 50 ) then red, green, blue = 1 - ((PPValue - 50) * 0.02), 1, 0.5 - ((PPValue - 50) * 0.01) ; end
		_G["GS_XpBar"..barcount]:SetStatusBarColor(red, green, blue)		
		_G["GS_XpBar"..barcount.."PercentText"]:SetText(PPValue .."%")
		if not ( UnitName("target") ) then _G["GS_XpBar"..barcount.."PercentText"]:SetText("Sin Objetivo"); end
		--if ( RangeCheck ) then _G["GS_XpBar"..barcount.."PercentText"]:SetText("Fuera de Alcance / Sin objetivo"); end
		_G["GS_XpBar"..barcount.."InstaceText"]:SetText(GearScore_GetInstanceTranslation(v))
	end
end

function GS_DecodeStats(Name)
	--print("DecodingStats for ", Name)
	local StatTable = {}
	local count = 0; --local RangeCheck = nil
	local StatString = ""
	if not GS_Data[GetRealmName()]["CurrentPlayer"] then GS_Data[GetRealmName()]["CurrentPlayer"] = {}; end
	if GS_Data[GetRealmName()].Players[Name] then
		if GS_Data[GetRealmName()]["CurrentPlayer"]["EXP"] then
			StatString = GS_Data[GetRealmName()]["CurrentPlayer"]["EXP"]
		else
			for i = 1,114 do
			StatString = StatString.."0"
			end
			--RangeCheck = true
		end
	end
		for i,v in pairs(GS_BackString) do
			count = tonumber(string.sub(StatString, v, v))
			for j, w in pairs(GS_AchInfo) do
				if w[i] then
					StatTable[j] = (StatTable[j] or 0) + ( count or 0 );
					--if not count then print(j, i, v); end
					break;
				end

			end
		end
		return StatTable, RangeCheck
end



hooksecurefunc("SetItemRef",GearScoreSetItemRef)

GearScore_TimerFrame:Hide()
GearScore_TimerFrame:SetScript("OnUpdate", GearScore_OnUpdate)
local f = CreateFrame("Frame", "GearScore", UIParent);
f:SetScript("OnUpdate", GearScore_ThrottleUpdate)
f:SetScript("OnEvent", GearScore_OnEvent);
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
f:RegisterEvent("CHAT_MSG_ADDON");
f:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
f:RegisterEvent("INSPECT_READY")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
GameTooltip:HookScript("OnTooltipSetUnit", GearScore_HookSetUnit)
GameTooltip:HookScript("OnTooltipSetItem", GearScore_HookSetItem)
ShoppingTooltip1:HookScript("OnTooltipSetItem", GearScore_HookCompareItem)
ShoppingTooltip2:HookScript("OnTooltipSetItem", GearScore_HookCompareItem2)
PaperDollFrame:HookScript("OnShow", MyPaperDoll)
PaperDollFrame:CreateFontString("PersonalGearScore")
PersonalGearScore:SetFont("Fonts\\FRIZQT__.TTF", 10)
PersonalGearScore:SetText("GS: 0")
PersonalGearScore:SetPoint("BOTTOMLEFT",PaperDollFrame,"TOPLEFT",72,-253)
PersonalGearScore:Show()
PaperDollFrame:CreateFontString("GearScore2")
GearScore2:SetFont("Fonts\\FRIZQT__.TTF", 10)
GearScore2:SetText("GearScore")
GearScore2:SetPoint("BOTTOMLEFT",PaperDollFrame,"TOPLEFT",72,-265)
GearScore2:Show()
ItemRefTooltip:HookScript("OnTooltipSetItem", GearScore_HookRefItem)
-- Usar hooksecurefunc para evitar taint
function GS_ShouldBlockInspect()
    if not GS_HookEnabled then
        return true
    end
    if GS_BlockAllInspects then
        return true
    end
    if PaperDollFrame and PaperDollFrame:IsVisible() then
        return true
    end
    local _, class = UnitClass("player")
    if class == "ROGUE" then
        local hasMain, _, _, hasOff = GetWeaponEnchantInfo()
        if hasMain or hasOff then
            return true
        end
    end
    return false
end


GearScore_Original_SetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = GearScore_OnEnter
-- Función simple para obtener información de gemas
function GS_GetPlayerGems(playerName)
	if not GS_Data[GetRealmName()].Players[playerName] or not GS_Data[GetRealmName()].Players[playerName].Equip then return end
	
	-- Simplemente intentar obtener información actualizada de los items
	for i = 1, 19 do
		if GS_Data[GetRealmName()].Players[playerName].Equip[i] then
			local equipValue = GS_Data[GetRealmName()].Players[playerName].Equip[i]
			if type(equipValue) == "string" and equipValue ~= "" and equipValue ~= "0" then
				-- Intentar obtener link actualizado si no lo tenemos
				if not equipValue:find("|Hitem:") then
					local name, link = GetItemInfo("item:" .. equipValue)
					if link then
						GS_Data[GetRealmName()].Players[playerName].Equip[i] = link
					end
				end
			end
		end
	end
end

-- Función para cargar gemas de forma diferida (simplificada)
function GS_LoadGemsDelayed(playerName)
	if not GS_Settings or GS_Settings["EnableModel"] == false then return end
	if GS_Settings["DisableGems"] then return end
	if not GS_Data[GetRealmName()].Players[playerName] or not GS_Data[GetRealmName()].Players[playerName].Equip then return end
	
	-- Crear timer simple
	local gemTimer = CreateFrame("Frame")
	gemTimer.timeLeft = 0.8  -- Dar más tiempo para que el equipo cargue primero
	gemTimer.playerName = playerName
	
	gemTimer:SetScript("OnUpdate", function(self, elapsed)
		self.timeLeft = self.timeLeft - elapsed
		if self.timeLeft <= 0 then
			-- Cargar todos los items con gemas directamente
			local gemsLoaded = 0
			for i = 1, 19 do
				if GS_Data[GetRealmName()].Players[self.playerName].Equip[i] then
					local equipValue = GS_Data[GetRealmName()].Players[self.playerName].Equip[i]
					
					-- Solo cargar si es un link completo con información de gemas
					if type(equipValue) == "string" and equipValue:find("|Hitem:") then
						pcall(function() 
							GS_Model:TryOn(equipValue)
							gemsLoaded = gemsLoaded + 1
						end)
					end
				end
			end
			
			if GS_Settings and GS_Settings["DebugGems"] then
				print("|cffFFFF00GearScore:|r Intentado cargar " .. gemsLoaded .. " items con gemas")
			end
			self:SetScript("OnUpdate", nil)
		end
	end)
end

-- Función para debug del modelo 3D
function GS_DebugModel()
	if not GS_Settings then GS_Settings = {} end
	local modelEnabled = GS_Settings["EnableModel"] ~= false
	local gemsEnabled = not GS_Settings["DisableGems"]
	print("|cffFFFF00GearScore Debug:|r")
	print("- Modelo habilitado: " .. (modelEnabled and "Sí" or "No"))
	print("- Gemas habilitadas: " .. (gemsEnabled and "Sí" or "No"))
	print("- Índice historial actual: " .. GS_CurrentHistoryIndex)
	print("- GS_Model existe: " .. (GS_Model and "Sí" or "No"))
	if GS_Model then
		print("- GS_Model visible: " .. (GS_Model:IsVisible() and "Sí" or "No"))
	end
	
	-- Información del cache
	local modelCacheCount = 0
	local statCacheCount = 0
	if GS_ModelCache then
		for k,v in pairs(GS_ModelCache) do modelCacheCount = modelCacheCount + 1 end
	end
	if GS_StatCache then
		for k,v in pairs(GS_StatCache) do statCacheCount = statCacheCount + 1 end
	end
	print("- Cache modelo: " .. modelCacheCount .. " entradas")
	print("- Cache stats: " .. statCacheCount .. " entradas")
	
	if GS_DisplayPlayer then
		print("- Jugador actual: " .. GS_DisplayPlayer)
		if GS_Data and GS_Data[GetRealmName()] and GS_Data[GetRealmName()].Players[GS_DisplayPlayer] then
			local playerData = GS_Data[GetRealmName()].Players[GS_DisplayPlayer]
			local history = playerData.EquipHistory
			if history then
				print("- Historiales guardados: " .. #history)
			else
				print("- Historiales guardados: 0")
			end
			
			-- Verificar items con gemas en el equipo actual
			local itemsWithGems = 0
			if playerData.Equip then
				for i = 1, 19 do
					if playerData.Equip[i] and type(playerData.Equip[i]) == "string" and playerData.Equip[i]:find("|Hitem:") then
						-- Contar los : en el string para ver si tiene gemas
						local colonCount = 0
						for colon in playerData.Equip[i]:gmatch(":") do
							colonCount = colonCount + 1
						end
						if colonCount > 6 then
							itemsWithGems = itemsWithGems + 1
						end
					end
				end
			end
			print("- Items con información de gemas: " .. itemsWithGems)
		end
	else
		print("- No hay jugador seleccionado")
	end
	
	print("Usa |cff00FF00/gslimpiarcache|r si tienes problemas de carga")
end

-- Sistema de historial de equipamiento
function GS_SaveEquipmentHistory(playerName, currentEquip, currentGS, currentDate, currentAverage, currentStats)
	if not GS_Data[GetRealmName()].Players[playerName] then 
		return 
	end
	if not currentEquip then 
		return 
	end
	
	-- Inicializar historial si no existe
	if not GS_Data[GetRealmName()].Players[playerName].EquipHistory then
		GS_Data[GetRealmName()].Players[playerName].EquipHistory = {}
	end
	
	local history = GS_Data[GetRealmName()].Players[playerName].EquipHistory
	
	-- Solo guardar si es diferente al último equipo guardado
	local isDifferent = (#history == 0 or not GS_CompareEquipment(currentEquip, history[#history].Equip))
	
	if isDifferent then
		table.insert(history, {
			Equip = GS_CopyTable(currentEquip),
			GearScore = currentGS,
			Date = currentDate,
			Average = currentAverage,
			Stats = currentStats and GS_CopyTable(currentStats) or nil,  -- Guardar estadísticas también
			SaveTime = GetTime()
		})
		
		-- Mantener EXACTAMENTE 5 historiales máximo para no saturar la memoria
		while #history > 5 do
			table.remove(history, 1)  -- Eliminar el más antiguo
		end
	end
end

-- Función para copiar una tabla
function GS_CopyTable(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = GS_CopyTable(orig_value)
		end
	else
		copy = orig
	end
	return copy
end

-- Función para comparar equipamiento
function GS_CompareEquipment(equip1, equip2)
	if not equip1 or not equip2 then return false end
	
	for i = 1, 19 do
		if equip1[i] ~= equip2[i] then
			return false
		end
	end
	return true
end

-- Función para mostrar equipo anterior
function GS_ShowPreviousEquipment()
	local currentPlayer = GS_DisplayPlayer
	if not currentPlayer or not GS_Data[GetRealmName()].Players[currentPlayer] then
		print("|cffFFFF00GearScore:|r No hay jugador seleccionado actualmente.")
		return
	end
	
	local history = GS_Data[GetRealmName()].Players[currentPlayer].EquipHistory
	if not history or #history == 0 then
		print("|cffFFFF00GearScore:|r No hay historial de equipo para " .. currentPlayer)
		return
	end
	
	-- Incrementar el índice del historial
	GS_CurrentHistoryIndex = GS_CurrentHistoryIndex + 1
	if GS_CurrentHistoryIndex > #history then
		GS_CurrentHistoryIndex = 1  -- Volver al primero
	end
	
	-- Mostrar qué historial estamos viendo
	local historyEntry = history[#history - GS_CurrentHistoryIndex + 1]
	if historyEntry then
		local timeText = GearScore_GetReadableSaveTime(historyEntry.SaveTime)
		print("|cffFFFF00GearScore:|r Equipo " .. GS_CurrentHistoryIndex .. "/" .. #history .. " de " .. currentPlayer .. " (" .. timeText .. ", GS: " .. historyEntry.GearScore .. ")")
		GearScore_DisplayUnit(currentPlayer)
	else
		GS_CurrentHistoryIndex = 0
		print("|cffFFFF00GearScore:|r No hay más historial. Volviendo al equipo actual.")
		GearScore_DisplayUnit(currentPlayer)
	end
end

-- Función para listar todos los historiales disponibles
function GS_ListEquipmentHistory()
	local currentPlayer = GS_DisplayPlayer
	if not currentPlayer or not GS_Data[GetRealmName()].Players[currentPlayer] then
		print("|cffFFFF00GearScore:|r No hay jugador seleccionado actualmente.")
		return
	end
	
	local history = GS_Data[GetRealmName()].Players[currentPlayer].EquipHistory
	if not history or #history == 0 then
		print("|cffFFFF00GearScore:|r No hay historial de equipo para " .. currentPlayer)
		return
	end
	
	print("|cffFFFF00GearScore:|r Historial de " .. currentPlayer .. " (" .. #history .. "/5 slots máximo):")
	for i = #history, 1, -1 do
		local entry = history[i]
		local timeText = GearScore_GetReadableSaveTime(entry.SaveTime)
		local index = #history - i + 1
		local current = (GS_CurrentHistoryIndex == index) and " |cff00FF00[ACTUAL]|r" or ""
		print("  " .. index .. ". GS: " .. entry.GearScore .. " - " .. timeText .. current)
	end
	print("Usa |cff00FF00/gsprev|r para navegar o |cff00FF00/gsactual|r para el equipo actual")
end

-- Función para volver al equipo actual
function GS_ShowCurrentEquipment()
	GS_CurrentHistoryIndex = 0
	if GS_DisplayPlayer then
--		print("|cffFFFF00GearScore:|r Mostrando equipo actual de " .. GS_DisplayPlayer)
		GearScore_DisplayUnit(GS_DisplayPlayer)
	end
end

-- Variable global para controlar qué historial se está mostrando
GS_CurrentHistoryIndex = 0  -- 0 = actual, 1 = anterior, 2 = anterior al anterior, etc.

-- Función para alternar debug de gemas
function GS_ToggleGemDebug()
	if not GS_Settings then GS_Settings = {} end
	if GS_Settings["DebugGems"] then
		GS_Settings["DebugGems"] = false
		print("|cffFFFF00GearScore:|r Debug de gemas desactivado.")
	else
		GS_Settings["DebugGems"] = true
		print("|cffFFFF00GearScore:|r Debug de gemas activado. Verás información detallada de carga.")
	end
end

-- Función para forzar carga de gemas (útil cuando el jugador está lejos)
function GS_ForceLoadGems()
	local currentPlayer = GS_DisplayPlayer
	if not currentPlayer then
		print("|cffFFFF00GearScore:|r No hay jugador seleccionado.")
		return
	end
	
	if not GS_Settings or GS_Settings["EnableModel"] == false then
		print("|cffFFFF00GearScore:|r El modelo 3D está desactivado. Usa /gs3d para activarlo.")
		return
	end
	
	if GS_Settings["DisableGems"] then
		print("|cffFFFF00GearScore:|r Las gemas están desactivadas. Usa /gsgemas para activarlas.")
		return
	end
	
	print("|cffFFFF00GearScore:|r Forzando carga de gemas para " .. currentPlayer .. "...")
	
	-- Obtener información actualizada primero
	GS_GetPlayerGems(currentPlayer)
	
	-- Esperar un poco y luego cargar gemas
	local forceTimer = CreateFrame("Frame")
	forceTimer.timeLeft = 0.2
	forceTimer:SetScript("OnUpdate", function(self, elapsed)
		self.timeLeft = self.timeLeft - elapsed
		if self.timeLeft <= 0 then
			GS_LoadGemsDelayed(currentPlayer)
			self:SetScript("OnUpdate", nil)
		end
	end)
end

-- Función para alternar las gemas en el modelo 3D
function GS_ToggleGems()
	if not GS_Settings then GS_Settings = {} end
	if GS_Settings["DisableGems"] then
		GS_Settings["DisableGems"] = false
		print("|cffFFFF00GearScore:|r Gemas en modelo 3D activadas. Mejor visualización pero carga más lenta.")
	else
		GS_Settings["DisableGems"] = true
		print("|cffFFFF00GearScore:|r Gemas en modelo 3D desactivadas. Carga más rápida del modelo.")
	end
end

-- Función para alternar el modelo 3D
function GS_ToggleModel()
	if not GS_Settings then GS_Settings = {} end
	if GS_Settings["EnableModel"] == false then
		GS_Settings["EnableModel"] = true
		GS_Settings["ModelJustEnabled"] = true  -- Forzar recarga del modelo
		-- Limpiar cache para forzar actualización
		if GS_ModelCache then GS_ModelCache = {} end
		print("|cffFFFF00GearScore:|r Modelo 3D activado. Cache limpiado para forzar recarga.")
	else
		GS_Settings["EnableModel"] = false
		print("|cffFFFF00GearScore:|r Modelo 3D desactivado. Máximo rendimiento recomendado para consultas rápidas.")
	end
end

-- Funciones para el botón de historial de equipamiento (versión simplificada)
function GearScore_CreateHistoryButton()
	if GS_HistoryButton then return end -- Ya existe
	-- Crear el botón de historial
	local button = CreateFrame("Button", "GS_HistoryButton", GS_DisplayFrame, "UIPanelButtonTemplate")
	button:SetSize(120, 22)
	button:SetPoint("TOPLEFT", GS_DisplayFrame, "TOPLEFT", 280, -440)
	button:SetText("Historial")
	button:SetScript("OnClick", GearScore_HistoryButton_OnClick)
	button:Show()
	GS_HistoryButton = button
	-- Crear el botón Equipo BIS
	if not GS_EquipBISButton then
		local bisButton = CreateFrame("Button", "GS_EquipBISButton", GS_DisplayFrame, "UIPanelButtonTemplate")
		bisButton:SetSize(120, 22)
		bisButton:SetPoint("TOPLEFT", GS_DisplayFrame, "TOPLEFT", 400, -440) -- 10 píxeles a la izquierda
		bisButton:SetText("Equipo BIS")
		bisButton:SetScript("OnClick", function()
			if GS_DisplayFrame then GS_DisplayFrame:Hide() end
			if ToggleBISFrame then ToggleBISFrame() end
		end)
		bisButton:Show()
		GS_EquipBISButton = bisButton

		-- Crear el botón Copiar BIS justo después
		if not GS_CopyBISButton then
			local copyBtn = CreateFrame("Button", "GS_CopyBISButton", GS_DisplayFrame, "UIPanelButtonTemplate")
			copyBtn:SetSize(80, 22)--120
			copyBtn:SetPoint("TOPLEFT", GS_DisplayFrame, "TOPLEFT", 198, -440)
			copyBtn:SetText("Copiar BIS")
			copyBtn:SetScript("OnClick", function()
				   if _G.ShowCopySetDialog then ShowCopySetDialog() end
			end)
			copyBtn:Show()
			GS_CopyBISButton = copyBtn
		end
	end
	print("|cffFFFF00GearScore:|r Botón de historial, Equipo BIS y Copiar BIS creados programáticamente")
end

function GearScore_UpdateHistoryButton(playerName)
	-- Intentar crear el botón si no existe
	if not GS_HistoryButton then 
		GS_HistoryButton = _G["GS_HistoryButton"]
		if not GS_HistoryButton then
			GearScore_CreateHistoryButton()
		end
	end
	
	if not GS_HistoryButton then return end
	
	if not playerName then
		GS_HistoryButton:SetText("Sin jugador")
		GS_HistoryButton:Disable()
		return
	end
	
	if not GS_Data[GetRealmName()].Players[playerName] then
		GS_HistoryButton:SetText("Sin datos")
		GS_HistoryButton:Disable()
		return
	end
	
	-- Acceso más directo al historial
	local playerData = GS_Data[GetRealmName()].Players[playerName]
	local history = playerData.EquipHistory
	
	if not history or #history == 0 then
		GS_HistoryButton:SetText("Sin historial")
		GS_HistoryButton:Disable()
		return
	end
	
	-- Mostrar estado actual
	GS_HistoryButton:Enable()
	local currentText = "Actual"
	if GS_CurrentHistoryIndex and GS_CurrentHistoryIndex > 0 then
		currentText = "Historial " .. GS_CurrentHistoryIndex .. "/" .. #history
	else
		currentText = "Actual (1/" .. (#history + 1) .. ")"
	end
	GS_HistoryButton:SetText(currentText)
	GS_HistoryButton:Show()
end

function GearScore_HistoryButton_OnClick()
	local playerName = GS_DisplayPlayer
	if not playerName or not GS_Data[GetRealmName()].Players[playerName] then return end
	
	local history = GS_Data[GetRealmName()].Players[playerName].EquipHistory
	if not history or #history == 0 then return end
	
	-- Ciclar entre equipos: Actual -> Historial 1 -> Historial 2 -> ... -> Actual
	if not GS_CurrentHistoryIndex or GS_CurrentHistoryIndex == 0 then
		-- Ir al primer historial
		GS_CurrentHistoryIndex = 1
	elseif GS_CurrentHistoryIndex >= #history then
		-- Volver al actual
		GS_CurrentHistoryIndex = 0
	else
		-- Siguiente historial
		GS_CurrentHistoryIndex = GS_CurrentHistoryIndex + 1
	end
	
	-- Actualizar display
	GearScore_DisplayUnit(playerName)
--	print("|cffFFFF00GearScore:|r " .. (GS_CurrentHistoryIndex == 0 and "Mostrando equipo actual" or ("Mostrando historial " .. GS_CurrentHistoryIndex .. "/" .. #history)))
end

-- Función para forzar actualización del botón
function GS_ForceUpdateHistoryButton()
	local currentPlayer = GS_DisplayPlayer
	if not currentPlayer then
		print("|cffFFFF00GearScore:|r No hay jugador seleccionado")
		return
	end
	
--	print("|cffFFFF00GearScore:|r Forzando actualización del botón para " .. currentPlayer)
	GearScore_UpdateHistoryButton(currentPlayer)
end

-- Función para activar debug del historial
function GS_ToggleHistoryDebug()
	if not GS_Settings then GS_Settings = {} end
	if GS_Settings["DebugHistory"] then
		GS_Settings["DebugHistory"] = false
		print("|cffFFFF00GearScore:|r Debug de historial desactivado")
	else
		GS_Settings["DebugHistory"] = true
		print("|cffFFFF00GearScore:|r Debug de historial activado")
	end
end

-- Función para debug del botón de historial
function GS_DebugHistoryDropdown()
	print("|cffFFFF00GearScore Debug Historial:|r")
	print("- GS_HistoryButton existe: " .. (GS_HistoryButton and "Sí" or "No"))
	print("- _G['GS_HistoryButton'] existe: " .. (_G["GS_HistoryButton"] and "Sí" or "No"))
	
	if _G["GS_HistoryButton"] then
		local button = _G["GS_HistoryButton"]
		print("- Botón visible: " .. (button:IsVisible() and "Sí" or "No"))
		print("- Botón mostrado: " .. (button:IsShown() and "Sí" or "No"))
		print("- Botón habilitado: " .. (button:IsEnabled() and "Sí" or "No"))
		print("- Texto del botón: " .. (button:GetText() or "Sin texto"))
	end
	
	if GS_DisplayPlayer then
		print("- Jugador actual: " .. GS_DisplayPlayer)
		local playerData = GS_Data[GetRealmName()].Players[GS_DisplayPlayer]
		if playerData then
			local history = playerData.EquipHistory
			print("- Tiene historial: " .. (history and #history > 0 and "Sí (" .. #history .. " entradas)" or "No"))
			print("- Índice actual: " .. (GS_CurrentHistoryIndex or "0 (actual)"))
			
			-- Mostrar detalles del historial si existe
			if history and #history > 0 then
				for i = 1, #history do
					local entry = history[i]
					local timeText = GearScore_GetReadableSaveTime(entry.SaveTime)
					print("  " .. i .. ". GS: " .. entry.GearScore .. " - " .. timeText)
				end
			end
		else
			print("- No hay datos del jugador en BD")
		end
	else
		print("- No hay jugador seleccionado")
	end
	
	-- Forzar actualización del botón para test
	print("- Forzando actualización del botón...")
	GearScore_UpdateHistoryButton(GS_DisplayPlayer)
end

-- Función para limpiar cache manual
function GS_ClearCache()
	if GS_ModelCache then GS_ModelCache = {} end
	if GS_StatCache then GS_StatCache = {} end
	print("|cffFFFF00GearScore:|r Cache limpiado. Próximas consultas recargarán toda la información.")
end

SlashCmdList["MYSCRIPT"] = GS_SPAM
SLASH_MYSCRIPT1 = "/gspam";
SlashCmdList["MY2SCRIPT"] = GS_MANSET
SLASH_MY2SCRIPT1 = "/gset"
SLASH_MY2SCRIPT3 = "/gearscore"
SlashCmdList["MY3SCRIPT"] = GS_SCANSET
SLASH_MY3SCRIPT3 = "/gs"
SLASH_MY3SCRIPT1 = "/gscanear"
SLASH_MY3SCRIPT2 = "/gsbuscar"
SlashCmdList["MY4SCRIPT"] = GS_BANSET
SLASH_MY4SCRIPT1 = "/gsban"
SlashCmdList["MY5SCRIPT"] = GS_ToggleModel
SLASH_MY5SCRIPT1 = "/gs3d"
SlashCmdList["MY6SCRIPT"] = GS_DebugModel
SLASH_MY6SCRIPT1 = "/gsdebug"
SlashCmdList["MY7SCRIPT"] = GS_ToggleGems
SLASH_MY7SCRIPT1 = "/gsgemas"
SlashCmdList["MY8SCRIPT"] = GS_ShowPreviousEquipment
SLASH_MY8SCRIPT1 = "/gsprev"
SLASH_MY8SCRIPT2 = "/gshistorico"
SlashCmdList["MY9SCRIPT"] = GS_ShowCurrentEquipment
SLASH_MY9SCRIPT1 = "/gscurrent"
SlashCmdList["MY10SCRIPT"] = GS_ListEquipmentHistory
SLASH_MY10SCRIPT1 = "/gslist"
SlashCmdList["MY11SCRIPT"] = GS_ForceLoadGems
SLASH_MY11SCRIPT1 = "/gscargar"
SLASH_MY11SCRIPT2 = "/gsforzargems"
SlashCmdList["MY12SCRIPT"] = GS_ToggleGemDebug
SLASH_MY12SCRIPT1 = "/gsgemdebug"
SlashCmdList["MY13SCRIPT"] = GS_ClearCache
SLASH_MY13SCRIPT1 = "/gslimpiarcache"
SlashCmdList["MY14SCRIPT"] = GS_DebugHistoryDropdown
SLASH_MY14SCRIPT1 = "/gshistoricodebug"
SlashCmdList["MY15SCRIPT"] = GearScore_CreateHistoryButton
SLASH_MY15SCRIPT1 = "/gscrearhistorico"
SlashCmdList["MY16SCRIPT"] = GS_ToggleHistoryDebug
SLASH_MY16SCRIPT1 = "/gsactivarhistorico"
SlashCmdList["MY17SCRIPT"] = GS_ForceUpdateHistoryButton
SLASH_MY17SCRIPT1 = "/gsforzaractualizacion"
SlashCmdList["MY18SCRIPT"] = GS_ForceGemRetry
SLASH_MY18SCRIPT1 = "/gsreintentar"
SLASH_MY18SCRIPT2 = "/gsreintentargemas"

SlashCmdList["MY19SCRIPT"] = GS_InspectTarget
SLASH_MY19SCRIPT1 = "/gsinspeccionar"
SLASH_MY19SCRIPT2 = "/gsi"

SlashCmdList["MY20SCRIPT"] = GS_DebugStats
SLASH_MY20SCRIPT1 = "/gsstatsdebug"

-- Función para debuggear estadísticas guardadas
function GS_DebugStats()
	local targetName = UnitName("target") or GS_DisplayPlayer
	if not targetName then
		print("|cffFFFF00GearScore:|r No tienes target ni jugador seleccionado en display")
		return
	end
	
	if GS_Data[GetRealmName()].Players[targetName] then
		local player = GS_Data[GetRealmName()].Players[targetName]
		print("|cffFFFF00GearScore Stats Debug para " .. targetName .. ":|r")
		
		-- Stats actuales
		if player.Stats then
			print("  |cffffff00Stats actuales:|r")
			for stat, value in pairs(player.Stats) do
				if value > 0 then
					print("    " .. stat .. ": " .. value)
				end
			end
		else
			print("  |cffff0000No hay stats actuales guardadas|r")
		end
		
		-- Stats en historial
		if player.EquipHistory then
			for i, entry in ipairs(player.EquipHistory) do
				print("  |cffffff00Historial " .. i .. " (" .. (entry.Date or "sin fecha") .. "):|r")
				if entry.Stats then
					local statCount = 0
					for stat, value in pairs(entry.Stats) do
						if value > 0 then
							statCount = statCount + 1
						end
					end
					print("    Stats disponibles: " .. statCount .. " estadísticas")
				else
					print("    |cffff0000Sin estadísticas guardadas|r")
				end
			end
		else
			print("  |cffff0000No hay historial disponible|r")
		end
	else
		print("|cffFFFF00GearScore:|r " .. targetName .. " no está en la base de datos")
	end
end

-- Función para inspeccionar el target actual
function GS_InspectTarget()
	if UnitName("target") then
		if CanInspect("target") then
			NotifyInspect("target")
			GearScore_GetScore(UnitName("target"), "target")
			
			-- Mostrar display si no está visible
			if not (GS_DisplayFrame and GS_DisplayFrame:IsVisible()) then
				GearScore_DisplayUnit(UnitName("target"), 1)
			end
		end
	end
end

-- Función para forzar reintento de gemas manualmente
function GS_ForceGemRetry()
	local playerName = GS_DisplayPlayer
	if not playerName then
		print("|cffFFFF00GearScore:|r No hay jugador seleccionado")
		return
	end
	
	if not UnitExists("target") or UnitName("target") ~= playerName then
		print("|cffFFFF00GearScore:|r El jugador debe estar targetado para forzar carga de gemas")
		return
	end
	
	if GS_Settings and GS_Settings["DisableGems"] then
		print("|cffFFFF00GearScore:|r Las gemas están desactivadas. Usa /gsgemas para activarlas")
		return
	end
	
	-- Activar temporalmente el debug para este reintento
	local wasDebugActive = GS_Settings and GS_Settings["DebugGems"]
	if not GS_Settings then GS_Settings = {} end
	GS_Settings["DebugGems"] = true
	
	-- Forzar verificación y reintento
	GearScore_CheckAndRetryGems(playerName, "target")
	
	-- Restaurar estado de debug anterior
	if not wasDebugActive then
		GS_Settings["DebugGems"] = false
	end
end

-- Inicializar botón de historial cuando se carga el addon
GearScore_CreateHistoryButton()

GS_DisplayFrame:Hide()
LibQTip = LibStub("LibQTipClick-1.1")




