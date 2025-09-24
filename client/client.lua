-----------------------------------------------------
---- For more scripts and updates, visit ------------
--------- https://discord.gg/trase ------------------
-----------------------------------------------------

local vehicles, preview = {}, nil
local browsing, index, activeGarage = false, 1, nil
local enterRadius, storeEnterRadius = 1.6, 3.0
local markerScale, storeMarkerScale = vec3(0.9,0.9,0.9), vec3(4.0,4.0,0.4)

local function showHelpMessage(msg)
    if not msg or msg == '' then return end
    AddTextEntry("trase:garage:message", msg)
    BeginTextCommandDisplayHelp("trase:garage:message")
    EndTextCommandDisplayHelp(0, false, nil, -1)
end

local function drawMarkerAt(pos, scale)
    DrawMarker(1, pos.x, pos.y, pos.z - 0.98, 0,0,0, 0,0,0, scale.x, scale.y, scale.z, 0,153,255,140, false,false,2,false,nil,nil,false)
end

local function loadModel(name)
    local m = type(name)=='string' and joaat(name) or name
    if not m or not IsModelValid(m) then return end
    if not HasModelLoaded(m) then
        RequestModel(m)
        while not HasModelLoaded(m) do Wait(0) end
    end
    return m
end

local function clearPreview()
    if preview and DoesEntityExist(preview) then
        SetEntityAsMissionEntity(preview,true,true)
        DeleteVehicle(preview)
    end
    preview = nil
end

local function concealSelf(toggle)
    local ped = PlayerPedId()
    NetworkConcealEntity(ped, toggle)
    SetEntityVisible(ped, true, false)
end

local function seatLocal(vehicleData, pos, setProps)
    DoScreenFadeOut(100); Wait(100)
    clearPreview()
    local info = vehicleData and json.decode(vehicleData.vehicle or '{}') or {}
    local model = info.model and (type(info.model)=='string' and joaat(info.model) or info.model) or nil
    local m = loadModel(model)
    if not m then
        DoScreenFadeIn(100)
        lib.notify({ title = locale('ui.garage'), description = locale('error.load_model'), type = 'error' })
        return
    end
    preview = CreateVehicle(m, pos.x, pos.y, pos.z, pos.w, false, false)
    if setProps and next(info) then pcall(function() lib.setVehicleProperties(preview, info) end) end
    if vehicleData and vehicleData.plate then SetVehicleNumberPlateText(preview, vehicleData.plate) end
    SetVehicleDoorsLocked(preview, 4)
    SetVehicleEngineOn(preview, false, true, false)
    SetEntityInvincible(preview, true)
    SetVehicleUndriveable(preview, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), preview, -1)
    SetModelAsNoLongerNeeded(m)
    DoScreenFadeIn(100)
end

local function spawnNetwork(info, plate, pos)
    local model = info and (type(info.model)=='string' and joaat(info.model) or info.model)
    local m = loadModel(model); if not m then return end
    local v = CreateVehicle(m, pos.x, pos.y, pos.z, pos.w, true, false)
    if plate then SetVehicleNumberPlateText(v, plate) end
    if info and next(info) then pcall(function() lib.setVehicleProperties(v, info) end) end
    SetVehicleOnGroundProperly(v)
    TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)
    SetVehicleDoorsLocked(v, 1)
    SetVehicleUndriveable(v, false)
    SetEntityInvincible(v, false)
    SetVehicleEngineOn(v, true, true, false)
    SetModelAsNoLongerNeeded(m)
end

local function browseLoop(helpFn, leftFn, rightFn, confirmFn, cancelFn)
    while browsing do
        Wait(0)
        if preview and DoesEntityExist(preview) then helpFn() end
        if IsControlJustPressed(0, 174) then leftFn() end
        if IsControlJustPressed(0, 175) then rightFn() end
        if IsControlJustPressed(0, 191) then confirmFn() break end
        if IsControlJustPressed(0, 177) then cancelFn() break end
    end
end

local function startGarageBrowse(key)
    local g = Config.Garages[key]; if not g then return end
    lib.callback('trase_garage:getVehicles', false, function(list)
        vehicles = list or {}
        if not next(vehicles) then
            lib.notify({ title = locale('ui.garage'), description = locale('error.no_owned'), type = 'error' })
            return
        end
        activeGarage, browsing, index = key, true, 1
        SetEntityCoordsNoOffset(PlayerPedId(), g.Browse.x, g.Browse.y, g.Browse.z, false, false, false)
        SetEntityHeading(PlayerPedId(), g.Browse.w)
        concealSelf(true)
        seatLocal(vehicles[index], g.Browse, true)

        local function help()
            local name = GetDisplayNameFromVehicleModel(GetEntityModel(preview)) or 'N/A'
            local plate = GetVehicleNumberPlateText(preview) or '---'
            showHelpMessage((locale('help.browse')):format(name, plate))
        end
        local function left()
            index = index <= 1 and #vehicles or index - 1
            seatLocal(vehicles[index], g.Browse, true)
        end
        local function right()
            index = index >= #vehicles and 1 or index + 1
            seatLocal(vehicles[index], g.Browse, true)
        end
        local function confirm()
            browsing = false
            clearPreview()
            concealSelf(false)
            local v = vehicles[index]; if not v then return end
            local ok = lib.callback.await('trase_garage:pullOutVehicle', false, v.plate)
            if ok == true then
                spawnNetwork(json.decode(v.vehicle or '{}'), v.plate, g.Browse)
            else
                if ok == 'not_owner' then
                    lib.notify({ title=locale('ui.garage'), description=locale('error.not_owner'), type='error' })
                elseif ok == 'not_stored' then
                    lib.notify({ title=locale('ui.garage'), description=locale('error.already_out'), type='error' })
                else
                    lib.notify({ title=locale('ui.garage'), description=locale('error.pull_fail'), type='error' })
                end
            end
            activeGarage = nil
        end
        local function cancel()
            browsing = false
            clearPreview()
            concealSelf(false)
            activeGarage = nil
        end

        browseLoop(help, left, right, confirm, cancel)
    end)
