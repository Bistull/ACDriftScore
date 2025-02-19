---@ext
ConfigFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/DriftScoring/" .. "settings.ini")
DisplayScale = ConfigFile:get("settings", "displayscale", 1)
BoardScale = ConfigFile:get("settings", "boardscale", 1)
AngleScale = ConfigFile:get("settings", "anglescale", 1)
ShowPraises = ConfigFile:get("settings", "showpraises", true)
LapScoringEnabled = ConfigFile:get("settings", "lapscoring", true)
ConfigFile:set("settings", "displayscale", DisplayScale)
ConfigFile:set("settings", "boardscale", BoardScale)
ConfigFile:set("settings", "anglescale", AngleScale)
ConfigFile:set("settings", "showpraises", ShowPraises)
ConfigFile:set("settings", "lapscoring", LapScoringEnabled)
ConfigFile:save()

CurrentDriftTime = 0
CurrentDriftTimeout = 2
CurrentDriftScore = 0
CurrentDriftCombo = 1
TotalScore = 0
TotalScoreTarget = 0
BestDrift = 0
BestDriftTarget = 0
BestLapScore = 0
BestLapScoreTarget = 0
SecondsTimer = 0
UpdatesTimer = 0
LongDriftTimer = 0
NoDriftTimer = 0
SplineReached = 0
CurrentLapScoreCut = false
CurrentLapScoreCutValue = 0
CurrentLapScore = 0
CurrentLapScoreTarget = 0
SubmittedLapDriftScore = 0

ExtraScore = false
ExtraScoreMultiplier = 1
InitialScoreMultiplier = 0
NearestCarDistance = 1

local TrackHasSpline = ac.hasTrackSpline() and LapScoringEnabled
ac.log("TrackHasSpline", TrackHasSpline)

RecordsFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/DriftScoring/" .. "data.ini")
RecordDrift = 0
RecordDriftTarget = RecordsFile:get(ac.getCarID(0) .. "_" .. ac.getTrackFullID("_"), "recorddrift", 0)
RecordBestLap = 0
RecordBestLapTarget = RecordsFile:get(ac.getCarID(0) .. "_" .. ac.getTrackFullID("_"), "recordlap", 0)

ComboReached = 0

NoWarning = true

Sim = ac.getSim()
Car = ac.getCar(0)

local angle
local dirt

function getNearbyCarDistance()
    PlayerCarPos = ac.getCar(Car.index).position
    local lowestDist = 9999999
    for i = 1,9999 do
        if ac.getCar(i) and i ~= 0 then
            local distance = math.distance(ac.getCar(0).position, ac.getCar(i).position)
            if distance < lowestDist and (not ac.getCar(i).isInPit) and (not ac.getCar(i).isInPitlane) and ac.getCar(i).isConnected then
                lowestDist = distance
            end
        elseif not ac.getCar(i) then
            break
        end
    end
    return lowestDist
end

