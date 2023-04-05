-- breed object reader for GLua 
-- by DevilHawk 

-- define crucial tables beforehand 

local materialPath = "materials/models/breed" 
local soundPath = "sound/breed" 

BREED							=	{} 
BREED.Objects					=	{} 
BREED.AmmoSettings				=	{} 
BREED.ApproachSettings			=	{} 
BREED.CameraSettings			=	{} 
BREED.CharacterSettings			=	{} 
BREED.CollisionSphereSettings	=	{} 
BREED.CollisionMeshes			=	{} 
BREED.DamagePosSettings			=	{} -- where smokes emit as we take damage 
BREED.DamageMeshSettings		=	{} 
BREED.DamageMultiplierSetting	=	{}	
BREED.DefaultAnim				=	{}	
BREED.DefaultCharWeapon			=	{}
BREED.EmitterSettings			=	{} 
BREED.EnterIconSettings			=	{} 
BREED.ExplosionSettings			=	{} 
BREED.HitAnims					=	{}	
BREED.HitSounds					=	{} 
BREED.InputSettings 			=	{} 
BREED.Interiorspace				=	{} 
BREED.LauncherSettings			=	{} 
BREED.LoadposSettings			=	{} 
BREED.LightSettings				=	{} 
BREED.MapIconSettings			=	{} 
BREED.MuzzleSettings			=	{} 
BREED.PanelSettings				=	{} 
BREED.PilotSettings				=	{} 
BREED.ObjectSounds				=	{} 
BREED.SpriteSettings			=	{} 
BREED.Squad_Follow				=	{} 
BREED.States					=	{} 
BREED.Subob						=	{} 
BREED.Switches					=	{} 
BREED.Tag_Generate				=	{} 
BREED.ViewPointSettings			=	{} 
BREED.Weapon_Name				=	{} 
BREED.WeaponSounds				=	{} 
BREED.WheelSettings				=	{} 

MsgC(color_white,"BREED Scripting Init\n") 

if !BREED.Debug then BREED.Debug	=	{} end 
if BREED.Debug and BREED.Debug.ReloadTime and BREED.Debug.ReloadTime == CurTime() then 
	MsgC(color_white,"Skipping multiple reloads in one tick.\n") 
return end 
BREED.Debug.ReloadTime			=	CurTime() 
-- print(BREED.Debug.ReloadTime) 

local function hexcolortocolor_255(str) 
	local firstsub = string.sub(str,1,2) 
	local secondsub = string.sub(str,3,4) 
	local thirdsub = string.sub(str,5,6) 
	local fourthsub = string.sub(str,7) 
	firstsub = firstsub and tonumber(firstsub,16) or 255 -- 16 means hexadecimal base 
	secondsub = secondsub and tonumber(secondsub,16) or 255
	thirdsub = thirdsub and tonumber(thirdsub,16) or 255 
	fourthsub = fourthsub and tonumber(fourthsub,16) or 255 
	return Color(firstsub,secondsub,thirdsub,fourthsub) 
end 

local function GetMaterialPathFromID(id) 
	return path 
end 

local function convert_vector(x,y,z) x = tonumber(x) y = tonumber(y) z = tonumber(z) return z,-x,-y end 

local filepath = "objects" 

local function CreateObject(obj) -- important func 
-- #DEF	OBNAME	MODE	MESH	HEAD_ICON	COCKPIT	ICON	COLLISN	DETECT	DRANGE	CAMERA	SHADOW	MASS KG	THRUST KG	DAMAGE	MAXVEL	ACCEL	SPACE	SURF	TILT_Z	CAN CARRY	VIEW OB	TARGET OB	SOUND Db	FIREMISSION AWARE	TARGETTABLE
	local object = obj[2] 
	if BREED.Objects[object] and BREED.Objects[object] == object then MsgC(Color(255,255,255),"Scripting: Duplicate Vehicle Def:"..object.."\n") return end 
	-- BREED.Objects[object]		 			=		object 
	BREED.Objects[object]		 			=		{} -- create field. i.e. BREED.Objects.DROPSHIP 
	BREED.Objects[object].mode 				= 		obj[3] -- defines what this object actually is. a weapon, a vehicle, a thruster or a character? 
	BREED.Objects[object].mesh 				= 		obj[4] -- modelname 
	BREED.Objects[object].unused1			=		obj[5]
	BREED.Objects[object].head_icon 		= 		obj[6] 
	BREED.Objects[object].cockpit_icon 		= 		obj[7] 
	BREED.Objects[object].collision 		= 		obj[8] -- collision mesh 
	BREED.Objects[object].detect 			= 		obj[9] -- does this object look for other entities? if so, how? 
	BREED.Objects[object].drange 			= 		obj[10] -- max. distance between detectable entities 
	BREED.Objects[object].camera 			= 		obj[11] -- use this object as camera 
	BREED.Objects[object].shadow 			= 		obj[12] -- entity has shadow 
	BREED.Objects[object].mass_kg 			= 		obj[13] -- entity total mass 
	BREED.Objects[object].thrust_kg 		= 		obj[14] -- how much this entity can thrust 
	BREED.Objects[object].damage 			= 		obj[15] -- health 
	BREED.Objects[object].maxvel 			= 		obj[16] -- how fast can we go 
	BREED.Objects[object].accel 			= 		obj[17] -- acceleration 
	BREED.Objects[object].space 			= 		obj[18] -- for flying entities 
	BREED.Objects[object].surf 				= 		obj[19] 
	BREED.Objects[object].tilt_z 			= 		obj[20] -- how much to tilt this entity on Z axis when flying 
	BREED.Objects[object].can_carry 		= 		obj[21] -- can work as magnet for other vehicles 
	BREED.Objects[object].view_ob 			= 		obj[22] 
	BREED.Objects[object].target_ob 		= 		obj[23] 
	BREED.Objects[object].sound_db 			= 		obj[24] 
	BREED.Objects[object].firemission_aware = 		obj[25] 
	BREED.Objects[object].targettable 		= 		obj[26] -- is this object targetable by seeking missiles 
