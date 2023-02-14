AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.Spawnable		            	 = false        
ENT.AdminSpawnable		             = false 

ENT.PrintName		                 =  "Flash Flood"
ENT.Author			                 =  "Hmm"
ENT.Contact		                     =  "Hmm"
ENT.Category                         =  "Hmm"
ENT.MaxFloodLevel                    =  500
ENT.Mass                             =  100
ENT.Model                            =  "models/props_junk/PopCan01a.mdl"


function ENT:Initialize()	

	
	if (SERVER) then
		
		self:SetModel(self.Model)

		self:SetSolid( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE  )
		self:SetUseType( ONOFF_USE )
		self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		
		local phys = self:GetPhysicsObject()
		
		if (phys:IsValid()) then
			phys:SetMass(self.Mass)
		end 		
		
		self.FloodHeight = 0
		self:SetNWFloat("FloodHeight", self.FloodHeight)
		

			
		
	end
end

function ENT:EFire(pointer, arg) 
	
	if pointer == "EnableFHGain" then self.shouldFloodGainHeight = arg or true 
	elseif pointer == "Enable" then 
	elseif pointer == "MaxHeight" then self.MaxFloodHeight = arg or 400 
	elseif pointer == "Parent" then self.Parent = arg 
	end
end

function createFlood(maxheight, parent)
	
	for k, v in pairs(ents.FindByClass("env_dynamicwater")) do
		v:Remove()
	end
	
	local flood = ents.Create("env_dynamicwater")
	flood:SetPos(getMapCenterFloorPos())
	flood:Spawn()
	flood:Activate()
	
	
	flood:EFire("Parent", parent)
	flood:EFire("MaxHeight", maxheight)
	flood:EFire("Enable", true)
	
	return flood

end

function ENT:SpawnFunction( ply, tr )
	if ( !tr.Hit ) then return end
	
	self.OWNER = ply
	local ent = ents.Create( self.ClassName )
	ent:SetPhysicsAttacker(ply)
	
	if IsMapRegistered() == false then 
		ent:SetPos( tr.HitPos + tr.HitNormal * 1  )
	else 
		
		ent:SetPos( getMapCenterFloorPos() )
	end
	
	ent:Spawn()
	ent:Activate()
	return ent
end


function ENT:FloodHeightIncrement(scalar, t)


	local sim_quality     = GetConVar( "gdisasters_envdynamicwater_simquality" ):GetFloat() --  original water simulation is based on a value of 0.01 ( which is alright but not for big servers ) 
	local sim_quality_mod = sim_quality / 0.01
	local overall_mod     = sim_quality_mod * scalar
	
	
	self.FloodHeight = math.Clamp(self.FloodHeight + ( (1/6) * overall_mod), 0, self.MaxFloodLevel) 
	self:SetNWFloat("FloodHeight", self.FloodHeight)
end


function ENT:PlayerOxygen(v, scalar, t)

	local sim_quality     = GetConVar( "gdisasters_envdynamicwater_simquality" ):GetFloat() --  original water simulation is based on a value of 0.01 ( which is alright but not for big servers ) 
	local sim_quality_mod = sim_quality / 0.01

	local overall_mod     = sim_quality_mod * scalar 
	
	if v.IsInWater then
		v.Oxygen = math.Clamp(v.Oxygen - (engine.TickInterval() * overall_mod ), 0,10)

		
		
		if v.Oxygen <= 0 then

			if math.random(1,math.floor((100/overall_mod)))==1 then
				
				local dmg = DamageInfo()
				dmg:SetDamage( math.random(1,25) )
				dmg:SetAttacker( v )
				dmg:SetDamageType( DMG_DROWN  )

				v:TakeDamageInfo(  dmg)
			end
		
		end
	else
		v.Oxygen = 5
	end
end


