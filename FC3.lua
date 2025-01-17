BIOS.protocol.beginModule("FC3", 0x6000)
BIOS.protocol.setExportModuleAircrafts(BIOS.FLAMING_CLIFFS_AIRCRAFT)

local defineIndicatorLight = BIOS.util.defineIndicatorLight
local define8BitFloatFromGetter = BIOS.util.define8BitFloatFromGetter
local defineFloatFromGetter = BIOS.util.defineFloatFromGetter
local defineIntegerFromGetter = BIOS.util.defineIntegerFromGetter
local defineString = BIOS.util.defineString

local _altitude = " -- "
local _altitudeG = " ---- "
local _altitudeS = " ---- "
local _verticalVelocity = " -- "
local _indicatedAirspeed = " -- "
local _trueAirspeed = " -- "
local _machNumber = " -- "
local _fuel = " -- "
local _AoA = " -- "
local _gLoad = " -- "
local _radarAltitude = 0
local _barFuel = 0
local _barGLoad = 0
local _barVVI = 8

local _adiBank = 0.0
local _adiPitch = 0.0
local _adiYaw = 0.0

local function LoGetSelfPlane()
	local self = LoGetSelfData()
	if self == nil then self = "XXX" end
	return self.Name
end

local function LoGetFuelAll()
	local eng = LoGetEngineInfo()
	if eng == nil then return end
	return eng.fuel_internal + eng.fuel_external
end

local function LoGetGLoad()
	local au = LoGetAccelerationUnits()
	if au == nil then return end
	return au.y
end

local function BarFuel(fuel, plane)
	local maxFuel = 1000

	if plane == "A-10A" then maxFuel = 5029
	elseif plane == "F-15C" then maxFuel = 6103
	elseif plane == "MiG-29A" or plane == "MiG-29G" then maxFuel = 3380
	elseif plane == "MiG-29S" then maxFuel = 3500
	elseif plane == "Su-25" then maxFuel = 2835
	elseif plane == "Su-25T" then maxFuel = 3790
	elseif plane == "Su-27" or plane == "Su-33" or plane == "J-11A" then maxFuel = 9400
	end

	local barf = math.ceil((fuel / maxFuel) * 16)
	if barf > 16 then barf = 16 end
    if barf == nil then return end
	return barf
end

local function BarGLoad(gload)
	local barg = math.floor((gload / 11) * 16)

	if barg < 0 then barg = 0
	elseif barg > 16 then barg = 16 end
    if barg == nil then return end
	return barg
end

local function BarVVI(vvi, plane)
	local divide = 150

	if plane == "A-10A" or plane == "F-15C" then divide = 30 end
	local bar = (vvi / divide) * 8
	if bar < -8 then bar = -8
	elseif bar < 0 then bar = math.floor(bar)
	elseif bar > 8 then bar = 8
	elseif bar > 0 then bar = math.ceil(bar)
	end
    if bar == nil then return end
	return bar + 8
end

local function allowMach(plane)
  if plane == "A-10A" then return false
  elseif plane == "Su-25T" then return false
  else return true end
end

local function allowTAS(plane)
  if plane == "Su-25" then return true
  elseif plane == "Su-25T" then return true
  else return false end
end