end

local function startImpoundBrowse(locKey, loc)
    lib.callback('trase_garage:getImpoundedVehicles', false, function(list)
        if not list or not next(list) then
            lib.notify({ title = locale('ui.impound'), description = locale('error.no_impounded'), type = 'error' })
            return
        end
        local ped = PlayerPedId()
        local price = (Config.Impound and Config.Impound.Price) or 0
        browsing, index = true, 1
        SetEntityCoordsNoOffset(ped, loc.Browse.x, loc.Browse.y, loc.Browse.z, false, false, false)
        SetEntityHeading(ped, loc.Browse.w)
        concealSelf(true)
        seatLocal(list[index], loc.Browse, true)

        local function help()
            local name = GetDisplayNameFromVehicleModel(GetEntityModel(preview)) or 'N/A'
            local plate = GetVehicleNumberPlateText(preview) or '---'
            showHelpMessage((locale('help.impound')):format(price, name, plate))
        end
        local function left()
            index = index <= 1 and #list or index - 1
            seatLocal(list[index], loc.Browse, true)
        end
        local function right()
            index = index >= #list and 1 or index + 1
            seatLocal(list[index], loc.Browse, true)
        end
        local function confirm()
            browsing = false
            local v = list[index]; if not v then return end
            local ok = lib.callback.await('trase_garage:releaseImpound', false, v.plate, price, locKey)
            clearPreview()
            concealSelf(false)
            if ok == true then
                spawnNetwork(json.decode(v.vehicle or '{}'), v.plate, loc.Browse)
                lib.notify({ title=locale('ui.impound'), description=locale('success.retrieved'), type='success' })
            else
                if ok == 'insufficient_funds' then
                    lib.notify({ title=locale('ui.impound'), description=locale('error.no_money'), type='error' })
                else
                    lib.notify({ title=locale('ui.impound'), description=locale('error.retrieve_fail'), type='error' })
                end
            end
        end
        local function cancel()
            browsing = false
            clearPreview()
            concealSelf(false)
        end

        browseLoop(help, left, right, confirm, cancel)
    end)
end

for key, g in pairs(Config.Garages or {}) do
    local enterPoint = lib.points.new(g.Enter, Config.DrawDistance or 25.0, { key = key })
    function enterPoint:nearby()
        drawMarkerAt(g.Enter, markerScale)
        if self.currentDistance <= enterRadius and not browsing then
            showHelpMessage(locale('help.open_garage'))
            if IsControlJustPressed(0, 38) then startGarageBrowse(self.key) end
        end
    end

    if Config.Blips and Config.Blips.Garages and Config.Blips.Garages.Enabled then
        local blip = AddBlipForCoord(g.Enter.x, g.Enter.y, g.Enter.z)
        SetBlipSprite(blip, Config.Blips.Garages.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blips.Garages.Scale)
        SetBlipColour(blip, Config.Blips.Garages.Color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.Blips.Garages.Name or "Garage")
        EndTextCommandSetBlipName(blip)
    end

    if g.Store then
        local storePoint = lib.points.new(g.Store, Config.DrawDistance or 25.0, { key = key })
        function storePoint:nearby()
            drawMarkerAt(g.Store, storeMarkerScale)
            if self.currentDistance <= storeEnterRadius and not browsing then
                showHelpMessage(locale('help.store'))
                if IsControlJustPressed(0, 38) then
                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) == ped then
                        local veh = GetVehiclePedIsIn(ped, false)
                        local ok = lib.callback.await('trase_garage:storeVehicle', false, self.key, lib.getVehicleProperties(veh))
                        if ok == true then
                            SetEntityAsMissionEntity(veh, true, true)
                            DeleteVehicle(veh)
                            lib.notify({ title=locale('ui.garage'), description=locale('success.stored'), type='success' })
                        elseif ok == 'not_owner' then
                            lib.notify({ title=locale('ui.garage'), description=locale('error.not_owner'), type='error' })
                        elseif ok == 'already_stored' then
                            lib.notify({ title=locale('ui.garage'), description=locale('error.already_stored'), type='error' })
                        else
                            lib.notify({ title=locale('ui.garage'), description=locale('error.store_fail'), type='error' })
                        end
                    else
                        lib.notify({ title=locale('ui.garage'), description=locale('error.driver_only'), type='error' })
                    end
                end
            end
        end
    end
end

if Config.Impound and Config.Impound.Enabled and Config.Impound.Locations then
    for k, p in pairs(Config.Impound.Locations) do
        if Config.Blips and Config.Blips.Impounds and Config.Blips.Impounds.Enabled then
            local blip = AddBlipForCoord(p.Enter.x, p.Enter.y, p.Enter.z)
            SetBlipSprite(blip, Config.Blips.Impounds.Sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blips.Impounds.Scale)
            SetBlipColour(blip, Config.Blips.Impounds.Color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(Config.Blips.Impounds.Name or "Impound")
            EndTextCommandSetBlipName(blip)
        end
        local impEnter = lib.points.new(p.Enter, Config.DrawDistance or 25.0, { key = k })
        function impEnter:nearby()
            drawMarkerAt(p.Enter, markerScale)
            if self.currentDistance <= enterRadius and not browsing then
                showHelpMessage(locale('help.open_impound'))
                if IsControlJustPressed(0, 38) then startImpoundBrowse(self.key, p) end
            end
        end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearPreview()
    concealSelf(false)
    lib.hideTextUI()
end)

lib.locale()