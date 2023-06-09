AddCSLuaFile() 

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

-- GetProperIndex 
-- Purpose: This function is used to remove leading zeros from a string. 
-- Inputs: A string (str). 
-- Outputs: A modified string (newstr) with leading zeros removed. 

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
	self:SetUseType(SIMPLE_USE) 
	self:InitMoveType() 
	-- then start welding 
	self:InitSubob() 
	
	if !IsValid(self:GetOwner()) and self:GetPhysicsObject():IsValid() and BREED.Objects[self:GetOBName()].mode == "STATIC" then -- base entity without movement, lock movement for optimization 
		self:GetPhysicsObject():EnableMotion(false) 
	end 
	
	self.Mercury_angSpawnAngles = self:GetLocalAngles() 
	self.Mercury_bRotationBounce = false 
	self.Mercury_iNextMuzzle = 1 
	self:StartMotionController() 
	local max = self:OBBMaxs() 
	local min = self:OBBMins() 
	
	if BREED.Objects[self:GetOBName()].mode == "JET" then 
		-- self.ThrustOffset = Vector( 0, 0, max.z ) 
		self.ThrustOffset = Vector( max.x, 0, 0 ) 
		-- self.ThrustOffsetR = Vector( 0, 0, min.z ) 
		self.ThrustOffsetR = Vector( min.x, 0, 0 ) 
		self.ForceAngle = self.ThrustOffset:GetNormalized() * -1 
		self:SetOffset( self.ThrustOffset ) 
		
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
	self:NetworkVar("Angle",0,"RotationAngle") 
	self:NetworkVar("String",0,"OBName",{"KeyName","object"}) -- Allows the NetworkVar to be set using Entity:SetKeyValue. 
	self:NetworkVar("String",1,"SubMode") 
	self:NetworkVar("Entity",0,"SubEnt") -- rename to BranchEnt 
	self:NetworkVar("Entity",1,"ControllerSeat") 
	self:NetworkVar("Float",0,"ThrustRate") 
	self:NetworkVar("Vector",0,"Offset") -- for thruster 
end 

function ENT:InitializeSeat() 
	local pos = BREED.PilotSettings[self:GetOBName()].pos*scalar 
	pos = self:LocalToWorld(pos) 
	local pod = ents.Create("prop_vehicle_prisoner_pod") 
	if !IsValid(pod) then return end 
	pod:SetPos(pos) 
	pod:SetAngles(self:GetAngles()-Angle(0,180,0)) 
	pod:SetParent(self) 
	pod:SetModel("models/weapons/ar2_grenade.mdl") 
	pod:SetRenderMode(1) 
	pod:SetSolid(SOLID_NONE) 
	pod:SetMoveType(MOVETYPE_NONE) 
	pod:SetColor(Color(0,0,0,1)) 
	pod:SetKeyValue("vehiclescript","scripts/vehicles/prisoner_pod.txt") 
	pod:SetKeyValue("limitview",0) 
	pod:Spawn() 
	pod:Activate() 
	pod:SetMoveType(MOVETYPE_NONE) 
	pod:SetNotSolid(1) 
	self:SetControllerSeat(pod) 
	pod:SetNW2Entity("Mercury_entParent",self) 
	local viewEntity = self:Mercury_FindViewPointEnt() 
	MsgC(color_white,"viewEntity is: "..tostring(viewEntity).." ".. viewEntity:GetOBName().." \n") 
	-- if IsValid(viewEntity) then driver:SetViewEntity(viewEntity) end 
	pod:SetNW2Entity("Mercury_entView",viewEntity) 
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

function ENT:Mercury_TranslateMeshIndex(meshindex) -- translates the mesh index to a collision mesh index replacement 
	-- if meshindex == 110 then return 142 end 
	meshindex = BREED.CollisionMeshes[meshindex] or meshindex -- return the same mesh if we don't have any appropriate replacement 
	return meshindex 
end 

function ENT:Mercury_GetRandomVertex() 
	local mesh = BREED.GetModelMeshes(self:GetModel()) 
	for _,submodel in RandomPairs(mesh) do 
		for _,vertex in RandomPairs(submodel.verticies) do 
			return vertex.pos 
		end 
	end 
end 

function ENT:Mercury_CheckEntityConvexity(entity) 
	if !IsValid(entity) then entity = self end 
    local physObj = entity:GetPhysicsObject() 
    if !physObj:IsValid() then return end 
    
    local convexes = physObj:GetMeshConvexes() 
    for _, convex in ipairs(convexes) do 
        for i = 1, #convex do 
            if i % 3 == 1 then 
                local v1, v2, v3 = convex[i].pos, convex[i+1].pos, convex[i+2].pos 
                local crossProduct = (v2 - v1):Cross(v3 - v1) 
                for j = 1, #convex do 
                    if j != i and j != i+1 and j != i+2 then 
                        local vertex = convex[j].pos 
						-- print(vertex) 
						-- print((vertex - v1):Dot(crossProduct)) 
                        if (vertex - v1):Dot(crossProduct) > 0 then 
                            return false -- a concave vertex was found 
                        end 
                    end 
                end 
            end 
        end 
    end 
    
    return true -- all convex meshes are valid 
end 

local function rescaleVertices(vertices) -- fixed to rescale bounding radius to 1 
    -- Find the bounding box of the vertices
    local minPos = Vector(0, 0, 0)
    local maxPos = Vector(0, 0, 0)
    for _, vertex in ipairs(vertices) do
        if vertex.x < minPos.x then minPos.x = vertex.x end
        if vertex.y < minPos.y then minPos.y = vertex.y end
        if vertex.z < minPos.z then minPos.z = vertex.z end
        if vertex.x > maxPos.x then maxPos.x = vertex.x end
        if vertex.y > maxPos.y then maxPos.y = vertex.y end
        if vertex.z > maxPos.z then maxPos.z = vertex.z end
    end

    -- Calculate the center of the bounding box
    local centerPos = (minPos + maxPos) / 2

    -- Calculate the distance from the center to the furthest vertex
    local maxDistance = 0
    for _, vertex in ipairs(vertices) do
        local distance = (vertex - centerPos):Length()
        if distance > maxDistance then maxDistance = distance end
    end

    -- Rescale the vertices
    local scale = 1 / maxDistance
    for _, vertex in ipairs(vertices) do
        vertex = (vertex - centerPos) * scale
    end

    -- Return the new, scaled table of vertices
    return vertices
