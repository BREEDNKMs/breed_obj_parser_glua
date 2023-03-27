AddCSLuaFile("entities/basemercuryobject.lua") 

include("autorun/breed_objects.lua") 

local error_model = "models/blackout.mdl"
local scalar = -0.33 
local keystring = "target" -- string to use from keyvalues, which refers to object name at first 
local collision_mesh_sets = 3 

ENT.Base			= "base_gmodentity" 
ENT.Type 			= "anim" 
ENT.PrintName		= "Mercury Entity" 
ENT.Author			= "DevilHawk" 
ENT.Spawnable		= false 

local function GetProperIndex(str) 
	local strindexcount = #str 
	local newstr = str 
	for i = 1, strindexcount do -- iterate throughout the string 
			if string.StartWith(newstr,"0") then 
				newstr = string.sub(newstr,2) -- skip the zero at beginning 
			else 
				break -- stop when we didn't hit any zeros 
			end 
		end 
	return newstr 
end 

function ENT:Initialize() 
	if CLIENT then return end 
	self.ob_name = self:GetKeyValues()[keystring] -- define which ent is this 
	self.tblsubents = { } 
	self:SetOBName(self.ob_name) -- for client 
	-- set model first 
	self:InitModel() 
	self:SetCollisionGroup(COLLISION_GROUP_NPC) 
	self:SetCollisionBounds(self:GetModelBounds()) 
	self:SetSaveValue("m_takedamage",2) 
	self:SetHealth(BREED.Objects[self.ob_name].damage) 
	self:SetMaxHealth(self:Health()) 
	self:SetRenderMode(RENDERMODE_TRANSALPHA) 
	self:InitMoveType() 
	-- then start welding 
	self:InitSubob() 
	self.Mercury_angSpawnAngles = self:GetLocalAngles() 
	self.Mercury_bRotationBounce = false 
	local max = self:OBBMaxs()
	local min = self:OBBMins()
	
	if BREED.Objects[self:GetOBName()].mode == "JET" then 
		-- self.ThrustOffset = Vector( 0, 0, max.z ) 
		self.ThrustOffset = Vector( max.x, 0, 0 ) 
		-- self.ThrustOffsetR = Vector( 0, 0, min.z ) 
		self.ThrustOffsetR = Vector( min.x, 0, 0 ) 
		self.ForceAngle = self.ThrustOffset:GetNormalized() * -1 
		self:SetOffset( self.ThrustOffset ) 
		self:StartMotionController() 
	end 
	
	if BREED.PilotSettings[self:GetOBName()] then 
		self:InitializeSeat() 
	end 
	
	for k,v in pairs(self.tblsubents) do 
		if IsValid(v) then constraint.NoCollide(self,v,0,0) end 
	end 
	self:Activate() 
end 

function ENT:SetupDataTables() 
	self:NetworkVar("String",0,"OBName") 
	self:NetworkVar("Entity",0,"SubEnt") 
	self:NetworkVar("Float",0,"ThrustRate") 
	self:NetworkVar("Vector",0,"Offset") 
end 

function ENT:InitializeSeat() 
	local pos = BREED.PilotSettings[self:GetOBName()].pos*scalar 
	pos = self:LocalToWorld(pos) 
	local pod = ents.Create("prop_vehicle_prisoner_pod") 
	if !IsValid(pod) then return end 
	pod:SetPos(pos) 
	pod:SetAngles(self:GetAngles()) 
	pod:SetParent(self) 
	pod:SetModel("models/blackout.mdl") 
	pod:SetSolid(SOLID_NONE) 
	pod:SetMoveType(MOVETYPE_NONE) 
	pod:SetKeyValue("vehiclescript","scripts/vehicles/prisoner_pod.txt") 
	pod:SetKeyValue("limitview",0) 
	pod:Spawn() 
	pod:SetMoveType(MOVETYPE_NONE) 
	pod:SetNotSolid(1) 
	self.Mercury_entSeat = pod 
end 