function script.update(dt)
    Sim = ac.getSim()
    Car = ac.getCar(0)
    if not Sim.isPaused then
        SecondsTimer = SecondsTimer + dt
        UpdatesTimer = UpdatesTimer + 1
        angle = math.max(0, ((math.max(math.abs(Car.wheels[2].slipAngle), math.abs(Car.wheels[3].slipAngle))))))

        if (Car.localVelocity.z <= 0 and Car.speedKmh > 1) then
            angle = 180 - angle
        end
        dirt = math.min(math.abs(Car.wheels[0].surfaceDirt), math.abs(Car.wheels[1].surfaceDirt), math.abs(Car.wheels[2].surfaceDirt), math.abs(Car.wheels[3].surfaceDirt))

        if angle > 10 and Car.speedKmh > 20 and dirt == 0 and Car.wheelsOutside < 4 and ((not TrackHasSpline) or Car.splinePosition >= SplineReached - 0.0001) then
            CurrentDriftTimeout = math.min(1, CurrentDriftTimeout + dt)
            CurrentDriftScore = CurrentDriftScore + (((((angle - 10) * 10 + (Car.speedKmh - 20) * 10) * 0.5) * dt * CurrentDriftCombo)) * ExtraScoreMultiplier * InitialScoreMultiplier * 0.2
            CurrentDriftCombo = math.min(5, CurrentDriftCombo + (((((angle - 10) + (Car.speedKmh - 20)) * 0.5) * dt) / 100) * ExtraScoreMultiplier * InitialScoreMultiplier * 0.5)
            LongDriftTimer = LongDriftTimer + dt
            NoDriftTimer = 0.5
            InitialScoreMultiplier = math.min(1, LongDriftTimer)
            if ComboReached < CurrentDriftCombo then
                ComboReached = CurrentDriftCombo
            end
        elseif CurrentDriftCombo > 1 then
            CurrentDriftTimeout = math.min(1, CurrentDriftTimeout + dt)
            CurrentDriftCombo = math.max(1, CurrentDriftCombo - 0.1 * (NoDriftTimer ^ 2) * dt)
            NoDriftTimer = NoDriftTimer + dt
            LongDriftTimer = 0
        elseif CurrentDriftCombo == 1 and CurrentDriftTimeout > 0 then
            CurrentDriftTimeout = CurrentDriftTimeout - dt
            NoDriftTimer = NoDriftTimer + dt
            LongDriftTimer = 0
        elseif CurrentDriftTimeout <= 0 then
            CurrentDriftTimeout = 0
            LongDriftTimer = 0
            NoDriftTimer = NoDriftTimer + dt
            if NoWarning then
                if CurrentDriftScore > 0 then
                    TotalScoreTarget = TotalScoreTarget + math.floor(CurrentDriftScore)
                    if TrackHasSpline then
                        SubmittedLapDriftScore = SubmittedLapDriftScore + math.max(0, math.floor(CurrentDriftScore))
                    end
                    if math.floor(CurrentDriftScore) > BestDriftTarget then
                        BestDriftTarget = math.floor(CurrentDriftScore)
                    end
                end
            end
            CurrentDriftScore = 0
            CurrentDriftCombo = 1
            ComboReached = 0
        end
        -- Continue with the rest of the code...
    end
end

function script.windowDisplay()
    ui.beginOutline()
    ui.pushDWriteFont('OPTIEdgarBold:\\Fonts;Weight=Medium')

    local baseColor = rgbm(1, 1, 1, 1)  -- White color for text
    local highlightColor = rgbm(0, 1, 0, 1)  -- Green color for good results
    local errorColor = rgbm(1, 0, 0, 1)  -- Red for warnings

    -- Displaying the drift combo
    if CurrentDriftCombo > 1 then
        ui.dwriteText("Combo: x" .. math.ceil(CurrentDriftCombo * 10) / 10, 30 * DisplayScale, highlightColor)
    else
        ui.dwriteText("Combo: x" .. math.ceil(CurrentDriftCombo * 10) / 10, 30 * DisplayScale, baseColor)
    end

    -- Displaying drift score
    if CurrentDriftScore > 5000 then
        ui.dwriteText("Drift Score: " .. math.floor(CurrentDriftScore), 40 * DisplayScale, highlightColor)
    else
        ui.dwriteText("Drift Score: " .. math.floor(CurrentDriftScore), 40 * DisplayScale, baseColor)
    end

    -- Displaying speed warnings
    if Car.speedKmh <= 20 then
        ui.dwriteText("TOO SLOW!", 20 * DisplayScale, errorColor)
    end

    -- Displaying off-track warnings
    if dirt > 0 or Car.wheelsOutside == 4 then
        ui.dwriteText("OFF-TRACK!", 20 * DisplayScale, errorColor)
    end

    ui.endOutline(0, 1.5)
    ui.popDWriteFont()
end