end


function ENT:Mercury_InitWheelPhysics(ent) 
	ent = IsValid(ent) and ent or self 
    -- Get the reference physics mesh 
    local referencePhys = BREED.GetModelMeshes("models/props_vehicles/carparts_wheel01a.mdl")[1]["verticies"] 
    
    -- Get the vertices from the reference physics mesh
    local vertices = {} 
    for k, v in pairs(referencePhys) do 
        table.insert(vertices, v.pos) 
    end 
    
    -- Get the bounding radius of the input entity
    local boundingRadius = ent:BoundingRadius() 
	print("boundingRadius:",boundingRadius) 
    
    -- Define the scaling factor
    local scaleFactor = boundingRadius / 20 
	
	vertices = rescaleVertices(vertices) -- scales bounding radius to 1 
    
    -- Rescale the vertices in the table 
    for k, v in pairs(vertices) do 
        vertices[k] = v * scaleFactor 
    end 
    
    -- Apply the new physics mesh to the input entity 
	ent:PhysicsInitConvex(vertices) 
    local physObj = ent:GetPhysicsObject() 
    if IsValid(physObj) then 
        -- physObj:EnableMotion(false) 
        -- physObj:SetMaterial("metal") 
        -- physObj:SetMass(1000) 
        -- physObj:SetMesh(vertices) 
        physObj:EnableMotion(true) 
        ent:SetSolid(SOLID_BBOX) 
        ent:SetMoveType(MOVETYPE_VPHYSICS) 
    end 
end 


function ENT:Mercury_FindParentEntity(mode) 
	local resultEnt = NULL 
	local parent = self:GetSubEnt() -- means get our branch 
	if IsValid(parent) then 
		MsgC(color_white,"checking "..tostring(parent).. " "..parent:GetOBName().."\n") 
		local parentSub = parent:GetSubMode() 
		if parentSub != mode then 
			resultEnt = parent:Mercury_FindParentEntity(mode) 
		else 
			resultEnt = parent 
		end 
	end 
	if IsValid(resultEnt) then 
		return resultEnt, resultEnt:GetOBName() 
	end 
end 

-- ENT.InitModel 
-- Purpose: Properly assign a model to a Mercury object. 
-- Input: - 
-- Output: - 
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
	local modelname = BREED.Models[meshindex] 
	if !modelname then MsgC(color_white,"Removed entity with meshindex "..BREED.Objects[self.ob_name].mesh.."\n") SafeRemoveEntity(self) return end 
	local modelpath = Model("models/breed/"..BREED.Models[meshindex]) 
	self:SetModel(modelpath or "models/error.mdl") 
end 

function ENT:Mercury_HasPhysics() 
	local mode = BREED.Objects[self.ob_name].mode 
	local col_type = BREED.Objects[self.ob_name].collision 
	return mode == "SPACE" or mode == "DRIVE" or mode == "WHEEL" or mode == "JET" or col_type == "POLY" or col_type == "BOX" or col_type == "SPHERE" 
end 

function ENT:Mercury_CanRotate() 
	local mode = BREED.Objects[self:GetOBName()].mode 
	return mode == "TURRET" or mode == "ROTATE" or mode == "JET" or mode == "ROTATE_THROTTLE" or mode == "WHEEL" or mode == "ROTATE_MANNED", mode 
end 

-- ENT.Mercury_FixInputLimit 
-- Purpose: Replaces "X" from InputSettings with 180 degrees  
-- Input: 'inputdata' - a table containing the limit values for an entity's rotation. 
-- Output: 'newdata' - a table containing the corrected limit values for the entity's rotation. If 'inputdata' is nil, the function returns nil 

function ENT:Mercury_FixInputLimit(inputdata) 
	if !inputdata then return nil end 
	local newdata = table.Copy(inputdata) 
	if newdata.minrot == "X" then newdata.minrot = 180 end 
	if newdata.maxrot == "X" then newdata.maxrot = -180 end 
	
	-- inverse mins and maxs 
	return newdata 
end 

-- ENT.Mercury_CalculateMass 
-- Purpose: Calculate the mass of an entity in the game. 
-- Input: - 
-- Output: A numerical value representing the mass of the entity. 

function ENT:Mercury_CalculateMass() 
	local mass = tonumber(BREED.Objects[self:GetOBName()].mass_kg) 
	if mass < 2 then mass = tonumber(BREED.Objects[self:GetOBName()].thrust_kg) end 
	if mass < 2 then mass = self:BoundingRadius() end 
	return mass 
end 

-- ENT.Mercury_InitAxisMove 
-- Purpose: This function initializes an axis movement constraint between two entities in the game world.
-- Input: The inputs to this function are the axis to move on, axis data, the parent entity, and the joint. 
-- Output: - 