end 

local function DefineSubOb(obj) -- completed: now can take more than one entry 
-- #REM	SUBOB	VEHICLE	SUBOB	POS	ANGLE	TASK 
-- Scripting: unknown vehicle subob task type %s 
	local posx,posy,posz = convert_vector(obj[4],obj[5],obj[6]) 
	local object = obj[2] -- vehicle 
	local parent = obj[3] -- parent 
	-- BREED.Subob[object] = object -- target obj  
	if BREED.Subob[object] == nil then BREED.Subob[object] = {} end 
	local tblsize = (#BREED.Subob[object])+1 
	BREED.Subob[object][tblsize] 					=		{} 
	BREED.Subob[object][tblsize][parent] 			= 		{} -- obj to create and mount 
	-- BREED.Subob[object][tblsize][parent].pos 		= 		Vector(obj[4],obj[6],obj[5]) -- where our object will be, local to ent. x, y and z  
	BREED.Subob[object][tblsize][parent].pos 		= 		Vector(posx,posy,posz) -- where our object will be, local to ent. x, y and z  
	BREED.Subob[object][tblsize][parent].ang 		= 		Angle(obj[7],obj[8],obj[9]) -- angles, local to target ent. 
	BREED.Subob[object][tblsize][parent].mode 		= 		obj[10] -- in which mode our object will be controlled. 
															-- types: by itself (new), pilot controlled (sub) or vehicle controlled (auto) 
end 

local function DefineAmmoSettings(obj) -- completed 
-- #REM	ARM	VEHICLE	WEAPON	ROUNDS	MUZZLETYPE	SECONDARY WEAPON	SECONDARY ROUNDS	
	local object = obj[2]	-- i.e. DROPSHIP	
	local projectile = obj[3] 	-- i.e. minigun 
	if BREED.AmmoSettings[object] == nil then BREED.AmmoSettings[object] = {} end 
	--[[ 
	BREED.AmmoSettings[object].weapon						=		projectile	
	BREED.AmmoSettings[object].primary_rounds				=		obj[4]		
	BREED.AmmoSettings[object].muzzle						=		obj[5]		
	BREED.AmmoSettings[object].secondary_weapon				=		obj[6]		
	BREED.AmmoSettings[object].secondary_rounds				=		obj[7]	
	--]] 
	BREED.AmmoSettings[object][projectile]					=		{}	
	BREED.AmmoSettings[object][projectile].primary_rounds	=		obj[4]		
	BREED.AmmoSettings[object][projectile].muzzle			=		obj[5]		
	BREED.AmmoSettings[object][projectile].secondary_weapon	=		obj[6]		
	BREED.AmmoSettings[object][projectile].secondary_rounds	=		obj[7]	
end 

local function DefineApproachSettings(obj) 
-- #REM	APPRCH	VEHICLE	POS
	local object = obj[2]	
	if BREED.ApproachSettings[object] == nil then BREED.ApproachSettings[object] = {} end 
	local tblsize = (#BREED.ApproachSettings[object])+1 -- important to make it able to take more than one index 
	local posx,posy,posz = convert_vector(obj[3],obj[4],obj[5]) 

	BREED.ApproachSettings[object][tblsize] 				=		Vector(posx,posy,posz) 
end 

local function DefineCameraSettings(obj) -- completed 
	-- #REM	CAMERA	VEHICLE	POS			ANGLE																				
	-- example: #CAMERA	ASSAULT_RIFLEA	-63.2	38.6	-70	-15	0		
	local object							=	obj[2]	
	local posx,posy,posz = convert_vector(obj[3],obj[4],obj[5]) 
	local pos								=	Vector(posx,posy,posz) 
	local ang								=	Angle(obj[6],obj[7],0)	-- pitch and yaw only 
	BREED.CameraSettings[object]			=	{} 
	BREED.CameraSettings[object].pos		=	pos	
	BREED.CameraSettings[object].ang		=	ang 
end 

local function DefineCharacterSettings(obj) -- completed 
	-- #REM	CHARACTER	VEHICLE	SKILL	HEAD_ICON	SPEED	ACCURACY	MEDI_PAK	ENG_PAK	VOICE INDEX	VOICE PITCH	CAN_PILOT	WEAPON	
	-- example: #CHARACTER	HOLO_GUNNY	GRUNT	0	1	0	3	0	0	1	1	PUNCH		
	local object = obj[2]	
	BREED.CharacterSettings[object]				=	{} 		
	BREED.CharacterSettings[object].skill		=	obj[3]	
	BREED.CharacterSettings[object].head_icon	=	obj[4]	
	BREED.CharacterSettings[object].speed		=	obj[5]	
	BREED.CharacterSettings[object].accuracy	=	obj[6]	
	BREED.CharacterSettings[object].medi_pak	=	obj[7]	
	BREED.CharacterSettings[object].eng_pak		=	obj[8]	
	BREED.CharacterSettings[object].voice_index	=	obj[9]	
	BREED.CharacterSettings[object].voice_pitch	=	obj[10]	
	BREED.CharacterSettings[object].can_pilot	=	tobool(obj[11])	
	BREED.CharacterSettings[object].weapon		=	obj[12]	

end 

local function DefineCollisionSphereSettings(obj) 

end 

local function DefineDamagePosSettings(obj) -- completed 
-- #REM	DAMAGE POS	VEHICLE	X	Y	Z	RADIUS	LIFE	
	local object							=	obj[2]	
	BREED.DamagePosSettings[object]			=	{} 
	local posx,posy,posz = convert_vector(obj[3],obj[4],obj[5]) 
	BREED.DamagePosSettings[object].pos		=	Vector(posx,posy,posz) 
	BREED.DamagePosSettings[object].radius	=	obj[6]	
	BREED.DamagePosSettings[object].life	=	obj[7]	
end 

local function DefineDamageMeshSettings(obj) -- completed: mesh to be after dying 
	-- #DAMAGE_MESH	PROTO_MISSILEBASE-Y	557 
	local object							=	obj[2] 
	BREED.DamageMeshSettings[object]		=	obj[3] 	
end 

local function DefineDamageMultiplierSetting(obj) -- completed 
-- #REM	DAMAGE	VEHICLE	VALUE	
	local object							=	obj[2]	
	local dmg								=	obj[3]	
	BREED.DamageMultiplierSetting[object]	=	dmg 
end	

local function DefineDefaultCharWeapon(obj) -- completed 
-- #REM	ARM	VEHICLE	WEAPON	
	local object = obj[2]	
	local weapon = obj[3]	
	BREED.DefaultCharWeapon[object] = weapon	-- define only one weapon per char 
end 

local function DefineDefaultAnim(obj)	-- completed
-- #REM	ANIM	VEHICLE	ANIM	SUBINDEX	UPPER BODY	
	local object = obj[2]	
	local anim	 = obj[3]	
	BREED.DefaultAnim[object]				=	{}	
	BREED.DefaultAnim[object].anim			=	obj[4]	
	BREED.DefaultAnim[object].subindex		=	obj[5]	
	BREED.DefaultAnim[object].upper_body	=	tobool(obj[6])	-- turn 0 or 1 to boolean 
end 

local function DefineEmitterSettings(obj) -- completed 
-- #REM	EMITTER	VEHICLE	MODE	LIFE	TEXTURE	PROBABL	RADIUS	BLOOM	COL1	COL2	POSITION			VELOCITY	
-- #EMIT	BFIGHTERENG	THRTTL	0.2	67	0.1	400	1	ffe869	ff4800	0	0	0	0	0	-100 
	local object = obj[2] 
	if !BREED.EmitterSettings[object] then BREED.EmitterSettings[object]	=	{}	end 
	local tblsize = (#BREED.EmitterSettings[object])+1 -- important to make it able to take more than one index 
	
	BREED.EmitterSettings[object][tblsize] 				=	{} 
	BREED.EmitterSettings[object][tblsize].mode = obj[3] 
	BREED.EmitterSettings[object][tblsize].life = obj[4] 
	BREED.EmitterSettings[object][tblsize].texture = obj[5] 
	BREED.EmitterSettings[object][tblsize].probabl = obj[6] 
	BREED.EmitterSettings[object][tblsize].radius = obj[7] 
	BREED.EmitterSettings[object][tblsize].bloom = obj[8] 
	BREED.EmitterSettings[object][tblsize].col1 = hexcolortocolor_255(obj[9]) 
	BREED.EmitterSettings[object][tblsize].col2 = hexcolortocolor_255(obj[10])  
	local posx,posy,posz = convert_vector(obj[11],obj[12],obj[13]) 
	BREED.EmitterSettings[object][tblsize].position = Vector(posx,posy,posz) -- vector 
	if (obj[17] and #obj[17] > 1) or tonumber(obj[14]) == nil then -- fix for LDPENG, RDPENG, LDPENG_MP, RDPENG_MP 
		posx,posy,posz = convert_vector(obj[15],obj[16],obj[17]) 
	else 
		posx,posy,posz = convert_vector(obj[14],obj[15],obj[16]) 
	end 
	BREED.EmitterSettings[object][tblsize].velocity = Vector(posx,posy,posz) -- vector 
end 

local function DefineEnterIconSettings(obj) -- completed 
	local object = obj[2]	
	BREED.EnterIconSettings[object]		=	obj[3]
end 

local function DefineExplosionSettings(obj) -- completed 
-- #REM	EXPLOSIVE_FORCE	VEHICLE	TYPE	FORCE	RADIUS	

	local object = obj[2]	
	BREED.ExplosionSettings[object]				=	{}	
	BREED.ExplosionSettings[object].exptype		=	obj[3]	
	BREED.ExplosionSettings[object].force		=	obj[4]	
	BREED.ExplosionSettings[object].rad			=	obj[5]	
end 

local function DefineHitAnim(obj)	
-- #REM	HIT_ANIM	VEHICLE	STOOD ANIM	CROUCHED ANIM																						

	local object = obj[2]	
	BREED.HitAnims[object]				=	{}	
	BREED.HitAnims[object].stood_anim		=	obj[3]	
	BREED.HitAnims[object].crouched_anim	=	obj[4]	
end	

local function DefineInputSettings(obj)	
	-- #REM	INPUT	VEHICLE	AXIS	INPUT	MAX	MIN	RATE	
	-- input methods: ANLG_UD ANLG_LR DGTL_UD DGTL_LR 
	-- Scripting: unknown vehicle axis input %s
	-- Scripting: unknown vehicle axis %s 
	-- #INPUT	TOPTURR2A	Y	ANLG_LR	X	X	1000 
	local object = obj[2]	
	if !BREED.InputSettings[object] then BREED.InputSettings[object] = { } end -- TOPTURR2A 
	
	if !BREED.InputSettings[object][obj[4]] then BREED.InputSettings[object][obj[4]] = { } end -- ANLG_LR 
	if !BREED.InputSettings[object][obj[4]][obj[3]] then BREED.InputSettings[object][obj[4]][obj[3]] = { } end -- Y 
	BREED.InputSettings[object][obj[4]][obj[3]].minrot = obj[5] -- X 
	BREED.InputSettings[object][obj[4]][obj[3]].maxrot = obj[6] -- X 
	BREED.InputSettings[object][obj[4]][obj[3]].rate = obj[7] -- 1000 
end 

local function DefineInteriorSpace(obj) 

end 

local function DefineLauncherSettings(obj) 

end 

local function DefineLightSettings(obj) -- completed 
-- #REM	SPRITE	VEHICLE	MODE	COLOR	POSITION			RADIUS	
	local object = obj[2]	
	if !BREED.LightSettings[object] then BREED.LightSettings[object]	=	{}	end 
	local tblsize = (#BREED.LightSettings[object])+1 -- important to make it able to take more than one index 

	BREED.LightSettings[object][tblsize] 				=	{} 
	BREED.LightSettings[object][tblsize].texindex		=	obj[3] 
	BREED.LightSettings[object][tblsize].color			=	hexcolortocolor_255(obj[4]) 
	local posx,posy,posz = convert_vector(obj[5],obj[6],obj[7]) 
	BREED.LightSettings[object][tblsize].pos			=	Vector(posx,posy,posz) 
	BREED.LightSettings[object][tblsize].rad			=	obj[8] 
end 

local function DefineLoadposSettings(obj) 

end 

local function DefineMapIconSettings(obj) 
	local object = obj[2]	
	BREED.MapIconSettings[object]	=	obj[3]	
end 

local function DefineMuzzleSettings(obj) -- completed: can take more than one entry 
-- #REM	MUZZLE	VEHICLE	SUBTYPE	POSITION	
	local object = obj[2] -- vehicle 
	local subtype = obj[3] -- muzzle index. starts at 0. should start from 1 
	if BREED.MuzzleSettings[object] == nil then BREED.MuzzleSettings[object] = {} end 
	if BREED.MuzzleSettings[object][subtype] == nil then BREED.MuzzleSettings[object][subtype] = {} end 
	local tblsize = (#BREED.MuzzleSettings[object][subtype])+1 -- array starts at one 
	BREED.MuzzleSettings[object][subtype][tblsize] 			= 		{} 
	local posx,posy,posz = convert_vector(obj[4],obj[5],obj[6]) 
	BREED.MuzzleSettings[object][subtype][tblsize].pos 		= 		Vector(posx,posy,posz) -- where our muzzle will be, local to ent. x, y and z  
end 

local function DefinePanelSetting(obj) 

end 

local function DefinePilotPos(obj)	-- completed
-- #REM	PILOT	VEHICLE	PILOT OBJECT	POS	POSE	EJECT X	Y	Z	BLAST DAMAGE	0-lying	1-sitting	2-standing	
-- #REM	PILOT	VEHICLE	PILOT OBJECT	POS	POSE	EJECT X	Y	Z	BLAST DAMAGE	EXIT_ROOT	
-- #PILOT	DROPSHIP_MP	PILOT	0	-160	990		0	250	0	250	0	0	

	local object = obj[2] -- vehicle 
	-- BREED.PilotSettings[object] = object 
	BREED.PilotSettings[object] = {} 
	BREED.PilotSettings[object].pilotobject = obj[3] 
	local posx,posy,posz = convert_vector(obj[4],obj[5],obj[6]) 
	BREED.PilotSettings[object].pos = Vector(posx,posy,posz) 
	if obj[12] then 
		posx,posy,posz = convert_vector(obj[8],obj[9],obj[10]) 
		BREED.PilotSettings[object].ejectpos = Vector(posx,posy,posz) 
		BREED.PilotSettings[object].blastdamage = obj[11] 
		BREED.PilotSettings[object].sit_type = obj[12] 
	else	
		posx,posy,posz = convert_vector(obj[7],obj[8],obj[9]) 
		BREED.PilotSettings[object].ejectpos = Vector(posx,posy,posz) 
		BREED.PilotSettings[object].blastdamage = obj[10] 
		BREED.PilotSettings[object].sit_type = obj[11] 
	end 
end 

local function DefineSpriteSettings(obj) -- completed 
	local object = obj[2]	
	if !BREED.SpriteSettings[object] then BREED.SpriteSettings[object]	=	{}	end 
	local tblsize = (#BREED.SpriteSettings[object])+1 -- important to make it able to take more than one index 

	BREED.SpriteSettings[object][tblsize] 				=	{} 
	BREED.SpriteSettings[object][tblsize].texindex		=	obj[3] 
	BREED.SpriteSettings[object][tblsize].color			=	hexcolortocolor_255(obj[4]) 
	local posx,posy,posz = convert_vector(obj[5],obj[6],obj[7]) 
	BREED.SpriteSettings[object][tblsize].pos			=	Vector(posx,posy,posz) 
	BREED.SpriteSettings[object][tblsize].rad			=	obj[8] 
end 

local function DefineStates(obj)	

end 

local function DefineSwitches(obj) --	completed	
	-- #REM	SWITCH	VEHICLE	TYPE	STATE	ICON	POS X	POS Y	POS Z	RADIUS	VAR	
	-- #SWITCH	USCDARWIN	STATE_TOGGLE	ST07	2	-6.2	17	-120.9	4	0	

	local object = obj[2]	
	if !BREED.Switches[object] then BREED.Switches[object]	=	{}	end 
	local tblsize = (#BREED.Switches[object])+1 -- important to make it able to take more than one index 

	BREED.Switches[object][tblsize] 						=	{} 
	BREED.Switches[object][tblsize].stype 					=	obj[3] 
	BREED.Switches[object][tblsize].state 					=	obj[4] 
	BREED.Switches[object][tblsize].icon 					=	obj[5] 
	local posx,posy,posz = convert_vector(obj[6],obj[7],obj[8]) 
	BREED.Switches[object][tblsize].pos 					=	Vector(posx,posy,posz) 
	BREED.Switches[object][tblsize].rad 					=	obj[9] 
	BREED.Switches[object][tblsize].var 					=	obj[10] 
end 

local function DefineTag(obj) 
	local object = obj[2]	
	if !BREED.Tag_Generate then BREED.Tag_Generate	=	{}	end	
	BREED.Tag_Generate[object]						=	true	
end 

local function DefineViewPointSettings(obj) -- to be completed 
-- #REM	VIEWPOINT	VEHICLE	POSITION	
	local object = obj[2] -- vehicle 
	local x = obj[5] 
	if tonumber(x) == nil then x = 0 end 
	local posx,posy,posz = convert_vector(obj[3],obj[4],obj[5]) 
	BREED.ViewPointSettings[object]							=	Vector(posx,posy,posz)	
end 

local function DefineWeaponName(obj) 

end 

local function DefineWheelSettings(obj) 
	-- #REM	WHEEL	VEHICLE	DRIVEN	STEERED	ROTATE	TRAVEL cm	SMOKE	FORCE X OFF	FORCE Z OFF	HIDDEN_Y	RADIUS (M)	
	-- #WHEEL	DUALWHEELS		2	0	1	100	1	0	-600	0	0	
	-- #WHEEL	FDUALWHEELS		2	1	1	100	1	0	0	0	0	
	-- driven: 0 prevents throttling. 1 and 2 allows. 
	-- steered: allow wheel steering input. 
	-- rotate: allow wheel rotation. 
	-- travel cm: suspension amount, from start to down 
	-- force x off: increment "x" sideways wheel length 
	-- force z off: useless 
	-- radius: wheel radius 
	local object = obj[2] -- vehicle 
	BREED.WheelSettings[object]				=	{} 
	if tonumber(obj[3]) == nil then 
	BREED.WheelSettings[object].driven		=	obj[4] 
	BREED.WheelSettings[object].steered		=	obj[5] 
	BREED.WheelSettings[object].rotate		=	obj[6] 
	BREED.WheelSettings[object].travel		=	obj[7] 
	BREED.WheelSettings[object].smoke		=	obj[8] 
	BREED.WheelSettings[object].force_x_off	=	obj[9] 
	BREED.WheelSettings[object].force_z_off	=	obj[10] 
	BREED.WheelSettings[object].hidden_y	=	obj[11] 
	BREED.WheelSettings[object].radius		=	obj[12] 
	else 
	BREED.WheelSettings[object].driven		=	obj[3] 
	BREED.WheelSettings[object].steered		=	obj[4] 
	BREED.WheelSettings[object].rotate		=	obj[5] 
	BREED.WheelSettings[object].travel		=	obj[6] 
	BREED.WheelSettings[object].smoke		=	obj[7] 
	BREED.WheelSettings[object].force_x_off	=	obj[8] 
	BREED.WheelSettings[object].force_z_off	=	obj[9] 
	BREED.WheelSettings[object].hidden_y	=	obj[10] 
	BREED.WheelSettings[object].radius		=	obj[11] 
	end 
end 

local function Squad_Follow_Enabled(obj) 

end 

local function process_mercury_objcmd(tbl) 
	-- print(tbl[1])
	-- command processer that seperates tables of commands to their own parsers 
	-- feed it with a table like {"#SQUAD_FOLLOW","DARWIN_SEC0","1",2"} 
	-- and it will send the following table to Squad_Follow_Enabled parser 
	if tbl[1] == "#DEF" then 
		CreateObject(tbl) 
		-- MsgC(color_white,"Defined new object "..tbl[2].."\n") 
	elseif tbl[1] == "#SUBOB" then 
		DefineSubOb(tbl) 
	elseif tbl[1] == "#AMMO" then 
		DefineAmmoSettings(tbl) 
	elseif tbl[1] == "#ARM" then 
		DefineDefaultCharWeapon(tbl)	
	elseif tbl[1] == "#APPRCH" then 
		DefineApproachSettings(tbl) 
	elseif tbl[1] == "#ANIM" then	
		DefineDefaultAnim(tbl)	
	elseif tbl[1] == "#CAMERA" then 
		DefineCameraSettings(tbl) 
	elseif tbl[1] == "#CHARACTER" then
		DefineCharacterSettings(tbl) 
	elseif tbl[1] == "#COLLISION_SPHERE" then 
		DefineCollisionSphereSettings(tbl) 
	elseif tbl[1] == "#DAMAGE_MESH" then 
		DefineDamageMeshSettings(tbl) 
	elseif tbl[1] == "#DAMAGE_POS" then 
		DefineDamagePosSettings(tbl) 
	elseif tbl[1] == "#DAMAGE_SCALAR" then 
		DefineDamageMultiplierSetting(tbl)	
	elseif tbl[1] == "#EMIT" then 
		DefineEmitterSettings(tbl) 
	elseif tbl[1] == "#ENTER_ICON" then 
		DefineEnterIconSettings(tbl) 
	elseif tbl[1] == "#EXPLOSIVE_FORCE" then 
		DefineExplosionSettings(tbl) 
	elseif tbl[1] == "#HIT_ANIM" then 
		DefineHitAnim(tbl)	
	elseif tbl[1] == "#INPUT" then 
		DefineInputSettings(tbl) 
	elseif tbl[1] == "#MAP_ICON" then 
		DefineMapIconSettings(tbl) 
	elseif tbl[1] == "#MZL" then 
		DefineMuzzleSettings(tbl) 
	elseif tbl[1] == "#LIGHT" then 
		DefineLightSettings(tbl) 
	elseif tbl[1] == "#LOADPOS" then 
		DefineLoadposSettings(tbl) 
	elseif tbl[1] == "#INTERIOR_SPACE" then 
		DefineInteriorSpace(tbl) 
	elseif tbl[1] == "#PANEL" then 
		DefinePanelSetting(tbl) 
	elseif tbl[1] == "#PILOT" then 
		DefinePilotPos(tbl) 
	elseif tbl[1] == "#SPRT" then 
		DefineSpriteSettings(tbl)
	elseif tbl[1] == "#STATE" then 
		DefineStates(tbl) 
	elseif tbl[1] == "#SQUAD_FOLLOW" then 
		Squad_Follow_Enabled(tbl) 
	elseif tbl[1] == "#SWITCH" then 
		DefineSwitches(tbl) 
	elseif tbl[1] == "#TAG_GENERATE" then 
		DefineTag(tbl) 
	elseif tbl[1] == "#VPOINT" then 
		DefineViewPointSettings(tbl) 
	elseif tbl[1] == "#WEAPON_NAME" then 
		DefineWeaponName(tbl) 
	elseif tbl[1] == "#WHEEL" then 
		DefineWheelSettings(tbl) 
	elseif tbl[1] == "#REM" then 
	-- else MsgC(color_white,"Unknown command:"..tbl[1].."\n") 
	end 
end 

local function DefineSoundScript(obj) -- to be completed 
-- #REM	SAMPLE	PITCH VARIANCE%	VOLUME VARIANCE%	VOLUME	FALLOFF (M)	
-- #SAMPLE	1	0	0	100	50	
	local samplenum = obj[2] -- sample number 
	-- TODO: obj[4] is volume variance, but cannot be defined in soundscripts 

	local soundFile = BREED.Sounds[samplenum] -- sound is existing and cached, use it 
	if   soundFile then soundFile = Sound("breed/"..soundFile) 
	else soundFile = "common/null.wav" end 

	sound.Add( 
	{ 
		name = "BREED."..samplenum, 
		channel = CHAN_AUTO, 
		volume = obj[5]*0.01, --- 100 to 1 
		level = obj[6], 
		pitch = {100+obj[3],100-obj[3]}, 

		sound = { soundFile } 
	}) 
end 

local function DefineObjectSound(obj) -- completed 
-- #REM	OB	LPSND	START	END	PITCH MODE	EFFECT MIN%	EFFECT MAX%	VOLUME MODE	EFFECT MIN%	EFFECT MAX%	VOL%	PITCH%	
-- #OBJECT	dropship	430	0	0	VELOCITY	30	50	VELOCITY	60	70	100	100	
	local object = string.upper(obj[2]) -- dropship 
	BREED.ObjectSounds[object]				=	{ } 
	BREED.ObjectSounds[object].lpsnd		=	obj[3] -- 430 
	BREED.ObjectSounds[object].start		=	obj[4] -- 431 
	BREED.ObjectSounds[object].endsound		=	obj[5] -- 432 
	BREED.ObjectSounds[object].pitch_mode	=	obj[6] -- VELOCITY 
	BREED.ObjectSounds[object].pitch_min	=	obj[7] -- 30 
	BREED.ObjectSounds[object].pitch_max	=	obj[8] -- 50 
	BREED.ObjectSounds[object].volume_mode	=	obj[9] -- VELOCITY 
	BREED.ObjectSounds[object].volume_min	=	obj[10] -- 60 
	BREED.ObjectSounds[object].volume_max	=	obj[11] -- 70 
	BREED.ObjectSounds[object].volume		=	obj[12] -- 100 
	BREED.ObjectSounds[object].pitch		=	obj[13] -- 100
end 

local function DefineWeaponSound(obj) 
-- #REM	WEAPON	FIRE	LOOP	RELOAD	EMPTY	CARTRIDGE EJECT	CARTRIDGE HIT	RICOCHET	EXPLODE	LOCKED ON	
-- #WEAPON	iw-r300	620	81	914	621	623	672	624	0	0	
	local object = string.upper(obj[2]) -- iw-r300 
	BREED.WeaponSounds[object]						=	{ } 
	BREED.WeaponSounds[object].fire					=	obj[3] -- 620 
	BREED.WeaponSounds[object].loop					=	obj[4] -- 81, bullet_flyby.wav 
	BREED.WeaponSounds[object].reload				=	obj[5] -- 914 
	BREED.WeaponSounds[object].empty				=	obj[6] -- 621 
	BREED.WeaponSounds[object].cartridge_eject		=	obj[7] -- 623, iw_grenade_empty.wav 
	BREED.WeaponSounds[object].cartridge_hit		=	obj[8] -- 672, sniper_rifle_cartridge_hit.wav 
	BREED.WeaponSounds[object].ricochet				=	obj[9] -- ricochet, 624 ,individual_weapon_ricochet.wav
	BREED.WeaponSounds[object].explode				=	obj[10] -- 0 
	BREED.WeaponSounds[object].locked_on			=	obj[11] -- 0 
	
end 

local function DefineHitSound(obj) 
	-- #REM	WEAPON	STONE	FLESH	METAL	ARMOUR	WOOD	WATER	SAND	GRAVEL	GRASS	ICE	SNOW	BODY_ARMOUR	BREED_ARMOUR	GLASS 
	-- #OBJECT_HIT	GRUNT	941	150	925	150	150	923	929	154	165	150	158	150	150	150 
	-- #WEAPON_HIT	BPLASMA_MP	119	116	118	117	110	112	115	111	113	120	114	117	117	73
	local object = obj[2] -- can be either OBJECT or WEAPON 
	BREED.HitSounds[object]					=	{} 
	BREED.HitSounds[object].stone			=	obj[3] 
	BREED.HitSounds[object].flesh			=	obj[4] 
	BREED.HitSounds[object].metal			=	obj[5] 
	BREED.HitSounds[object].armour			=	obj[6] 
	BREED.HitSounds[object].wood			=	obj[7] 
	BREED.HitSounds[object].water			=	obj[8] 
	BREED.HitSounds[object].sand			=	obj[9] 
	BREED.HitSounds[object].gravel			=	obj[10] 
	BREED.HitSounds[object].grass			=	obj[11] 
	BREED.HitSounds[object].ice				=	obj[12] 
	BREED.HitSounds[object].snow			=	obj[13] 
	BREED.HitSounds[object].body_armour		=	obj[14] 
	BREED.HitSounds[object].breed_armour	=	obj[15] 
	BREED.HitSounds[object].glass			=	obj[16] 
end 

local function process_mercury_soundfile(tbl) -- completed 
	if tbl[1] == "#OBJECT" then 
		DefineObjectSound(tbl) 
	elseif tbl[1] == "#SAMPLE" then 
		DefineSoundScript(tbl) 
	elseif tbl[1] == "#WEAPON" then 
		DefineWeaponSound(tbl) 
	elseif tbl[1] == "#OBJECT_HIT" or tbl[1] == "#WEAPON_HIT" then 
		DefineHitSound(tbl) 
	elseif tbl[1] == "#REM" then 
	-- else MsgC(color_white,"Unknown command:"..tbl[1].."\n") 
	end 
end 

local function process_mercury_meshadjustmentfile(tbl) -- completed 
	if tbl[1] == "#REM" then 
		 
	elseif tbl[1] == "#vis_boost" then -- defines the multiplier of object render distance 
		-- DefineVisBoost(tbl) 
	elseif tbl[1] == "#size" then -- scale the model by given value 
	elseif tbl[1] == "#xyz_scale" then -- scale the model xyz render separately by given value 
	elseif tbl[1] == "#detail" then -- detail textures to apply to the model 
	elseif tbl[1] == "#uv_scale" then -- idk 
	elseif tbl[1] == "#reflect" then -- idk 
	elseif tbl[1] == "#lores" then -- lod mesh to use 
	elseif tbl[1] == "#no_lod" then -- prevents use of lod mesh 
	elseif tbl[1] == "#centre" then -- idk 
	elseif tbl[1] == "#shadow" then -- shadow mesh to use  
	elseif tbl[1] == "#collision" or tbl[1] == "#char_collision" then -- collision mesh to use instead of original collision mesh 
		BREED.CollisionMeshes[tbl[2]]	=	tbl[3] 
	
	-- else MsgC(color_white,"Unknown command:"..tbl[1].."\n") 
	end 
end 

--[[ 
-- UNDONE: NO NEED TO USE THIS 
local function AssignModelPathforIndexes() 
	if #BREED.Objects == 0 then return end 
	MsgC(color_white,"Loading Models") 
	local model_names = file.Find("models/breed/*.mdl") -- list models into a table 
	for obname,_ in pairs(BREED.Objects) do -- iterate over each object 
		local meshindex = BREED.Objects[obname].mesh -- 110 for dropship, 004 for earth 
		for k,model_name in ipairs(model_names) do -- now iterate over each model 
			-- skip if we have more numbers after wherever we are checking 
			if string.StartWith(model_name,meshindex) and !isnumber(string.sub(model_name,#meshindex+1,#meshindex+1)) then 
				BREED.Objects[obname].mesh = Model("models/breed/"..model_name) 
				BREED.Objects[obname].mesh_has_model = true 
				break -- stop iterating 
			end 
			
			if !BREED.Objects[obname].mesh_has_model and string.StartWith(model_name,"0"..meshindex) and !isnumber(string.sub(model_name,#meshindex+2,#meshindex+2)) then -- reiterate with 0 at beginning 
				BREED.Objects[obname].mesh = Model("models/breed/"..model_name) 
				BREED.Objects[obname].mesh_has_model = true 
				break -- stop iterating 
			end 
		end 
	end 
end 
--]] 

-- filetable_reindex(table) 
-- feed this function with a table full of numerically sorted files 
-- then it will return a new table 
-- which every key is indexed depending on the start of their value 
-- for example: 004earth.mdl will be "4" = "004earth.mdl" 
local function filetable_reindex(tbl) 
	local newtbl = {} 
	for k,v in pairs(tbl) do 
		local indexnum = string.match(v,"[%d]*") -- the magic that finds if your string starts with num, counts all nums until it encounters non-number 
		local strindexcount = #indexnum 
		for i = 1, strindexcount do 
			if string.StartWith(indexnum,"0") then -- i have a zero at the beginning of filename 
				indexnum = string.sub(indexnum,2) -- hop over the zero at beginning 
			else 
				break 
			end 
		end 
		if #indexnum > 0 then newtbl[indexnum] = v end -- {"110" = "110dropship.mdl"} 
		-- if #indexnum > 0 then table.insert(newtbl,indexnum,v) end -- this gives unexpected indexing results when we try to return back to older nums
		-- indexnum > 0 means filename returned empty 
	end 
	return newtbl 
end 

local function readobjectfile(filename) 
	MsgC(color_white,"Loading object file definitions from "..filename.."\n") 
	local curfile = nil 
	if SERVER then 
		curfile = file.Open(filename,"r","LUA") -- open those files 
	else 
		curfile = file.Open(filename,"r","GAME") 
	end 
	while !curfile:EndOfFile() do -- loop: work until we reach the end of file 
		local curstring = curfile:ReadLine() -- read next line 
		local tableofstrings = string.Explode("%s",curstring,true) -- seperate given line to a table 
		-- while #tableofstrings[1] == 0 do table.remove(tableofstrings,1) end -- skip empty lines 
		if #tableofstrings[1] == 0 then table.remove(tableofstrings,1) end 
		process_mercury_objcmd(tableofstrings) 
	end 
	curfile:Close() 
end 

local function readsoundsfile(filename) 
	MsgC(color_white,"Loading sound scripts from "..filename.."\n") 
	local curfile = nil 
	curfile = file.Open(filename,"r","GAME") 
	while !curfile:EndOfFile() do -- loop: work until we reach the end of file 
		local curstring = curfile:ReadLine() -- read next line 
		local tableofstrings = string.Explode("%s",curstring,true) -- seperate given line to a table 
		-- while #tableofstrings[1] == 0 do table.remove(tableofstrings,1) end -- skip empty lines 
		if #tableofstrings[1] == 0 then table.remove(tableofstrings,1) end 
		process_mercury_soundfile(tableofstrings) 
	end 
	curfile:Close() 
end 

local function readmeshadjustmentfile(filename) 
	MsgC(color_white,"Loading mesh adjustment data from "..filename.."\n") 
	local curfile = nil 
	curfile = file.Open(filename,"r","GAME")  
	while !curfile:EndOfFile() do -- loop: work until we reach the end of file 
		local curstring = curfile:ReadLine() -- read next line 
		local tableofstrings = string.Explode("%s",curstring,true) -- seperate given line to a table 
		-- while #tableofstrings[1] == 0 do table.remove(tableofstrings,1) end -- skip empty lines 
		if #tableofstrings[1] == 0 then table.remove(tableofstrings,1) end 
		process_mercury_meshadjustmentfile(tableofstrings) 
	end 
	curfile:Close() 
end 

local function readbreedobjectfiles() -- read all file in lua/objects and create tasks according to given function name 
	MsgC(color_white,"Loading Scripts\n") 
	if BREED and BREED.Objects and !table.IsEmpty(BREED.Objects) then MsgC(Color(255,0,0),"Scripting: Tried to load objects while we already have obs defined! Halting. \n") return end 
	local objects_files = file.Find(filepath.."/*","LUA") -- look for all files in lua/objects 
	if table.IsEmpty(objects_files) then objects_files = file.Find("lua/"..filepath.."/*","GAME") end  -- case 2 
	if table.IsEmpty(objects_files) then MsgC(Color(255,0,0),"Scripting: No script file found! Halting.\n") return end 
	for _,objects_file in pairs(objects_files) do -- do the following for each file in objects 
		if SERVER then 
			local filepath2 = filepath.."/"..objects_file
			if file.Exists(filepath2,"LUA") then -- if those files really exist 
				readobjectfile(filepath2) 
			end 
		else 
			local filepath2 = "lua/"..filepath.."/"..objects_file 
			if file.Exists(filepath2,"GAME") then -- if those files really exist 
				readobjectfile(filepath2) 
			end 
		end 
	end	
	-- AssignModelPathforIndexes() undo: found a better way 
end	

local function CreateTriangleDataAndSave() -- clientside only 
	if SERVER then return end 
	if !BREED then return end 
	if !BREED.Models then return end 
	file.CreateDir("breed") 
	MsgC(color_white,"Cleaning up old vert data\n") 
	local files = file.Find("breed/*","DATA") -- retrieve all files 
	for k,v in pairs(files) do -- each file 
		file.Write("breed/"..v,"") -- erase data 
	end 
	MsgC(color_white,"creating vert data\n") 
	for k,v in pairs(BREED.Models) do 
		local modelpath = "models/breed/"..v 
		local printstring = "" 
		local modelmeshes = util.GetModelMeshes(modelpath) 
		for i = 1, #modelmeshes do -- all submodels in mesh 
			local vertdata = modelmeshes[i].triangles 
			local tblcount = tobool(table.Count(vertdata) < 16384*2) -- exclude models that have too many polygons 
			if tblcount then 
				for key,val in pairs(vertdata) do 
					printstring = vertdata[key].pos.x.."	"..vertdata[key].pos.y.."	"..vertdata[key].pos.z.."\r\n" 
					file.Append("breed/"..v..".txt",printstring) -- save only vert positions. x y z. 
				end 
			end 
		end 
	end 
end 
--[[ 
local function CreateTriangleDataFromSingleMesh() -- old code 
	print("creating vert data for single model")
	if SERVER then return end 
	local modelpath = "models/vehicles/ut99/hyperblast_ship.mdl"
	if util.IsValidModel(modelpath) then 
		local newtbl = {} 
		local vertdata = util.GetModelMeshes(modelpath)[1].triangles 
		local tblcount = tobool(table.Count(vertdata) < 8192) 
		print(tblcount) 
		if tblcount then 
			for key,val in pairs(vertdata) do 
				if !newtbl[key] then 
					newtbl[key] = {} 
				end 
				newtbl[key].pos = vertdata[key].pos 
			end 
		end 
		newtbl = table.ToString(newtbl,modelpath,true) 
		-- print("all valid so far")
		file.Write("breed/hyperblast_ship.txt",newtbl) 
	end 

end 
--]]

local function CreateTriangleDataFromSingleMesh(model) -- new code 
	print("creating vert data for single model") 
	local modelpath = Model(model) 
	if util.IsValidModel(modelpath) then 
		local newtbl = {} 
		local modelmeshes = util.GetModelMeshes(modelpath) 
		for i = 1, #modelmeshes do -- all submodels in mesh 
			local vertdata = modelmeshes[i].triangles 
			local tblcount = tobool(table.Count(vertdata) < 16384*2) -- exclude models that have too many polygons 
			if tblcount then 
				local printstring = "" 
				for key,val in pairs(vertdata) do 
					printstring = vertdata[key].pos.x.."	"..vertdata[key].pos.y.."	"..vertdata[key].pos.z.."\r\n" 
					file.Append("breed/hyperblast_ship.txt",printstring) -- save only vert positions. x y z. 
				end 
			end 
		end 
	end 
end 

local function DefineModelMeshes() -- this is for PhysicsInitMultiConvex or PhysicsFromMesh 
	if !SERVER then return end 
	if BREED and BREED.ModelMeshes then MsgC(color_white,"Refusing to reload model mesh data because they are already loaded. \n") return end 
	BREED.ModelMeshes				=	{} -- our current table 
	--	start reading data/breed 
	local tri_files = file.Find("breed/*","DATA")	
	for k,v in pairs(tri_files) do 
	-- read each file 
		local curfile = file.Open("breed/"..v,"r","DATA")	
		while !curfile:EndOfFile() and curfile:Size() > 1024 do -- is 1 kb 
			local curstring = curfile:ReadLine() -- read next line 
			if !curstring then break end 
			-- print(curstring,"in file:",v) 
			local tableofstrings = string.Explode("%s",curstring,true)  -- seperate given line to a table 
			-- expect three vectors at this point. x, y and z. 
			local curvector = Vector(tableofstrings[1],tableofstrings[2],tableofstrings[3]) 
			if !BREED.ModelMeshes[v] then BREED.ModelMeshes[v]	=	{} end -- "110dropshipbody.mdl.txt" 
			table.insert(BREED.ModelMeshes[v],curvector) -- save vectors to subtable  
		end 
		curfile:Close() 
	end 
end 

BREED.DefineModelMeshes = DefineModelMeshes 
BREED.FileTable_ReIndex = filetable_reindex 
BREED.HexColorToColor255 = hexcolortocolor_255 
BREED.ReadObjectFiles = readbreedobjectfiles 
MsgC(color_white,"Loading Textures...\n") 
BREED.Materials = filetable_reindex(file.Find(materialPath.."/*.vmt","GAME")) 
MsgC(color_white,"Loading Models...\n") 
BREED.Models = filetable_reindex(file.Find("models/breed/*.mdl","GAME")) 
MsgC(color_white,"Loading Sounds...\n") 
BREED.Sounds = filetable_reindex(file.Find(soundPath.."/*.wav","GAME")) 
readsoundsfile("lua/misc/Sounds.txt") 
readmeshadjustmentfile("lua/misc/MeshHelp.txt") 
BREED.CreateTriangleDataAndSave = CreateTriangleDataAndSave 
BREED.CreateTriangleDataFromSingleMesh = CreateTriangleDataFromSingleMesh 
readbreedobjectfiles() 