moduleBeingDefined.exportHooks[#moduleBeingDefined.exportHooks+1] = function()
	local self = LoGetSelfData()
	local plane = LoGetSelfPlane()

	local altS = LoGetAltitudeAboveSeaLevel() or 0
	local altG = LoGetAltitudeAboveGroundLevel() or 0
	local alt = altS or 0
	local vvi = LoGetVerticalVelocity() or 0
	local ias = LoGetIndicatedAirSpeed() or 0
	local tas = LoGetTrueAirSpeed() or 0
	local mach = LoGetMachNumber() or 0
	local fuel = LoGetFuelAll() or 0
	local aoa = LoGetAngleOfAttack() or 0
	local gload = LoGetGLoad() or 0
	_glidedev = LoGetGlideDeviation()
	_sidedev = LoGetSideDeviation()
	_slipball = LoGetSlipBallPosition()

	_barFuel = BarFuel(fuel, plane)
	_barGLoad = BarGLoad(gload)
	_barVVI = BarVVI(vvi, plane)
	
	-- _RPMLeft = LoGetEngineInfo().RPM.left 
	-- _RPMRight = LoGetEngineInfo().RPM.right 
	-- _TEMPLeft = LoGetEngineInfo().Temperature.left 
	-- _TEMPRight = LoGetEngineInfo().Temperature.right 
	-- _GearStatus = LoGetMechInfo().gear.value 	
	-- _chaff = LoGetSnares().chaff 
	-- _flare = LoGetSnares().flare 

	--[[ US PLANES ]]--
	if plane == "A-10A" or plane == "F-15C" or plane == "MiG-29G" then

		ias = ias * 1.94384449		-- knots
		tas = tas * 1.94384449		-- knots
		alt = alt * 3.2808399		-- feets
		altS = altS * 3.2808399		-- feets
		altG = altG * 3.2808399		-- feets
		vvi = vvi * 196.850394		-- feets per minute
		fuel = math.floor(fuel * 0.022) * 100
		aoa = aoa + 10

		if vvi > 6000 then vvi = 6000
		elseif vvi < -6000 then vvi = -6000 end
		vvi = vvi / 1000

		--[[ RADAR ALTIMITER ]]--
		if plane == "A-10A" or plane == "MiG-29G" then
			_radarAltitude = 1
			if altG > 5000 then _radarAltitude = 0 end
		end
		fuel = fuel / 100
		_fuel = string.format("%3.1f", math.floor(fuel));

	--[[ RU PLANES ]]--
	elseif	plane == "MiG-29A" or plane == "MiG-29S" or
			plane == "Su-25" or plane == "Su-25T" or
			plane == "Su-27" or plane == "Su-33" or plane == "J-11A" then

		ias = math.floor(ias * 0.36) * 10
		tas = math.floor(tas * 0.36) * 10
		if( tas < 400 ) then tas = 400 end
		alt = math.floor(alt * 0.1) * 10
		if altG > 1500 then _radarAltitude = 0
		else _radarAltitude = 1 end
		fuel = math.floor(fuel / 10) * 10
		if _radarAltitude == 0 then alt = math.floor(alt / 10) * 10 end
	end

	if _radarAltitude == 1 then
		alt = altG
	end

	if alt >= 10000 then
		alt = math.floor(alt / 100)
		_altitude = string.format("%3d ", alt)
	else _altitude = string.format("%4d", alt) end
	_altitudeG = string.format("%6d", altG)
	_altitudeS = string.format("%6d", altS)

	-- AOA
	if plane == "A-10A" then
		if aoa < 0 then aoa = 0
		elseif aoa > 30 then aoa = 30 end
	elseif plane == "F-15C" then
		if aoa < 0 then aoa = 0
		elseif aoa > 45 then aoa = 45 end
	else
		if aoa < -10 then aoa = -10
		elseif aoa > 40 then aoa = 40 end
	end
	if math.abs(aoa) >= 10 then _AoA = string.format(" %2d ", aoa)
	else _AoA = string.format("%4.1f", aoa) end

	if fuel > 100 then _fuel = string.format("%4d", fuel)
	else _fuel = string.format("%4.1f", fuel) end
     if _fuel == nil then return end
	 
	-- G LOAD
	if plane == "A-10A" then
		if gload < -5 then gload = -5
		elseif gload > 10 then gload = 10 end
	end
	if math.abs(gload) > 10 then _gLoad = string.format(" %2d ", gload)
	else _gLoad = string.format("%4.1f", gload) end
	_indicatedAirspeed = string.format("%4d", ias)

	-- MACH NUMBER
	if allowMach(plane) then
		if ( mach < 0.5 ) then mach = 0.5 end
		_machNumber = string.format("%4.2f", mach)
	end
	-- TAS
	if allowTAS(plane) then _trueAirspeed = string.format("%4d", tas) end

	if vvi >= 100 then _verticalVelocity = string.format("%4d", vvi)
	elseif vvi >= 10 then _verticalVelocity = string.format("%3d ", vvi)
	elseif vvi <= -10 then _verticalVelocity = string.format("%3d ", vvi)
	else _verticalVelocity = string.format("%4.1f", vvi) end

	_adiPitch, _adiBank, _adiYaw = LoGetADIPitchBankYaw()
end

--Altitude
defineString("FC3_ALTITUDE", function() return _altitude .. string.char(0) or "000000" end, 6, "Altitude", "Altitude")
defineString("FC3_ALTITUDE_GROUND", function() return _altitudeG .. string.char(0) or "000000" end, 6, "Altitude", "Altitude above Ground")
defineString("FC3_ALTITUDE_SEA", function() return _altitudeS .. string.char(0) or "000000"  end, 6, "Altitude", "Altitude above Sea Level")
defineString("FC3_ANGLE_OF_ATTACK", function() return _AoA .. string.char(0) or "0000" end, 4, "String", "Angle of Attack")
defineString("FC3_FUEL_ALL", function() return _fuel .. string.char(0) or "00000" end, 5, "String", "Fuel Remaining")
defineString("FC3_G_LOAD", function() return _gLoad .. string.char(0) or "0000" end, 4, "String", "G Load")
defineString("FC3_INDICATED_AIRSPEED", function() return _indicatedAirspeed .. string.char(0) or "0000" end, 4, "Speed", "Indicated Airspeed")
defineString("FC3_MACH_NUMBER", function() return _machNumber .. string.char(0) or "0000" end, 4, "Speed", "Mach Number")
defineString("FC3_TRUE_AIRSPEED", function() return _trueAirspeed .. string.char(0) or "0000" end, 4, "Speed", "True Airspeed")
defineString("FC3_VERTICAL_VELOCITY", function() return _verticalVelocity .. string.char(0) or "0000" end, 4, "Speed", "Vertical Velocity")
defineIntegerFromGetter("FC3_RADAR_ALTITUDE", function() return _radarAltitude end, 1, "Altitude", "Radar Altitude")

--Engine
-- defineString("FC3_RPM_L", function() return _RPMLeft .. string.char(0) or "00000" end, 5, "Engine", "RPM Left Engine")
-- defineString("FC3_RPM_R", function() return _RPMRight .. string.char(0) or "00000" end, 5, "Engine", "RPM Left Engine")
-- defineString("FC3_TEMP_L", function() return _TEMPLeft .. string.char(0) or "000" end, 3, "Engine", "Temperature Left Engine")
-- defineString("FC3_TEMP_R", function() return _TEMPRight .. string.char(0) or "000" end, 3, "Engine", "Temperature Left Engine")

--Mechanical
-- defineString("FC3_GEAR", function() return _GearStatus .. string.char(0) or "0" end, 1, "Mechanical", "Gear Status")

--Countermeasures
-- defineString("FC3_CHAFF", function() return _chaff .. string.char(0) or "000" end, 3, "Countermeasures", "Chaff Counter")
-- defineString("FC3_FLARE", function() return _flare .. string.char(0) or "000" end, 3, "Countermeasures", "Flare Counter")

--Bar
defineIntegerFromGetter("FC3_FUEL_BAR", function() return _barFuel end, 16, "Bar", "Fuel Bar")
defineIntegerFromGetter("FC3_G_LOAD_BAR", function() return _barGLoad end, 16, "Bar", "G Load Bar")
defineIntegerFromGetter("FC3_VVI_BAR", function() return _barVVI end, 16, "Bar", "Vertical Velocity Bar")

--Float
define8BitFloatFromGetter("FC3_ADI_BANK", function() return _adiBank or 0 end, {-1, 1}, "Float", "ADI Bank")
define8BitFloatFromGetter("FC3_ADI_PITCH", function() return _adiPitch or 0 end, {-1, 1}, "Float", "ADI Pitch")
define8BitFloatFromGetter("FC3_ADI_YAW", function() return _adiYaw or 0 end, {-1, 1}, "Float", "ADI Yaw")
define8BitFloatFromGetter("FC3_GLIDE_DEVIATION", function() return _glidedev or 0 end, {-1, 1}, "Float", "Glide Deviation")
define8BitFloatFromGetter("FC3_SIDE_DEVIATION", function() return _sidedev or 0 end, {-1, 1}, "Float", "Side Deviation")
define8BitFloatFromGetter("FC3_SLIP_BALL_POSITION", function() return _slipball or 0 end, {-1, 1}, "Float", "Slip Ball Position")

----Radar Warning
--defineIndicatorLight("RADAR_WARNING_POWER_1", 216, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_2", 215, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_3", 214, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_4", 213, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_5", 212, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_6", 211, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_7", 210, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_8", 209, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_9", 208, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_10", 207, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_11", 206, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_12", 205, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_13", 204, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_14", 203, "RADAR WARNING","POWER 1 INDICATE")
--defineIndicatorLight("RADAR_WARNING_POWER_14", 202, "RADAR WARNING","POWER 1 INDICATE")
--
--defineIndicatorLight("RADAR_WARNING_LEFT_10", 153, "RADAR WARNING","RIGHT 10 INDICATE")
--defineIndicatorLight("RADAR_WARNING_LEFT_30", 152, "RADAR WARNING","RIGHT 30 INDICATE")
--defineIndicatorLight("RADAR_WARNING_LEFT_50", 151, "RADAR WARNING","RIGHT 50 INDICATE")
--defineIndicatorLight("RADAR_WARNING_LEFT_90", 150, "RADAR WARNING","RIGHT 90 INDICATE")
--
--defineIndicatorLight("RADAR_WARNING_RIGHT_10", 154, "RADAR WARNING","RIGHT 10 INDICATE")
--defineIndicatorLight("RADAR_WARNING_RIGHT_30", 155, "RADAR WARNING","RIGHT 30 INDICATE")
--defineIndicatorLight("RADAR_WARNING_RIGHT_50", 156, "RADAR WARNING","RIGHT 50 INDICATE")
--defineIndicatorLight("RADAR_WARNING_RIGHT_90", 157, "RADAR WARNING","RIGHT 90 INDICATE")
--
--defineIndicatorLight("RADAR_WARNING_BACK_DIRECTION_LEFT", 158, "RADAR WARNING","BACK LEFT INDICATE")
--defineIndicatorLight("RADAR_WARNING_BACK_DIRECTION_RIGHT", 159, "RADAR WARNING","BACK RIGHT INDICATE")
--
--defineIndicatorLight("RADAR_WARNING_HIGHER_ELEVATION", 160, "RADAR WARNING","HIGHER INDICATE")
--defineIndicatorLight("RADAR_WARNING_LOWER_ELEVATION", 161, "RADAR WARNING","LOWER INDICATE")
--defineIndicatorLight("RADAR_WARNING_LAUNCH", 162, "RADAR WARNING","LAUNCH INDICATE")
--
--defineIndicatorLight("RADAR_WARNING_AUDIO_DISABLE", 163, "RADAR WARNING","AUDIO DISABLE INDICATE")
--
--defineIndicatorLight("RADAR_WARNING_THREAT_AIRBORNE", 164, "RADAR WARNING","AIRBORNE THREAT INDICATE")
--defineIndicatorLight("RADAR_WARNING_THREAT_LONG_RANGE", 165, "RADAR WARNING","LONG RANGE THREAT INDICATE")
--defineIndicatorLight("RADAR_WARNING_THREAT_MEDIUM_RANGE", 166, "RADAR WARNING","MEDIUM RANGE THREAT INDICATE")
--defineIndicatorLight("RADAR_WARNING_THREAT_SHORT_RANGE", 167, "RADAR WARNING","SHORT RANGE THREAT INDICATE")
--defineIndicatorLight("RADAR_WARNING_THREAT_EARLY_WARNING", 168, "RADAR WARNING","EARLY WARNING THREAT INDICATE")
--defineIndicatorLight("RADAR_WARNING_THREAT_AWACS", 169, "RADAR WARNING","AWACS THREAT INDICATE")
--
----Engine
--defineIndicatorLight("ENGINE_TURBO_LEFT", 244, "ENGINE","TURBO LEFT")
--defineIndicatorLight("ENGINE_TURBO_RIGHT", 245, "ENGINE","TURBO RIGHT")


--Externals
defineIntegerFromGetter("EXT_SPEED_BRAKE_RIGHT", function()
	return math.floor(LoGetAircraftDrawArgumentValue(182)*65535)
end, 65535, "External Aircraft Model", "Right Speed Brake")
defineIntegerFromGetter("EXT_SPEED_BRAKE_LEFT", function()
	return math.floor(LoGetAircraftDrawArgumentValue(184)*65535)
end, 65535, "External Aircraft Model", "Left Speed Brake")

defineIntegerFromGetter("EXT_POSITION_LIGHT_LEFT", function()
	if LoGetAircraftDrawArgumentValue(190) > 0 then return 1 else return 0 end
end, 1, "External Aircraft Model", "Left Position Light (red)")
defineIntegerFromGetter("EXT_POSITION_LIGHT_RIGHT", function()
	if LoGetAircraftDrawArgumentValue(191) > 0 then return 1 else return 0 end
end, 1, "External Aircraft Model", "Right Position Light (green)")
defineIntegerFromGetter("EXT_STROBE", function()
	if LoGetAircraftDrawArgumentValue(192) > 0 then return 1 else return 0 end
end, 1, "External Aircraft Model", "Strobe Light")

defineIntegerFromGetter("EXT_WOW_NOSE", function()
	if LoGetAircraftDrawArgumentValue(1) > 0 then return 1 else return 0 end
end, 1, "External Aircraft Model", "Weight ON Wheels Nose Gear")
defineIntegerFromGetter("EXT_WOW_RIGHT", function()
	if LoGetAircraftDrawArgumentValue(4) > 0 then return 1 else return 0 end
end, 1, "External Aircraft Model", "Weight ON Wheels Right Gear")
defineIntegerFromGetter("EXT_WOW_LEFT", function()
	if LoGetAircraftDrawArgumentValue(6) > 0 then return 1 else return 0 end
end, 1, "External Aircraft Model", "Weight ON Wheels Left Gear")

BIOS.protocol.endModule()