if SERVER then  
	function ENT:SetForce( force, mul ) 

		if ( force ) then self.force = force end 
		mul = mul or 1 

		local phys = self:GetPhysicsObject() 
		if ( !IsValid( phys ) ) then 
			Msg( "Warning: [gmod_thruster] Physics object isn't valid!\n" ) 
			return 
		end 

		-- Get the data in worldspace 
		local ThrusterWorldPos = phys:LocalToWorld( self.ThrustOffset ) 
		local ThrusterWorldForce = phys:LocalToWorldVector( self.ThrustOffset * -1 ) 

		-- Calculate the velocity 
		ThrusterWorldForce = ThrusterWorldForce * self.force * mul * 50 

		local motionEnabled = phys:IsMotionEnabled() 
		phys:EnableMotion( true ) -- Dirty hack for PhysObj.CalculateVelocityOffset while frozen 
		self.ForceLinear, self.ForceAngle = phys:CalculateVelocityOffset( ThrusterWorldForce, ThrusterWorldPos ) 
		phys:EnableMotion( motionEnabled ) 

		self.ForceLinear = phys:WorldToLocalVector( self.ForceLinear ) 

		if ( mul > 0 ) then 
			self:SetOffset( self.ThrustOffset ) 
		else 
			self:SetOffset( self.ThrustOffsetR ) 
		end 

		-- self:SetNWVector( 1, self.ForceAngle ) 
		-- self:SetNWVector( 2, self.ForceLinear ) 

		-- self:SetOverlayText( "Force: " .. math.floor( self.force ) ) 

	end 
	
	function ENT:Mercury_GetForceMultiplier() 
		local thrustForce = 1 
		if self:GetMaxHealth() > 1 then 
			thrustForce = self:Health()/self:GetMaxHealth() 
		end 
		if BREED.Objects[self.ob_name].mesh == "5" then return thrustForce*100 end 

		return thrustForce 
	end 
	
end 

--[[ 
-- model name determiner passed to autorun 
function ENT:DecideModelName() 
	local meshtype = BREED.Objects[self.ob_name].mesh 
	if meshtype == "0" then return "models/blackout.mdl" end 
	if meshtype == "5" then return "models/blackout.mdl" end 
	local folderpath = "models/breed/" 
	local filename = file.Find(folderpath..meshtype.."*.mdl","GAME")[1] 
	if !filename then filename = file.Find(folderpath.."0"..meshtype.."*.mdl","GAME")[1] end 
	-- if !filename then filename = file.Find(folderpath.."00"..meshtype.."*.mdl","GAME")[1] end 
	if filename then return folderpath..filename else return nil end 
end 

function ENT:InitModel() 
	-- local folderpath = "models/breed/" 
	-- local modelindex = self:GetKeyValues().skin 
	-- local filename = file.Find(folderpath..modelindex.."*")[1] 
	-- if filename then self:SetModel(filename) end 
	local filename = self:DecideModelName() 
	if filename then self:SetModel(filename) else MsgC(color_white,"Model index not found: "..BREED.Objects[self.ob_name].mesh .."\n") end 
end 

function ENT:InitModel() 
	local meshindex = BREED.Objects[self.ob_name].mesh 
	if meshindex == "0" or meshindex == "5" then self:SetModel("models/blackout.mdl") return end 
	if util.IsValidModel(meshindex) then self:SetModel(meshindex) else self:SetModel(error_model) end 
end 
--]] 

function ENT:Mercury_TranslateMeshIndex(meshindex) 
	if meshindex == 110 then return 142 end 
	return meshindex 
end 

function ENT:InitModel() 
	print("OBJECT NAME:", self.ob_name) 
	local meshindex = BREED.Objects[self.ob_name].mesh 
	if meshindex == "0" or meshindex == "5" then self:SetModel("models/blackout.mdl") return end 
	--[[ 
	local strindexcount = #meshindex 
	for i = 1, strindexcount do 
		if string.StartWith(meshindex,"0") then 
			meshindex = string.sub(meshindex,2) -- skip the zero at beginning 
		else 
			break 
		end 
	end 
	--]] 
	meshindex = GetProperIndex(meshindex) 
	-- meshindex = self:Mercury_TranslateMeshIndex(meshindex) 
	local modelname = BREED.Models[meshindex] 
	if !modelname then MsgC(color_white,"Removed entity with meshindex "..BREED.Objects[self.ob_name].mesh.."\n") SafeRemoveEntity(self) return end 
	local modelpath = Model("models/breed/"..BREED.Models[meshindex]) 
	self:SetModel(modelpath or "models/error.mdl") 
end 

function ENT:HasPhysics() 
	local mode = BREED.Objects[self.ob_name].mode 
	local col_type = BREED.Objects[self.ob_name].collision 
	return mode == "SPACE" or mode == "DRIVE" or mode == "WHEEL" or mode == "JET" or col_type == "POLY" or col_type == "BOX" or col_type == "SPHERE" 
end 