function ENT:Mercury_InitAxisMove(axis,axisdata,parentent,joint) 
	local self = IsValid(joint) and joint or self 
	-- local bone1, bone2, LPos1, LPos2, forcelimit, torquelimit, xmin, ymin, zmin, xmax, ymax, zmax, xfric, yfric, zfric, onlyrotation, nocollide = 0, 0, vector_origin, vector_origin, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 
	--[[ 
	local joint = ents.Create("prop_physics") 
	if IsValid(joint) then 
		joint:SetModel("models/blackout.mdl") 
		joint:SetPos(parentent:GetPos()) 
		joint:PhysicsInitSphere(joint:BoundingRadius()) 
		joint:SetSolid(SOLID_NONE) 
		joint:SetNotSolid(1) 
		joint:Spawn() 
		joint:GetPhysicsObject():SetMass(self:GetPhysicsObject():GetMass()*10) 
		joint:GetPhysicsObject():EnableGravity(0) 
		joint:SetNotSolid(1) 
		joint:SetCollisionGroup(COLLISION_GROUP_WORLD) 
		parentent.Mercury_entJoint = joint 
		constraint.Weld(self,joint,0,0,0,true,false) 
		constraint.NoCollide(self,joint,0,0) 
		end 
		--]] 
	local LPos1 = self:WorldToLocal(parentent:GetPos()) 
	LPos1 = !IsValid(joint) and LPos1 or vector_origin 
	local LPos2 = Vector(0,0,0) 
	if axis == "X" then 
	--[[ 
		-- constraint.Axis(joint,parentent,0,0,joint:GetUp()*joint:BoundingRadius(),parentent:GetUp()*parentent:BoundingRadius(),0,0,0,1) 
		local LPos1 = Vector(0,parentent:BoundingRadius(),0) 
		local LPos2 = -LPos1 
		-- print("lpos2:",LPos2) 
		-- print("distance:",self:GetPos():Distance(parentent:GetPos())) 
		-- local LPos2 = Vector(0,1,0) 
		constraint.Axis(self,parentent,0,0,LPos1,LPos2,0,0,0,1) 
		-- constraint.Weld(joint,parentent,0,0,0,true,false) -- weld on physics objects 
		print(parentent:GetOBName(),"used x") -- RD-MISSILEPOD-Y	used x rocket shooter 
	--]] 
		print(parentent,parentent:GetOBName(),"using x axis move up and down") 
		LPos2 = Vector(0,1,0) 
	end 
	
	if axis == "Y" then 
		-- constraint.Axis(joint,parentent,0,0,joint:GetForward()*joint:BoundingRadius(),parentent:GetForward()*parentent:BoundingRadius(),0,0,0,1) 
		-- local LPos1 = self:GetPos()-parentent:GetPos() 
		-- print(self:OBBMins(),self:OBBMaxs(),self:OBBCenter()) 
		-- local LPos1 = self:OBBCenter() 
		-- local LPos2 = parentent:GetPos()-self:GetPos() 
		-- local hingePoint = self:WorldToLocal(parentent:GetPos()) 
		-- local LPos2 = (hingePoint - parentent:OBBCenter()) 
		-- local dist = self:GetPos():Distance(parentent:GetPos()) 
		-- LPos1 = hingePoint 
		LPos2 = Vector(0,0,1) 
		-- print("lpos1:",LPos1) 
		-- print("lpos2:",LPos2) 
		-- print("distance:",dist) 
		-- local LPos2 = Vector(0,1,0) 
		-- constraint.Axis(self,parentent,0,0,LPos1,LPos2,0,0,0,1) 
		-- constraint.Weld(joint,parentent,0,0,0,true,false) -- weld on physics objects 
		print(parentent,parentent:GetOBName(),"using y axis move left and right") 

	end 
	
	if axis == "Z" then 
		LPos2 = Vector(1,0,0) 
	end 
	constraint.Axis(self,parentent,0,0,LPos1,LPos2,0,0,0,1) 
	
end 

-- ENT.Mercury_CalculateSuspensionPos 
-- Purpose: Calculates suspension position used by Mercury wheels 
-- Input: 1- Entity: Wheel or joint. 2- Length: Length data from WheelSettings. 
-- Output: Global Vector 
function ENT:Mercury_CalculateSuspensionPos(parentent,length) 
	return parentent:GetPos()+(parentent:GetUp()*-(length))
end 

-- ENT.Mercury_InitWheelAxis 
-- Purpose: Initializes a wheel axis on a suspension point, for a Garry's Mod entity.
-- Input: parentent (Entity), joint (optional entity)
-- Output: - 

function ENT:Mercury_InitWheelAxis(parentent,joint) 
	local self = IsValid(joint) and joint or self 
	local length = tonumber(BREED.WheelSettings[parentent.ob_name].travel)*-scalar 
	local suspension = ents.Create("prop_physics") 
	-- suspension:SetPos(parentent:GetPos()) 
	suspension:SetPos(parentent:GetPos()+(parentent:GetUp()*-(length))) 
	suspension:SetModel("models/blackout.mdl") 
	suspension:PhysicsInitBox(suspension:GetModelBounds()) 
	parentent.Mercury_entSuspension = suspension 
	suspension:Spawn() 
	suspension:Activate() 
	suspension:PhysicsInitBox(suspension:GetModelBounds()) 
	local phys = self:GetPhysicsObject():IsValid() and self:GetPhysicsObject() 
	-- parentent:GetPhysicsObject():SetMass(self:GetPhysicsObject():GetMass()*10) 
	-- if phys then suspension:GetPhysicsObject():SetMass(self:GetPhysicsObject():GetMass()) end 
	suspension:SetNotSolid(1) 
	suspension:SetCollisionGroup(COLLISION_GROUP_WORLD) 
	constraint.Weld(self,suspension,0,0,0,true,false) 
	if IsValid(self:GetOwner()) then constraint.Weld(self:GetOwner(),suspension,0,0,0,true,false) end 
	-- parentent:SetPos(parentent:GetPos()+(parentent:GetUp()*-(length))) 
	parentent:SetPos(suspension:GetPos()+(suspension:GetUp()*-(length))) 
	-- constraint.Muscle(Entity(1),suspension,parentent,0,0,vector_origin,Vector(0,0,-(length*-scalar)),0,0,30,0,0,0,0,"cable/rope",color_white) 
	-- constraint.Hydraulic(Entity(1),suspension,parentent,0,0,vector_origin,Vector(0,0,-length),length,length,0,0,0,0,"cable/rope",color_white) 
	-- constraint.Slider(suspension,parentent,0,0,vector_origin,Vector(0,0,-length),30,"cable/rope",color_white) 
	-- constraint.Weld(suspension,parentent,0,0,0,true,false) 
	-- constraint.Axis(suspension,parentent,0,0,suspension:GetRight()*suspension:BoundingRadius(),parentent:GetRight()*parentent:BoundingRadius(),0,0,0,1) 
	local LPos1 = suspension:WorldToLocal(parentent:GetPos()) 
	local LPos2 = Vector(0,1,0) 
	if BREED.WheelSettings[parentent:GetOBName()] and tonumber(BREED.WheelSettings[parentent:GetOBName()].rotate) > 0 then 
		constraint.Axis(suspension,parentent,0,0,LPos1,LPos2,0,0,0,1) 
	else 
		constraint.Weld(suspension,parentent,0,0,0,true,true) 
	end 
end 

-- ENT.Mercury_BaseInitPhysRotation
-- Purpose: This function initializes the physics rotation of an entity based on its properties and settings.
-- Input: 
-- 1- parentent: the parent entity that is going to be rotated. 
-- 2- joint (optional): the joint entity that connects the parent entity to another entity.
-- Output: - 

