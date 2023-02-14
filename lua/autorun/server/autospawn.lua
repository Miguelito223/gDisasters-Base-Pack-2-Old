local recentTor = false
CreateConVar( "gdisasters_autospawn_timer", 120, { FCVAR_NOTIFY,FCVAR_ARCHIVE,FCVAR_SERVER_CAN_EXECUTE,FCVAR_PROTECTED}, "How often do you want to run the tornado spawn?")
CreateConVar( "gdisasters_autospawn_spawn_chance", 3, { FCVAR_NOTIFY,FCVAR_ARCHIVE,FCVAR_SERVER_CAN_EXECUTE,FCVAR_PROTECTED}, "What is the chance that a tornado will spawn?")


local function Tornadospawn()
	recentTor = true
	local tornado = {"gd_d3_ef0", "gd_d4_ef1", "gd_d5_ef2", "gd_d6_ef3", "gd_d7_ef4", "gd_d8_ef5" }
	EF = ents.Create( tornado[math.random( 1, #tornado )] .. "" )


	if GetConVar("gdisasters_autospawn"):GetInt() == 1 then
		if S37K_mapbounds == nil or table.IsEmpty(S37K_mapbounds) then
			EF:SetPos(Vector(math.random(-10000,10000),math.random(-10000,10000),5000))
			print("STORM'S LUA LIBRARY MISSING OR MAP IS BROKEN! USING LEGACY SPAWN METHOD!")
		else
			local stormtable = S37K_mapbounds[1]
			EF:SetPos( Vector(math.random(stormtable.negativeX,stormtable.positiveX),math.random(stormtable.negativeY,stormtable.positiveY),stormtable.skyZ) )
		end
		EF:Spawn()
	end
end

local function Removemaptornados()
	if GetConVar('gdisasters_getridmaptor'):GetInt() == 1 then
		for k,v in pairs(ents.FindByClass("func_tracktrain", "func_tanktrain")) do
			v:Remove()
		end
	end
end

hook.Add("InitPostEntity","Removemaptornados",function()
	Removemaptornados()
end)

hook.Add("PostCleanupMap","ReRemovemaptornados",function()
	Removemaptornados()
end)

timer.Create( "tornadotimer", GetConVar( "gdisasters_autospawn_timer" ):GetInt(), 0, function()
	if math.random(0,GetConVar( "gdisasters_autospawn_spawn_chance" ):GetInt()) == GetConVar( "gdisasters_autospawn_spawn_chance" ):GetInt() then
		if recentTor then recentTor = false return end
		Tornadospawn()
	end
end

)