function ENT:Mercury_CanRotate() 
	local mode = BREED.Objects[self:GetOBName()].mode 
	return mode == "TURRET" or mode == "ROTATE" or mode == "JET" or mode == "ROTATE_THROTTLE" or mode == "WHEEL" or mode == "ROTATE_MANNED", mode 
end 

function ENT:InitSubob() 
	local subobtbl = BREED.Subob[self.ob_name] 
	if subobtbl and subobtbl[1] then 
		for i = 1, #subobtbl do 
			local fieldname = table.GetKeys(subobtbl[i])[1] -- will return HANGER for BREED.Subob.DROPSHIP.1 
			local parentent = ents.Create("basemercuryobject") 
			parentent.ob_name = fieldname 
			parentent:SetPos(self:LocalToWorld((subobtbl[i][fieldname].pos)*scalar))	-- nearly exact representation of local coordinates used in breed 
			parentent:SetAngles(self:LocalToWorldAngles(subobtbl[i][fieldname].ang))	
			parentent:SetKeyValue(keystring,fieldname) -- define object name 
			parentent:SetSubEnt(self) 
			if self:GetMoveType() != MOVETYPE_VPHYSICS then 
				parentent:SetParent(self) 
			end 
			
			
			if (self:HasPhysics() and !parentent:HasPhysics()) or !self:HasPhysics() and parentent:HasPhysics() then 
				parentent:SetParent(self) 
			end 
			
			local subent = self
			if IsValid(parentent:GetSubEnt()) and IsValid(parentent:GetSubEnt():GetOwner()) then subent = parentent:GetSubEnt():GetOwner() end 
			if subent then 
				parentent:SetOwner(subent) -- this will decide the main entity we are connected to. this will be DROPSHIP entity for every object that DROPSHIP has. 
			end 
			table.insert(self.tblsubents,parentent) 
			parentent:Spawn() 
			if BREED.Objects[parentent.ob_name].mode == "WHEEL" and BREED.WheelSettings[parentent.ob_name] then 
				local length = tonumber(BREED.WheelSettings[parentent.ob_name].travel)*-scalar 
				length = length 
				local suspension = ents.Create("prop_physics") 
				-- suspension:SetPos(parentent:GetPos()) 
				suspension:SetPos(parentent:GetPos()+(parentent:GetUp()*-(length))) 
				suspension:SetModel("models/blackout.mdl") 
				suspension:PhysicsInitBox(suspension:GetModelBounds()) 
				suspension:Spawn() 
				suspension:PhysicsInitBox(suspension:GetModelBounds()) 
				parentent:GetPhysicsObject():SetMass(self:GetPhysicsObject():GetMass()*10)
				suspension:GetPhysicsObject():SetMass(self:GetPhysicsObject():GetMass()*10)
				suspension:SetNotSolid(1) 
				suspension:SetCollisionGroup(COLLISION_GROUP_WORLD) 
				constraint.Weld(self,suspension,0,0,0,true,false) 
				constraint.Weld(self:GetOwner(),suspension,0,0,0,true,false) 
				parentent:SetPos(parentent:GetPos()+(parentent:GetUp()*-(length))) 
				-- constraint.Muscle(Entity(1),suspension,parentent,0,0,vector_origin,Vector(0,0,-(length*-scalar)),0,0,30,0,0,0,0,"cable/rope",color_white) 
				-- constraint.Hydraulic(Entity(1),suspension,parentent,0,0,vector_origin,Vector(0,0,-length),length,length,0,0,0,0,"cable/rope",color_white) 
				-- constraint.Slider(suspension,parentent,0,0,vector_origin,Vector(0,0,-length),30,"cable/rope",color_white) 
				-- constraint.Weld(suspension,parentent,0,0,0,true,false) 
				constraint.Axis(suspension,parentent,0,0,suspension:GetRight()*suspension:BoundingRadius(),parentent:GetRight()*parentent:BoundingRadius(),0,0,0,1)
			else 
				constraint.Weld(self,parentent,0,0,0,true,false) -- weld on physics objects 
			end 
		end 
	end 
end 

function ENT:GetCollisionMeshTxt() 
	if self.ob_name == "DROPSHIP" then return "142dpcollision.mdl.txt" end 
	local collision_mesh = BREED.Objects[self.ob_name].collision 
	local modelname = nil 
	--[[ 
	if collision_mesh != "0" then 
		collision_mesh = GetProperIndex(collision_mesh) 
		modelname = BREED.Models[collision_mesh] 
		if modelname then 
			modelname = modelname..".txt" 
		end 
	else 
	--]] 
		modelname = self:GetModel() 
		modelname = string.GetFileFromFilename(modelname)..".txt" 
	-- end 
	return modelname 