function ENT:Mercury_BaseInitPhysRotation(parentent,joint) 
	if BREED.Objects[parentent.ob_name].mode == "WHEEL" and BREED.WheelSettings[parentent.ob_name] then 
		self:Mercury_InitWheelAxis(parentent,joint) 
	elseif parentent:Mercury_CanRotate() and parentent:Mercury_HasPhysics() and BREED.InputSettings[parentent.ob_name] then 
		-- get turn axes 
		local X,Y,Z 
		for rotMethod, rotTbl in pairs(BREED.InputSettings[parentent.ob_name]) do -- "ANLG_LR" = {"Y", "Z"}	
			for rotAxis, rotAxisTbl in pairs(rotTbl) do -- "Y" = { -30, 30, 1200 } 
				X = rotAxis == "X" and rotAxisTbl or nil 
				Y = rotAxis == "Y" and rotAxisTbl or nil 
				Z = rotAxis == "Z" and rotAxisTbl or nil 
			end 
		end 
				
		X = self:Mercury_FixInputLimit(X) 
		Y = self:Mercury_FixInputLimit(Y) 
		Z = self:Mercury_FixInputLimit(Z) 
		if X and !Y and !Z then 
			self:Mercury_InitAxisMove("X",X,parentent,joint) 
		elseif !X and Y and !Z then 
			self:Mercury_InitAxisMove("Y",Y,parentent,joint) 
		elseif !X and !Y and Z then 
			self:Mercury_InitAxisMove("Z",Z,parentent,joint) 
					
		elseif X and Y and Z then 
				--[[ 
					local bone1, bone2, LPos1, LPos2, forcelimit, torquelimit, xmin, ymin, zmin, xmax, ymax, zmax, xfric, yfric, zfric, onlyrotation, nocollide = 0, 0, vector_origin, parentent:GetUp()+parentent:GetForward()+parentent:GetRight(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 
					if X then 
						print(parentent, "will use X") 
						xmin = -tonumber(X.minrot) 
						xmax = -tonumber(X.maxrot) 
					end 
					if Y then 
						print(parentent, "will use Y") 
						ymin = -tonumber(Y.minrot) 
						ymax = -tonumber(Y.maxrot) 
					end 
					if Z then 
						print(parentent, "will use Z") 
						zmin = -tonumber(Z.minrot) 
						zmax = -tonumber(Z.maxrot) 
					end 
					local joint = ents.Create("prop_physics") 
					if IsValid(joint) then 
						joint:SetModel("models/blackout.mdl") 
						joint:SetPos(parentent:GetPos()) 
						joint:PhysicsInitSphere(joint:BoundingRadius()) 
						joint:SetSolid(SOLID_NONE) 
						joint:SetNotSolid(1) 
						joint:Spawn() 
						joint:GetPhysicsObject():SetMass(self:GetPhysicsObject():GetMass()*10) 
						joint:SetNotSolid(1) 
						joint:SetCollisionGroup(COLLISION_GROUP_WORLD) 
						parentent.Mercury_entJoint = joint 
						constraint.Weld(self,joint,0,0,0,true,false) 
						constraint.NoCollide(self,joint,0,0) 
					end 
					constraint.AdvBallsocket(joint,parentent,bone1,bone2,LPos1,LPos2,forcelimit,torquelimit,xmin,ymin,zmin,xmax,ymax,zmax,xfric,yfric,zfric,onlyrotation,nocollide) 
					--]] 
			print(parentent,"using XYZ rotation!") 
		else 
			if IsValid(joint) then 
				constraint.Weld(joint,parentent,0,0,0,true,false) 
			else 
				constraint.Weld(self,parentent,0,0,0,true,false) -- weld on physics objects 
			end 
		end 
				
	else -- STATIC OBJECTS 
		if IsValid(joint) then 
			constraint.Weld(joint,parentent,0,0,0,true,false) 
		else 
			constraint.Weld(self,parentent,0,0,0,true,false) -- weld on physics objects 
		end 
	end 
end 

-- ENT.InitSubob 
-- Purpose: Initialize sub-objects for an entity. 
-- Input: None. 
-- Output: None. 

function ENT:InitSubob() 
	local subobtbl = BREED.Subob[self.ob_name] 
	if subobtbl and subobtbl[1] then 
		for i = 1, #subobtbl do 
			local fieldname = table.GetKeys(subobtbl[i])[1] -- will return HANGER for BREED.Subob.DROPSHIP.1 
			local parentent = ents.Create("basemercuryobject") 
			parentent.ob_name = fieldname 
			parentent.Mercury_vecLocalPos = (subobtbl[i][fieldname].pos)*scalar -- nearly exact representation of local coordinates used in breed 
			parentent.Mercury_vecLocalAng = subobtbl[i][fieldname].ang -- nearly exact representation of local coordinates used in breed 
			parentent:SetPos(self:LocalToWorld(parentent.Mercury_vecLocalPos)) 
			parentent:SetAngles(self:LocalToWorldAngles(parentent.Mercury_vecLocalAng)) 
			parentent:SetKeyValue(keystring,fieldname) -- define object name 
			parentent:SetSubEnt(self) 
			parentent:SetSubMode(subobtbl[i][fieldname].mode) 
			table.insert(self.tblsubents,parentent) 
			local subent = self
			if IsValid(parentent:GetSubEnt()) and IsValid(parentent:GetSubEnt():GetOwner()) then subent = parentent:GetSubEnt():GetOwner() end 
			if subent then 
				parentent:SetOwner(subent) -- this will decide the main entity we are connected to. this will be DROPSHIP entity for every object that DROPSHIP has. 
			end 
			if self != parentent:GetOwner() then 
				table.insert(parentent:GetOwner().tblsubents,parentent) 
			end 
			parentent:Spawn() 
			-- if self:GetMoveType() != MOVETYPE_VPHYSICS then 
				-- parentent:SetParent(self) 
			-- end 
			
			
			if self:Mercury_HasPhysics() and !parentent:Mercury_HasPhysics() then 
				print("base ent",self:GetOBName(), "has phys but sub ent",parentent:GetOBName(),"doesn't have physics") 
				parentent:SetParent(self) 
			end 
			
			if !self:Mercury_HasPhysics() and !parentent:Mercury_HasPhysics() then 
				print("both base ent",self:GetOBName(),"and sub ent",parentent:GetOBName(),"doesn't have physics") 
				parentent:SetParent(self) 
			end 
			
			if !self:Mercury_HasPhysics() and parentent:Mercury_HasPhysics() then 
				print("base ent",self:GetOBName(),"doesn't have phys but sub ent",parentent:GetOBName(),"has physics. weld those objects with a joint") 
				local joint = ents.Create("prop_physics") 
				joint:SetModel("models/blackout.mdl") 
				joint:SetPos(parentent:GetPos()) 
				joint:SetParent(self) 
				joint:PhysicsInitBox(joint:GetModelBounds()) 
				joint:SetSolid(SOLID_NONE) 
				joint:SetNotSolid(1) 
				joint:Spawn() 
				joint:Activate() 
				joint:GetPhysicsObject():SetMass(999999) 
				joint:GetPhysicsObject():EnableGravity(0) 
				joint:SetNotSolid(1) 
				joint:SetSolid(SOLID_NONE) 
				joint:PhysicsInitBox(joint:GetModelBounds()) 
				joint:SetCollisionGroup(COLLISION_GROUP_WORLD) 
				parentent.Mercury_entJoint = joint 
				parentent:GetPhysicsObject():EnableGravity(0) 
				self:Mercury_BaseInitPhysRotation(parentent,joint) 
				-- parentent:SetParent(self) 
			end 
			
			-- if !self:Mercury_HasPhysics() and parentent:Mercury_HasPhysics() then 
				-- parentent:SetParent(self) 
			-- end 
			
			-- if (self:Mercury_HasPhysics() and !parentent:Mercury_HasPhysics()) or !self:Mercury_HasPhysics() and parentent:Mercury_HasPhysics() then 
				-- parentent:SetParent(self) 
			-- end 
			
			if self:Mercury_HasPhysics() and parentent:Mercury_HasPhysics() then 
				print("both base ent",self:GetOBName(), "and sub ent", parentent:GetOBName(),"has physics.") 
				self:Mercury_BaseInitPhysRotation(parentent) 
			end 
		end 
	end 
end 

function ENT:Mercury_MoveAllSubToLocalPos() 
	-- Move all the sub-entities attached to the parent entity to their respective local positions. 
	-- This function is called repeatedly to ensure that the sub-entities are always in their correct positions. 
	if !IsValid(self:GetOwner()) and self.tblsubents then 
	-- Check whether we're not the base entity and if there are any sub-entities attached to ourselves.
	-- If either of these conditions is not met, the function terminates.
		for k,parentent in pairs(self.tblsubents) do -- Loop through each sub-entity attached to the parent entity. 
			if IsValid(parentent:GetSubEnt()) then -- Check if the sub-entity in our table is valid. 
				local self2 = parentent:GetPhysicsObject():IsValid() and parentent:GetPhysicsObject() or parentent -- Get the physics object of the sub-entity if it exists, otherwise use the sub-entity itself. 
				local targetPos = self:LocalToWorld(parentent.Mercury_vecLocalPos) -- Calculate the local position of the sub-entity relative to the parent entity. 
				if self2:GetPos() == targetPos then return false end -- If the sub-entity is already at its target position, terminate the function. 
				self2:SetPos(targetPos,true) -- Move the sub-entity to its target position. 
			end 
		end 
	end 
end 

function ENT:Mercury_MoveSubToLocalPos() 
	
	if IsValid(self:GetSubEnt()) then 
		local self2 = self:GetPhysicsObject():IsValid() and self:GetPhysicsObject() or self 
		if BREED.Objects[self:GetOBName()].mode == "WHEEL" and IsValid(self.Mercury_entSuspension) then 
			self.Mercury_entSuspension:GetPhysicsObject():SetAngleVelocityInstantaneous(Vector(0,0,0)) 
			self2:SetPos(self.Mercury_entSuspension:GetPhysicsObject():GetPos(),false) 
			self:SetPos(self.Mercury_entSuspension:GetPos(),false) 
		else  
			-- parentent:SetPos(self:LocalToWorld(parentent.Mercury_vecLocalPos)) 
			self2:SetPos(self:GetSubEnt():LocalToWorld(self.Mercury_vecLocalPos),false) 
		end 
	end 
end 

function ENT:Mercury_ForceAngleToJoint() 
	self:GetPhysicsObject():SetAngles(self.Mercury_entJoint:GetPhysicsObject():GetAngles()) 
	self:SetAngles(self.Mercury_entJoint:GetAngles()) 
end 

function ENT:InitMoveType_MultiConvexVehicle() 
	MsgC(color_white,self.ob_name.." will be multiconvex physics vehicle.\n") 
	
	self.breed_collisionmesh = {} 
	self.breed_collisionmesh.verticies = { } 
	local model = self:GetModel() 
	for k,v in pairs(BREED.GetModelMeshes(model)) do 
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

function ENT:Mercury_VehicleCanSteer() 
	if !self.tblsubents or self.tblsubents and #self.tblsubents < 1 then return false end 
	if self.tblsubents then 
		for k,v in pairs(self.tblsubents) do 
			if v:Mercury_WheelCanSteer() then return true end -- at least has one steering wheel 
		end 
	end 
end 

function ENT:Mercury_WheelCanSteer() 
	local WheelSettings = BREED.WheelSettings[self:GetOBName()] 
	local InputSettings = BREED.InputSettings[self:GetOBName()] 
	InputSettings = InputSettings and (InputSettings.ANLG_LR or InputSettings.DGTL_LR) or nil 
	return WheelSettings and WheelSettings.steered and InputSettings and InputSettings.Y and InputSettings.Y.rate and InputSettings.Y.rate != "0" 
end 

function ENT:InitMoveType_Static() 
	MsgC(color_white,self.ob_name.." will be physics from mesh entity.\n") 
	
	local meshindex = self:Mercury_TranslateMeshIndex(BREED.Objects[self:GetOBName()].mesh) -- collision mesh replacement 
	meshindex = GetProperIndex(meshindex) 
	-- meshindex = self:Mercury_TranslateMeshIndex(meshindex) 
	local modelname = BREED.Models[meshindex] 
	local modelpath = self:GetModel() 
	if modelname then modelpath = Model("models/breed/"..BREED.Models[meshindex]) end 
	
	self.breed_collisionmesh = {} 
	self.breed_collisionmesh.verticies = { } 
	for k,v in pairs(BREED.GetModelMeshes(modelpath)) do 
		table.Add(self.breed_collisionmesh.verticies,v.verticies) 
	end 
	
	self:PhysicsFromMesh(self.breed_collisionmesh.verticies) 
	self:SetSolid(SOLID_VPHYSICS)	
	self:SetMoveType(MOVETYPE_VPHYSICS) 
	self:EnableCustomCollisions(true) 
	local phys = self:GetPhysicsObject() 
	if phys:IsValid(phys) then 
		phys:EnableMotion(true) 
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
	elseif mode == "WHEEL" then 
		local scalar = BREED.WheelSettings[self:GetOBName()] 
		scalar = scalar and scalar.radius 
		scalar = scalar and scalar != "0" and tonumber(scalar) or 1 
		-- self:PhysicsInitSphere(self:BoundingRadius()*scalar) 
		self:Mercury_InitWheelPhysics() 
	elseif col_type == "POLY" then 
		if IsValid(self:InitMoveType_Static()) then 
			self:GetPhysicsObject():EnableMotion(true) 
		end 
	elseif col_type == "BOX" then 
		self:PhysicsInitBox(self:GetCollisionBounds()) 
		self:GetPhysicsObject():EnableMotion( true ) 
	elseif col_type == "SPHERE" then 
		self:PhysicsInitSphere(self:BoundingRadius()) 
		self:GetPhysicsObject():EnableMotion( true ) 
	elseif mode == "JET" then 
		self:PhysicsInitBox(self:GetCollisionBounds()) 
		self:GetPhysicsObject():EnableMotion( true ) 
	
	else 
		print("OBJECT",self,self.ob_name,"MOVETYPE IS:", col_type) 
		self:SetSolid(SOLID_NONE) 
		self:SetMoveType(MOVETYPE_NONE) 
	end 
	local phys = self:GetPhysicsObject() 
	if phys and IsValid(phys) then 
		local mass = self:Mercury_CalculateMass() 
		phys:SetMass(mass) 
		if IsValid(self:GetSubEnt()) then 
			phys:AddGameFlag(FVPHYSICS_CONSTRAINT_STATIC+FVPHYSICS_MULTIOBJECT_ENTITY+FVPHYSICS_NO_PLAYER_PICKUP+FVPHYSICS_NO_SELF_COLLISIONS) 
		end 
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

function ENT:DrawEmitters() -- similar to lights and sprites 
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
	if LocalPlayer():InVehicle() then return end 
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
		for rotMethod, rotTbl in pairs(inputsettings) do -- -- "ANLG_LR" = {"Y", "Z"}	
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
				if obmode == "ROTATE_THROTTLE" and IsValid(self:GetOwner()) then 
					maxrotspeed = maxrotspeed * self:GetOwner():GetThrustRate() 
				end 
				if self.Mercury_bRotationBounce == true then axis = -axis end 
				curAngles:RotateAroundAxis(axis,maxrotspeed*FrameTime()) 
				
				if physobj then 
					if IsValid(self:GetSubEnt()) then 
						_,curAngles = LocalToWorld(vector_origin,curAngles,vector_origin,self:GetSubEnt():GetAngles()) 
					else 
						_,curAngles = LocalToWorld(vector_origin,curAngles,vector_origin,self.Mercury_angSpawnAngles) 
					end 
					-- physobj:SetAngles(curAngles) 
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

function ENT:Mercury_JetThink() 

	local engineThrust = self:GetThrustRate() -- parented to an aircraft 
	local targetThrust = IsValid(self:GetOwner()) and self:GetOwner():GetThrustRate() or engineThrust 
	local increment = math.Approach(engineThrust,targetThrust,0.5) 
	self:SetThrustRate(increment) 
	local thrustForce = BREED.Objects[self:GetOBName()].thrust_kg 
	thrustForce = thrustForce * (self:GetThrustRate()*0.01) 
	if self.SetForce and self.ForceLinear != thrustForce then self:SetForce(thrustForce,self:Mercury_GetForceMultiplier()) end 
end 

function ENT:Mercury_WheelThink() 
	local maxvel = BREED.Objects[self:GetOwner():GetOBName()].maxvel 
	-- Make the wheel spin
	local impulse = self:GetOwner():GetRight() -- Direction of the impulse force 
	local force = maxvel*self:GetOwner():GetThrustRate() -- Magnitude of the force 
	local position = self:GetPhysicsObject():GetPos() -- Position to apply the force 
	local torque,torquelocal = self:GetPhysicsObject():CalculateForceOffset(impulse * force, position) 
	self:GetPhysicsObject():ApplyTorqueCenter(torque) 
	-- print("applied torque to",self,"impulse:",impulse,"force:",force,"position:",position,torque,torquelocal) 
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
		
		local seat = self:GetControllerSeat() 
		if IsValid(seat) then 
			if SERVER then 
				local viewEntity = self:Mercury_FindViewPointEnt() 
				-- MsgC(color_white,"viewEntity is: "..tostring(viewEntity).." ".. viewEntity:GetOBName().." \n") 
				-- if IsValid(viewEntity) then driver:SetViewEntity(viewEntity) end 
				if IsValid(viewEntity) then seat:SetNW2Entity("Mercury_entView",viewEntity) end 
			end 
			local driver = seat:GetDriver() 
			if IsValid(driver) then 
				seat.Mercury_Driver = driver 
				local viewEntity = seat:GetNW2Entity("Mercury_entView") 
				-- print(viewEntity:GetOBName()) 
				-- print(viewEntity:GetAngles()) 
				-- local viewAngles = viewEntity:GetLocalAngles() 
				-- viewAngles.x = -viewAngles.x 
				-- viewAngles.y = 0 
				-- viewAngles.z = -viewAngles.z 
				
				-- if SERVER then driver:SetEyeAngles(viewAngles) end 
				-- if !seat.RenderOverride then 
					seat.RenderOverride = function() 
						local velocity = viewEntity:GetVelocity()*(FrameTime()) 
						-- velocity = vector_origin 
						local viewPos = BREED.ViewPointSettings[viewEntity:GetOBName()] 
						viewPos = viewPos and viewEntity:LocalToWorld(viewPos*scalar) or viewEntity:WorldSpaceCenter() 
						-- print(viewPos) 
						-- viewPos = viewPos or viewEntity:WorldSpaceCenter() 
						seat:SetRenderOrigin(viewPos+velocity) 
						-- seat:SetRenderAngles(viewEntity:GetAngles()+Angle(0,180,0)) 
						-- LocalPlayer():SetEyeAngles(self:GetAngles()) 
					end 
				-- end 
				-- if seat.SetRenderOrigin and IsValid(viewEntity) then seat:SetRenderOrigin(viewEntity:GetPos()) end 
				
				if driver:KeyDown(IN_FORWARD) and self:GetThrustRate() < 100 then 
					self:SetThrustRate(self:GetThrustRate()+0.5)
				end 
				
				if driver:KeyDown(IN_BACK) and self:GetThrustRate() > -100 then 
					self:SetThrustRate(self:GetThrustRate()-0.5) 
				end 
				-- print("THROTTLE:",self:GetThrustRate()) 
			else 
				if seat.Mercury_Driver then 
					if IsValid(seat.Mercury_Driver) then 
						self:Mercury_VehicleExit(seat.Mercury_Driver,seat) 
					end 
					seat.Mercury_Driver = nil 
				end 
			end 
		end 
		
	end 
	
	if BREED.Objects[self:GetOBName()].mode == "JET" then -- i am a jet 
		self:Mercury_JetThink() 
		
	elseif BREED.Objects[self:GetOBName()].mode == "WHEEL" and self:GetPhysicsObject():IsValid() and IsValid(self:GetOwner()) and self:GetOwner():GetThrustRate() != 0 and BREED.WheelSettings[self:GetOBName()] and tonumber(BREED.WheelSettings[self:GetOBName()].rotate) > 0 then -- a wheel 
		-- self:Mercury_WheelThink() 
	end 
	
	if self:Mercury_CanRotate() then -- except wheels 
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
				curvel = curvel/(maxvel*-scalar) 
				pitch = math.Remap(curvel,0,100,pitch_min,pitch_max) 
				self.LoopSound:ChangePitch(pitch) 
			end 
			
			-- set volume depending on velocity 
			
		elseif obtype == "JET" then 
			if pitch_mode == "THROTTLE" then 
				local curvel = self:GetThrustRate() 
				curvel = math.abs(curvel) 
				pitch = math.Remap(curvel,0,100,pitch_min,pitch_max) 
				self.LoopSound:ChangePitch(pitch) 
			end 
			
		end 
	end 
	self:NextThink(CurTime()+0.01) 
	return true 
	
end 

-- ENT.Mercury_FindViewPointEnt 
-- input: self 
-- output: 1- Entity: Object to use as viewpoint. 2- Entity OBJECT Name. 
function ENT:Mercury_FindViewPointEnt() 
	if BREED.Objects[self:GetOBName()].camera == "1" then return self end  -- first, assess ourselves 
	if self.tblsubents and !table.IsEmpty(self.tblsubents) then 
		for k,v in pairs(self.tblsubents) do -- then, our sub entities. those that are connected to us 
			if BREED.Objects[v:GetOBName()].camera == "1" then return v end 
		end 
	end 
	local newEnt = self:Mercury_FindParentEntity("NEW") -- then, our branch entity we're connected to 
	if !IsValid(newEnt) then newEnt = self:GetOwner() end 
	if !IsValid(newEnt) then newEnt = self end 
	if BREED.Objects[newEnt:GetOBName()].camera == "1" then return newEnt end 
	if newEnt.tblsubents and !table.IsEmpty(newEnt.tblsubents) then 
		for k,v in pairs(newEnt.tblsubents) do 
			if BREED.Objects[v:GetOBName()].camera == "1" then return v end 
		end 
	end 
end 

function ENT:Mercury_VehicleEnter(ply,seat) 
	-- emit starting sound 
	local mainEnt = self:Mercury_FindParentEntity("NEW") 
	mainEnt = IsValid(mainEnt) and mainEnt or self:GetOwner() 
	mainEnt = IsValid(mainEnt) and mainEnt or self 
	-- mainEnt = IsValid(self:GetOwner()) and self:GetOwner() or self  -- FIXME: Either "NEW" Entity or "Owner" Entity 
	local sndIndex = BREED.ObjectSounds[mainEnt:GetOBName()] 
	sndIndex = sndIndex and sndIndex.start or 0 
	self:EmitSound("BREED."..sndIndex) 
	
	-- give player weapons mounted on the vehicle 
	-- local weapon = ply:Give("basemercuryweapon") 
	
	-- get all sub entities with a gun 
	-- make sure all sub entities are connected to the "NEW" entity 
	-- with a "SUB" spawn parameter 
	-- include weapons on self entity 
	-- do not check weapons on "NEW" or "AUTO" 
	-- local weapons = BREED.AmmoSettings[]
	
end 

function ENT:Mercury_VehicleExit(ply,seat) 
	local mainEnt = IsValid(self:GetOwner()) and self:GetOwner() or self  -- FIXME: Either "NEW" Entity or "Owner" Entity 
	local sndIndex = BREED.ObjectSounds[mainEnt:GetOBName()] 
	sndIndex = sndIndex and sndIndex.endsound or 0 
	self:EmitSound("BREED."..sndIndex) 
	
	ply:SetAllowWeaponsInVehicle(false) 
end 

function ENT:MercuryWheel_GetSteerForce(phys,deltatime) 
	local wheelSettings = BREED.WheelSettings[self:GetOBName()] 
	if wheelSettings and tonumber(wheelSettings.steered) > 0 then 
		-- check whether wheel is touching the ground 
		local ownerVehicle = self:GetOwner() 
		if !IsValid(ownerVehicle) then return vector_origin end 
		local ownerDriver = ownerVehicle:GetControllerSeat() 
		if !IsValid(ownerDriver) then return vector_origin end 
		ownerDriver = ownerDriver:GetDriver() 
		if !IsValid(ownerDriver) then return vector_origin end 
		if !phys:GetFrictionSnapshot() then return vector_origin end 
		local scale = 5000 
		if ownerDriver:KeyDown(IN_MOVELEFT) and ownerDriver:KeyDown(IN_MOVERIGHT) then return vector_origin 
			elseif ownerDriver:KeyDown(IN_MOVELEFT) then return Vector(0,-scale,0) 
			elseif ownerDriver:KeyDown(IN_MOVERIGHT) then return Vector(0,scale,0) 
		end 
	end 
end 

function ENT:PhysicsSimulate( phys, deltatime ) 
	
	-- for non-phys to phys parents: force sub entity to move to parent entity's weld position 
	if IsValid(self.Mercury_entJoint) then 
		-- print(self.Mercury_entJoint:GetAngles()) 
		-- self2:SetPos() 
		self.Mercury_entJoint:GetPhysicsObject():SetPos(self:GetSubEnt():LocalToWorld(self.Mercury_vecLocalPos),true) 
		self.Mercury_entJoint:GetPhysicsObject():SetAngles(self:GetAngles()) 
		if IsValid(self.Mercury_entSuspension) then 
			local length = tonumber(BREED.WheelSettings[self:GetOBName()].travel)*-scalar 
			local wheelpos = self:Mercury_CalculateSuspensionPos(self.Mercury_entJoint,length) 
			self.Mercury_entSuspension:GetPhysicsObject():SetPos(wheelpos,true) 
			self.Mercury_entSuspension:SetPos(wheelpos,true) 
			self.Mercury_entSuspension:GetPhysicsObject():SetAngleVelocityInstantaneous(Vector(0,0,0)) 
		end 
 		self:Mercury_MoveSubToLocalPos() 
		self:GetPhysicsObject():SetAngleVelocityInstantaneous(Vector(0,0,0)) 
		self:Mercury_ForceAngleToJoint() 
	end 
	
	if BREED.Objects[self:GetOBName()].mode == "JET" then return Vector(0,0,0), self.ForceLinear, SIM_LOCAL_ACCELERATION end
	if BREED.Objects[self:GetOBName()].mode == "WHEEL" then 
		-- PrintTable(phys:GetFrictionSnapshot()) 
		-- print("stress:",phys:GetStress()) 
		local wheelSettings = BREED.WheelSettings[self:GetOBName()] 
		local torque = 0 
		local steer = self:MercuryWheel_GetSteerForce(phys,deltatime) 
		if wheelSettings then 
			local maxvel = BREED.Objects[self:GetOwner():GetOBName()].maxvel 
	-- Make the wheel spin
			local impulse = self:GetOwner():GetRight() -- Direction of the impulse force 
			local force = maxvel*self:GetOwner():GetThrustRate() -- Magnitude of the force 
			torque = force 
			
			local position = self:GetPhysicsObject():GetPos() -- Position to apply the force 
			local torque,torquelocal = self:GetPhysicsObject():CalculateForceOffset(impulse * force, position) 
			
			local shouldLimit = phys:GetAngleVelocity():Length() > force 
			if !shouldLimit then 
				phys:ApplyTorqueCenter(torque) 
			end 
			
			
			print(torque:Length(),phys:GetAngleVelocity():Length(),phys:GetDamping()) 
			return Vector(0,0,0), steer, SIM_LOCAL_ACCELERATION 
		end 
	end

	-- jet propulsion, copied from Gmod Thrusters 
	-- return self.ForceAngle, self.ForceLinear, SIM_LOCAL_ACCELERATION
	return SIM_NOTHING 
end

function ENT:OnRemove() 
	if self.LoopSound then self.LoopSound:Stop() self.LoopSound = nil end 
end 

function ENT:Use(activator,caller,useType,value) 
	if !IsValid(activator) or IsValid(activator) and !activator:IsPlayer() then return false end 
	-- if value != 0 then self:Mercury_VehicleEnter(activator) return end 
	local mainEnt = IsValid(self:GetOwner()) and self:GetOwner() or nil 
	local closestEnt = nil 
    local closestDist = math.huge 
	local eyePos = activator:EyePos() 
	for k,v in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do 
		if IsValid(v) and IsValid(v:GetNW2Entity("Mercury_entParent")) then -- find closest vehicle seat to player 
			local dist = eyePos:DistToSqr(v:EyePos()) 
			if dist < closestDist then 
				closestEnt = v 
				closestDist = dist 
			end 
		end 
	end 

	if IsValid(closestEnt) then 
		-- print(closestEnt) 
		activator:SetAllowWeaponsInVehicle(true) 
		closestEnt:Fire("entervehicle","",0,activator,activator) 
		closestEnt:GetNW2Entity("Mercury_entParent"):Mercury_VehicleEnter(activator,closestEnt) 
	end 

end 

local function Mercury_VehicleViewPoint(apc,ply,tbl) 
	-- ensure we are in an apc, clientsided 
	if apc:GetClass() != "prop_vehicle_prisoner_pod" then return end 
	if !IsValid(ply) and !IsValid(ply:GetVehicle()) and ply:GetVehicle():GetClass() != "prop_vehicle_apc" then return end 
	local eyeAttachment = apc:LookupAttachment("vehicle_driver_eyes") -- a driver eyepos coordinate already exists 
	if eyeAttachment != 0 then return end -- skip the hook 
	-- we're in 
	local enterTime = apc:GetNWFloat("apc_entertime") 
	local originalOrigin = ply:EyePos() 
	local desiredOrigin = apc:WorldSpaceCenter()+(apc:GetUp()*cl_apc_view_upvec:GetFloat()) 
	local timeDiff = math.Clamp(CurTime() - enterTime,0,1) 
	local resultOrigin = LerpVector(timeDiff,originalOrigin,desiredOrigin) 
	-- print(ply:EyePos()) 
	tbl.origin = resultOrigin 
	--[[ 
	-- note: angle fix not needed 
	-- tbl.angles = apc:GetAngles() + Angle(apc:GetPoseParameter("vehicle_weapon_pitch"),apc:GetPoseParameter("vehicle_weapon_yaw"),0) 
	local turret_attachment_angles = apc:WorldToLocalAngles(apc:GetAttachment(6).Ang) 
	-- tbl.angles = apc:GetAngles() + Angle(turret_attachment_angles.x,turret_attachment_angles.y,0) -- this works best 
	-- tbl.angles = ply:LocalEyeAngles() + Angle(turret_attachment_angles.x,turret_attachment_angles.y,0) -- this works kinda 
	local pos2,ang2 = apc:GetVehicleViewPosition() 
	-- tbl.angles = ang2 + Angle(turret_attachment_angles.x,turret_attachment_angles.y,0) 
	--]] 
	-- return tbl 
end 
-- hook.Add("CalcVehicleView","prop_vehicle_apc_view_fixer",fix_view) -- client 