function ENT:ProcessFlood(scalar, t)
	local zmax = self:GetPos().z + self.FloodHeight 
	local pos  = self:GetPos() - Vector(0,0,50)
	local wr   = 0.999               -- water friction
	local sim_quality     = GetConVar( "gdisasters_envdynamicwater_simquality" ):GetFloat() --  original water simulation is based on a value of 0.01 ( which is alright but not for big servers ) 
	local sim_quality_mod = sim_quality / 0.01
	
	local overall_mod     = sim_quality_mod * scalar 

	for k, v in pairs(ents.GetAll()) do
	
		local phys = v:GetPhysicsObject()
		
		if phys:IsValid()  and  (v:GetClass()!= "phys_constraintsystem" and v:GetClass()!= "phys_constraint"  and v:GetClass()!= "logic_collision_pair" and v:GetClass()!= "entityflame") then 
			local vpos = v:GetPos()
			local diff = zmax-vpos.z 
			
			if v:IsPlayer() then
			
				local eye = v:EyePos()	
				
				if eye.z >= pos.z and eye.z <= zmax then
					v:SetNWBool("IsUnderwater", true)			
					self:PlayerOxygen(v, scalar, t)

				else

					v.Oxygen = 5 
					if v:GetNWBool("IsUnderwater")==true then
						net.Start("gd_screen_particles")
						net.WriteString("hud/warp_ripple3")
						net.WriteFloat(math.random(10,58))
						net.WriteFloat(math.random(10,50)/10)
						net.WriteFloat(math.random(0,10))
						net.WriteVector(Vector(0,math.random(0,200)/100,0))
						net.Send(v)
					end
					
					v:SetNWBool("IsUnderwater", false)
				end
			end
	
	
	
			if (vpos.z >= pos.z and vpos.z <= zmax) and v.IsInWater!=true then
				v.IsInWater = true 
				
				if math.random(1,2)==1 then
					ParticleEffect( "splash_main", Vector(vpos.x, vpos.y, zmax), Angle(0,0,0), nil)
					v:EmitSound(table.Random({"ambient/water/water_splash1.wav","ambient/water/water_splash2.wav","ambient/water/water_splash3.wav"}), 80, 100)
				end
				
			end
			
			if (v:GetPos().z < pos.z or v:GetPos().z > zmax) and v.IsInWater==true then
				v.IsInWater = false
			end
			
			if v.IsInWater and v:IsPlayer() then
				v:SetVelocity( ((Vector(0,0,math.Clamp(diff,-100,50)/4) * 0.99)  * overall_mod) - (v:GetVelocity() * 0.05))
			elseif v.IsInWater and v:IsNPC() then
				v:SetVelocity( ((Vector(0,0,math.Clamp(diff,-100,50)/4) * 0.99)  * overall_mod) - (v:GetVelocity() * 0.05))
				v:TakeDamage(1, self, self)
			else
				if v.IsInWater then
					
					local massmod       = math.Clamp((phys:GetMass()/25000),0,1)
					local buoyancy_mod  = GetBuoyancyMod(v)
					local buoyancy      = massmod + (buoyancy_mod*(1 + massmod))
					
					local friction      = (1-math.Clamp( (phys:GetVelocity():Length()*overall_mod)/50000,0,1)) 
					local add_vel       = Vector(0,0, (math.Clamp(diff,-20,20)/8 * buoyancy)  * overall_mod)
					phys:AddVelocity( add_vel )
					
					local resultant_vel = v:GetVelocity() * friction
					local final_vel     = Vector(resultant_vel.x * wr,resultant_vel.y * wr, resultant_vel.z * friction)
		
					
					phys:SetVelocity( final_vel)
					
					
				end
			end

		
		end
	
	end
end



function ENT:IsParentValid()

	if self.Parent:IsValid()==false or self.Parent==nil then self:Remove() end
	
end

function ENT:Think()
	if (SERVER) then
		local t =   (66/ ( 1/engine.TickInterval())) * GetConVar( "gdisasters_envdynamicwater_simquality" ):GetFloat()-- tick dependant function that allows for constant think loop regardless of server tickrate
		
		local scalar = (66/ ( 1/engine.TickInterval()))
		self:ProcessFlood(scalar, t)
		self:FloodHeightIncrement(scalar, t)
		self:IsParentValid()
		
		self:NextThink(CurTime() + t)
		return true
	end
	
end
function ENT:OnRemove()
	self:StopParticles()
end

local watertexture = table.Random({"nature/floodwater", "nature/floodwater2"})

local water = Material(watertexture)



	
function ENT:Draw()
			
end

if (CLIENT) then
	function DrawFlood()
	
		
		if IsMapRegistered() then
			local flood = ents.FindByClass("env_dynamicwater")[1]
			if !flood then return end
			

			render.SetMaterial(water)
			local model = ClientsideModel("models/props_junk/PopCan01a.mdl", RENDERGROUP_OPAQUE)
			model:SetNoDraw(true)	
		
			
			local height =  flood:GetNWFloat("FloodHeight")
			
		
			cam.Start3D()
			
				local mat = Matrix()
				mat:Scale(Vector(0, 0, 0))
				model:EnableMatrix("RenderMultiply", mat)
				model:SetPos(flood:GetPos())
				model:DrawModel()
			
				render.SuppressEngineLighting( true ) 
			

				render.DrawBox(getMapCenterFloorPos(), Angle(0, 0, 0), Vector(getMapBounds()[1].x,getMapBounds()[1].y,flood:GetPos().z), Vector(getMapBounds()[2].x,getMapBounds()[2].y,height), Color(255, 255, 255, 25))	
				
				render.SuppressEngineLighting( false ) 
			cam.End3D()
			

			model:Remove()	
			
		else
			
			local flood = ents.FindByClass("gd_d2_flashflood")[1]
			if !flood then return end
			
				

			render.SetMaterial(water)
			local model = ClientsideModel("models/props_junk/PopCan01a.mdl", RENDERGROUP_OPAQUE)
			model:SetNoDraw(true)	
			
				
			local height = self:GetNWFloat("FloodHeight", 0)

			
			cam.Start3D()
			
				local mat = Matrix()
				mat:Scale(Vector(0, 0, 0))
				model:EnableMatrix("RenderMultiply", mat)
				model:SetPos(flood:GetPos())
				model:DrawModel()
				
				render.SuppressEngineLighting( true ) 
				

				render.DrawBox(flood:GetPos(), Angle(0, 0, 0), Vector(-50000,-50000,-height), Vector(50000,50000,height), Color(255, 255, 255, 25))	
			
				render.SuppressEngineLighting( false ) 
			cam.End3D()


			model:Remove()
			
		
		end
		
		
		
		
	
		
		
		
		
		
		
		
		
		
	
	end
	hook.Add("PostDrawTranslucentRenderables", "DRAWFLOOD", DrawFlood)
	
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end