end 

function ENT:InitMoveType_MultiConvexVehicle() 
	MsgC(color_white,self.ob_name.." will be multiconvex physics vehicle.\n") 
	
	self.breed_collisionmesh = {} 
	self.breed_collisionmesh.verticies = { } 
	local model = self:GetModel() 
	for k,v in pairs(util.GetModelMeshes(model)) do 
		table.Add(self.breed_collisionmesh.verticies,v.verticies) 
	end 
	
	self:PhysicsFromMesh(self.breed_collisionmesh.verticies) 
	self:SetSolid(SOLID_VPHYSICS) 
	self:SetMoveType(MOVETYPE_VPHYSICS) 
	self:EnableCustomCollisions(true) 
	self:PhysWake() 
	return self:GetPhysicsObject() 
end 

--[[ 
function ENT:InitMoveType_MultiConvexVehicle() 
	MsgC(color_white,self.ob_name.." will be multiconvex physics vehicle.\n") 
	-- if BREED.Objects[self.ob_name].collision == "0" then 
		-- local modelname = BREED.Models[
	local txtfile = self:GetCollisionMeshTxt() 
	local tbltriangles = BREED and BREED.ModelMeshes and BREED.ModelMeshes[txtfile] -- ["110dropship.mdl.txt"] = vertices 
	if tbltriangles and !table.IsEmpty(tbltriangles) then 
		-- MsgC(color_white,self.ob_name.." using modelmesh "..tbltriangles .."\n") 
		self.breed_collisionmesh = {} 
		MsgC(color_white,"tbltriangles counts up to "..table.Count(tbltriangles).."\n") 
		for i = 1, table.Count(tbltriangles) do 
			local v3 = tbltriangles[i] 
			if collision_mesh_sets == 1 then 
				self.breed_collisionmesh[i] =	{ 
				v3,
				Vector(v3.x,v3.z,v3.y), 
				Vector(v3.z,v3.x,v3.y), 
				Vector(v3.z,v3.y,v3.x), 
				Vector(v3.y,v3.z,v3.x), 
				Vector(v3.y,v3.x,v3.z), 
				v3+Vector(0,0,1), 
				v3+Vector(0,0,-1)
												} 
			elseif collision_mesh_sets == 2 then 
				local test_mins = v3 
				local test_maxs = -v3 
				self.breed_collisionmesh[i] =	{ 
				test_mins,
				Vector(test_mins.x,test_mins.y,test_maxs.z), 
				Vector(test_mins.x,test_maxs.y,test_mins.z), 
				Vector(test_mins.x,test_maxs.y,test_maxs.z), 
				Vector(test_maxs.x,test_mins.y,test_mins.z), 
				Vector(test_mins.x,test_mins.y,test_maxs.z), 
				Vector(test_mins.x,test_maxs.y,test_mins.z), 
				test_maxs 
												} 
			elseif collision_mesh_sets == 3 then 
				print("using set 3") 
				local v3_2 = tbltriangles[i+1] 
				if !v3_2 then break end 
				local test_mins = v3 
				local test_maxs = v3_2 
				self.breed_collisionmesh[i] =	{ 
				test_mins,
				Vector(test_mins.x,test_mins.y,test_maxs.z), 
				Vector(test_mins.x,test_maxs.y,test_mins.z), 
				Vector(test_mins.x,test_maxs.y,test_maxs.z), 
				Vector(test_maxs.x,test_mins.y,test_mins.z), 
				Vector(test_mins.x,test_mins.y,test_maxs.z), 
				Vector(test_mins.x,test_maxs.y,test_mins.z), 
				test_maxs 
													} 
			end 
		end 
		self:PhysicsInitMultiConvex(self.breed_collisionmesh) 
		self:SetSolid(SOLID_VPHYSICS)	
		self:SetMoveType(MOVETYPE_VPHYSICS) 
		self:EnableCustomCollisions(true) 
		self:PhysWake() 
	else MsgC(color_white,"Physics object table is empty.\n") 
	end 
end 
--]] 

--[[ 
function ENT:InitMoveType_Static() 
	MsgC(color_white,self.ob_name.." will be physics from mesh entity.\n") 
	local txtfile = self:GetCollisionMeshTxt() 
	local tbltriangles = BREED and BREED.ModelMeshes and BREED.ModelMeshes[txtfile] -- ["110dropship.mdl.txt"] = vertices 
	if tbltriangles and !table.IsEmpty(tbltriangles) then 
		-- MsgC(color_white,self.ob_name.." using modelmesh "..tbltriangles .."\n") 
		MsgC(color_white,"tbltriangles counts up to "..table.Count(tbltriangles).."\n") 
		local VERTICES = {}	
		for k,v in pairs(tbltriangles) do 
			table.insert(VERTICES,{pos = Vector(v)}) 
		end 
		self:PhysicsFromMesh(VERTICES) 
		self:SetSolid(SOLID_VPHYSICS)	
		self:SetMoveType(MOVETYPE_VPHYSICS) 
		self:GetPhysicsObject():EnableMotion( false ) 
		self:GetPhysicsObject():SetMass(400000) 
		self:EnableCustomCollisions(true) 
	else MsgC(color_white,"Physics object table is empty.\n") 
	end 
end 
--]] 

function ENT:InitMoveType_Static() 
	MsgC(color_white,self.ob_name.." will be physics from mesh entity.\n") 
	
	self.breed_collisionmesh = {} 
	self.breed_collisionmesh.verticies = { } 
	for k,v in pairs(util.GetModelMeshes(self:GetModel())) do 
		table.Add(self.breed_collisionmesh.verticies,v.verticies) 
	end 
	
	self:PhysicsFromMesh(self.breed_collisionmesh.verticies) 
	self:SetSolid(SOLID_VPHYSICS)	
	self:SetMoveType(MOVETYPE_VPHYSICS) 
	self:EnableCustomCollisions(true) 
	local phys = self:GetPhysicsObject() 
	if phys:IsValid(phys) then 
		phys:EnableMotion(false) 
	end 
	self:PhysWake() 
	return phys 
end 

function ENT:InitMoveType() 
	-- if IsValid(self:GetOwner()) then return end 
	local mode = BREED.Objects[self.ob_name].mode 
	local col_type = BREED.Objects[self.ob_name].collision 
	if mode == "SPACE" or mode == "DRIVE" then 
		if col_type == "POLY" then 
			-- self:InitMoveType_MultiConvexVehicle() 
			self:InitMoveType_Static() 
		elseif col_type == "BOX" then 
			self:PhysicsInitBox(self:GetCollisionBounds())	
		elseif col_type == "SPHERE" then 
			self:PhysicsInitSphere(self:BoundingRadius()) 
		end 
	-- the rest: static, controller, mzl, mine, head, torso, weapon, weapon_dummy, wheel, jet, biped, space, rotate, rotate_throttle, rotate_manned, turret, door, drive, hover, fly 
	elseif mode == "WHEEL" then self:PhysicsInitSphere(self:BoundingRadius()) 
	elseif col_type == "POLY" then 
		if IsValid(self:InitMoveType_Static()) then self:GetPhysicsObject():EnableMotion(true) end 
	elseif col_type == "BOX" then 
		self:PhysicsInitBox(self:GetCollisionBounds())	
		self:GetPhysicsObject():EnableMotion( false ) 
	elseif col_type == "SPHERE" then 
		self:PhysicsInitSphere(self:BoundingRadius()) 
		self:GetPhysicsObject():EnableMotion( false ) 
	elseif mode == "JET" then 
		self:PhysicsInitBox(self:GetCollisionBounds()) 
	
	else 
		print("OBJECT",self,self.ob_name,"MOVETYPE IS:", col_type) 
		self:SetSolid(SOLID_NONE) 
		self:SetMoveType(MOVETYPE_NONE) 
	end 
	local phys = self:GetPhysicsObject() 
	if phys and IsValid(phys) then 
		local mass = tonumber(BREED.Objects[self.ob_name].mass_kg) 
		mass = (mass and mass > 1 and mass) or BREED.Objects[self.ob_name].thrust_kg 
		-- if mode == "WHEEL" then mass = 5000 end 
		-- if mode != "WHEEL" then phys:SetMass(mass) end 
	end 
end 

function ENT:OnTakeDamage(dmginfo) 
	local m_takedamage = self:GetInternalVariable("m_takedamage") 
	if m_takedamage == 0 then return 0 end 
	if m_takedamage == 2 then 
		self:SetHealth(self:Health() - dmginfo:GetDamage()) 
	end 
	if self:Health() < 0 then 
		self:OnKilled(dmginfo) 
	end 
	return dmginfo:GetDamage() 
end 

function ENT:OnKilled() 
	local newmesh = BREED.DamageMeshSettings[self:GetOBName()] 
	if !newmesh then return end 
	newmesh = GetProperIndex(newmesh) 
	local modelname = BREED.Models[newmesh] 
	local modelpath = Model("models/breed/"..BREED.Models[newmesh]) 
	self:SetModel(modelpath) 
end 

function ENT:DrawLights() 
	local light = BREED and BREED.LightSettings and BREED.LightSettings[self:GetOBName()] -- returns you table of all lights of particular object 
	if light then 
		for i = 1,table.Count(light) do  
			local mat = Material( "sprites/blueflare1" ) 
			-- mat:SetInt("$spriterendermode", 5) 
			render.SetMaterial( mat ) -- add material option 
			render.DrawSprite(self:LocalToWorld((light[i].pos)*scalar),light[i].rad,light[i].rad,light[i].color) 
		end 
	end 
end 

function ENT:DrawSprites() -- same as lights 
	local sprite = BREED and BREED.SpriteSettings and BREED.SpriteSettings[self:GetOBName()] 
	-- if sprite then print(sprite) end 
	if sprite then 
		for i = 1,table.Count(sprite) do 
			local mat = Material("models/breed/"..BREED.Materials[sprite[i].texindex]) 
			mat:SetInt("$spriterendermode", 5) 
			render.SetMaterial( mat ) -- add material option 
			-- print("sprite at",self:LocalToWorld(sprite[i].pos)*0.35)
			render.DrawSprite(self:LocalToWorld((sprite[i].pos)*scalar),sprite[i].rad*-scalar,sprite[i].rad*-scalar,sprite[i].color) 
		end 
	end 
end 

function ENT:DrawEmitters() 
	local emitter = BREED and BREED.EmitterSettings and BREED.EmitterSettings[self:GetOBName()] 
	if emitter and FrameTime() > 0 and (!self.Mercury_flLastEmit or self.Mercury_flLastEmit and self.Mercury_flLastEmit < CurTime()) then 
		for i = 1,table.Count(emitter) do
			self.Mercury_flLastEmit = CurTime() + emitter[i].probabl -- fix probabl 
			local pos = self:LocalToWorld(emitter[i].position*scalar) 
			local radius = emitter[i].radius 
			local emit = ParticleEmitter(pos) 
			local texture = "models/breed/"..BREED.Materials[emitter[i].texture] 
			texture = string.sub(texture,1,#texture-4) 
			texture = Material(texture) 
				texture:SetInt("$spriterendermode",5) 
				local emitted = emit:Add(texture,pos) 
				if emitted then 
					local velocity = emitter[i].velocity*-10 
					local scalar = scalar 
					if BREED.Objects[self:GetOBName()].mode == "JET" then 
						scalar = scalar * (self:GetThrustRate()*0.01) 
					end 
					velocity = velocity * (self:GetThrustRate()*0.01) 
					velocity:Rotate(self:GetAngles()) 
					
					emitted:SetDieTime(emitter[i].life) 
					emitted:SetStartSize(radius*-scalar) 
					emitted:SetEndSize((radius*0.9)*-scalar) 
					local r,g,b = math.random(emitter[i].col1.r,emitter[i].col2.r), math.random(emitter[i].col1.g,emitter[i].col2.g), math.random(emitter[i].col1.b,emitter[i].col2.b) 
					emitted:SetColor(r,g,b) 
					emitted:SetVelocity(velocity) 
				end 
			emit:Finish() 
		end
	end 
end 

function ENT:DrawEnterIcon() 
	local range = 256 
	local canEnter = BREED.PilotSettings[self:GetOBName()] -- check whether the pilot table exists 
	if canEnter then 
		local enterPos = canEnter.pos*scalar 
		enterPos = self:LocalToWorld(enterPos) 
		local distToSeat = LocalPlayer():EyePos():Distance(enterPos) 
		if distToSeat < range then 
		cam.Start2D() 
			local actionIcons = Material("models/breed/903actions_HQ_NOMIP_") 
			actionIcons = surface.GetTextureID("models/breed/903actions_HQ_NOMIP_") 
			surface.SetTexture(actionIcons) 
			surface.SetDrawColor(255, 255, 255, 255) 
			surface.DrawTexturedRectUV(ScrW()*0.40,ScrH()*0.7,256,256,0,0,0.25,0.25) 
		cam.End2D() 
		end 
		-- print(distToSeat) 
	end 
end 

function ENT:Draw() 
	self:DrawModel() 
	self:DrawLights() 
	self:DrawSprites() 
	self:DrawEmitters() 
	self:DrawEnterIcon() 
end 

function ENT:Mercury_RotateThink() 
	if CLIENT then return end 
	local obmode = BREED.Objects[self:GetOBName()].mode 
	local physobj = self:GetPhysicsObject():IsValid() and self:GetPhysicsObject() 
	local inputsettings = BREED.InputSettings[self:GetOBName()] 
	if (obmode == "ROTATE" or obmode == "ROTATE_THROTTLE" or obmode == "ROTATE_MANNED" or obmode == "TURRET") and inputsettings then 
		for rotMethod, rotTbl in pairs(inputsettings) do -- "ANLG_LR" = "Y" 
			for rotAxis, rotAxisTbl in pairs(rotTbl) do -- "Y" = { -30, 30, 1200 } 
				local curAngles = self:GetLocalAngles() 
				if physobj then 
					if IsValid(self:GetSubEnt()) then 
						_,curAngles = WorldToLocal(vector_origin,self:GetSubEnt():GetAngles(),vector_origin,physobj:GetAngles()) 
					else 
						_,curAngles = WorldToLocal(vector_origin,self.Mercury_angSpawnAngles,vector_origin,physobj:GetAngles()) 
					end 
				end 
				-- local axis = (rotAxis == "X" and Vector(0,1,0)) or (rotAxis == "Y" and Vector(0,0,1)) or rotAxis == "Z" and Vector(1,0,0) 
				local axis = (rotAxis == "X" and Vector(0,1,0)) or (rotAxis == "Y" and Vector(0,0,1)) or rotAxis == "Z" and Vector(1,0,0) 
				local maxrotspeed = rotAxisTbl["rate"] 
				maxrotspeed = maxrotspeed * 0.1 
				if self.Mercury_bRotationBounce == true then axis = -axis end 
				curAngles:RotateAroundAxis(axis,maxrotspeed*FrameTime()) 
				
				if physobj then 
					if IsValid(self:GetSubEnt()) then 
						_,curAngles = LocalToWorld(vector_origin,curAngles,vector_origin,self:GetSubEnt():GetAngles()) 
					else 
						_,curAngles = LocalToWorld(vector_origin,curAngles,vector_origin,self.Mercury_angSpawnAngles) 
					end 
					physobj:SetAngles(curAngles) 
				else 
					self:SetLocalAngles(curAngles) 
				end 
				-- rotAxis = (rotAxis == "X" and "y") or (rotAxis == "Y" and "z") or rotAxis == "Z" and "x" 
				-- rotAxis = (rotAxis == "X" and "x") or (rotAxis == "Y" and "y") or rotAxis == "Z" and "z" 
				rotAxis = string.lower(rotAxis) 
				-- print("object", self:GetOBName(), curAngles[rotAxis]) 
				if rotAxisTbl["minrot"] != "X" and curAngles[rotAxis] < -tonumber(rotAxisTbl["minrot"]) then 
					self.Mercury_bRotationBounce = false 
				end 
				
				if rotAxisTbl["maxrot"] != "X" and curAngles[rotAxis] > -tonumber(rotAxisTbl["maxrot"]) then 
					self.Mercury_bRotationBounce = true 
				end 
				
			end 
		end 
	end 
end 

function ENT:Think() 

	if BREED.PilotSettings[self:GetOBName()] then 
		local pos = BREED.PilotSettings[self:GetOBName()].pos*scalar 
		local ejectpos = BREED.PilotSettings[self:GetOBName()].ejectpos 
		pos = self:LocalToWorld(pos) 
		ejectpos = self:LocalToWorld(ejectpos) 
		-- debugoverlay.Axis(pos,self:GetAngles(),20,0.15) 
		-- debugoverlay.Axis(ejectpos,self:GetAngles(),20,0.15) 
		-- debugoverlay.Text(pos,"pos",0.15) 
		-- debugoverlay.Text(ejectpos,"ejectpos",0.15) 
		
		if IsValid(self.Mercury_entSeat) then 
			local driver = self.Mercury_entSeat:GetDriver() 
			if IsValid(driver) then 
				if driver:KeyDown(IN_FORWARD) and self:GetThrustRate() < 100 then 
					self:SetThrustRate(self:GetThrustRate()+0.5)
				end 
				
				if driver:KeyDown(IN_BACK) and self:GetThrustRate() > -100 then 
					self:SetThrustRate(self:GetThrustRate()-0.5) 
				end 
				print("THROTTLE:",self:GetThrustRate()) 
			end 
		end 
		
	end 
	
	if BREED.Objects[self:GetOBName()].mode == "JET" then -- i am a jet 
		local engineThrust = self:GetThrustRate() -- parented to an aircraft 
		local targetThrust = IsValid(self:GetOwner()) and self:GetOwner():GetThrustRate() or engineThrust 
		local increment = math.Approach(engineThrust,targetThrust,0.5) 
		self:SetThrustRate(increment) 
		local thrustForce = BREED.Objects[self:GetOBName()].thrust_kg 
		thrustForce = thrustForce * (self:GetThrustRate()*0.01) 
		if self.SetForce then self:SetForce(thrustForce,self:Mercury_GetForceMultiplier()) end 
	elseif BREED.Objects[self:GetOBName()].mode == "WHEEL" and self:GetPhysicsObject():IsValid() and IsValid(self:GetOwner()) then 
		local maxvel = BREED.Objects[self:GetOwner():GetOBName()].maxvel 
		-- Make the wheel spin
		local impulse = Vector(0,0,1) -- Direction of the impulse force 
		local force = maxvel*self:GetOwner():GetThrustRate() -- Magnitude of the force 
		local position = self:GetPhysicsObject():GetPos() -- Position to apply the force 
		local torque,torquelocal = self:GetPhysicsObject():CalculateForceOffset(impulse * force, position) 
		self:GetPhysicsObject():ApplyTorqueCenter(torquelocal) 
		print("applied torque to",self,"impulse:",impulse,"force:",force,"position:",position,torque,torquelocal) 
	end 
	
	if self:Mercury_CanRotate() then 
		self:Mercury_RotateThink() 
	end 

	-- sound scripts 
	local hasSound = BREED.ObjectSounds[self:GetOBName()] 
	hasSound = hasSound and hasSound.lpsnd 
	local obtype = BREED.Objects[self:GetOBName()].mode 
	if hasSound and hasSound != 0 and BREED.Sounds[hasSound] and !self.LoopSound then 
		self.LoopSound = CreateSound(self,"BREED."..hasSound) 
		if obtype == "STATIC" or obtype == "SPACE" or obtype == "DRIVE" or obtype == "JET" then 
			self.LoopSound:Play() 
		end 
	end 
	
	if self.LoopSound and self.LoopSound:IsPlaying() then 
		local pitch, volume = BREED.ObjectSounds[self:GetOBName()].pitch, BREED.ObjectSounds[self:GetOBName()].volume 
		local pitch_mode = BREED.ObjectSounds[self:GetOBName()].pitch_mode 
		local pitch_min = BREED.ObjectSounds[self:GetOBName()].pitch_min 
		local pitch_max = BREED.ObjectSounds[self:GetOBName()].pitch_max
		local volume_mode = BREED.ObjectSounds[self:GetOBName()].volume_mode 
		local volume_min = BREED.ObjectSounds[self:GetOBName()].volume_min 
		local volume_max = BREED.ObjectSounds[self:GetOBName()].volume_max 
		
		local maxvel = BREED.Objects[self:GetOBName()].maxvel 
		local thrust_kg = BREED.Objects[self:GetOBName()].thrust_kg 
		
		if (obtype == "SPACE" or obtype == "DRIVE") then 
			if pitch_mode == "VELOCITY" then 
				-- set pitch depending on object velocity 
				-- todo: move to clientside and add doppler 
				local curvel = self:GetVelocity() 
				if self:GetPhysicsObject():IsValid() then curvel = self:GetPhysicsObject():GetVelocity() end 
				curvel = curvel:Length() 
				curvel = curvel/maxvel 
				pitch = math.Remap(curvel,0,100,pitch_min,pitch_max) 
				self.LoopSound:ChangePitch(pitch) 
			end 
			
			-- set volume depending on velocity 
			
		elseif obtype == "JET" then 
			if pitch_mode == "THROTTLE" then 
				local curvel = self:GetThrustRate() 
				pitch = math.Remap(curvel,0,100,pitch_min,pitch_max) 
				self.LoopSound:ChangePitch(pitch) 
			end 
			
		end 
	end 
	self:NextThink(CurTime()+0.01) 
	return true 
	
end 

function ENT:PhysicsSimulate( phys, deltatime )
	if BREED.Objects[self:GetOBName()].mode != "JET" then return SIM_NOTHING end

	return self.ForceAngle, self.ForceLinear, SIM_LOCAL_ACCELERATION
end

function ENT:OnRemove() 
	if self.LoopSound then self.LoopSound:Stop() self.LoopSound = nil end 
end 
