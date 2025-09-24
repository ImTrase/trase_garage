-----------------------------------------------------
---- For more scripts and updates, visit ------------
--------- https://discord.gg/trase ------------------
-----------------------------------------------------

if Config.Framework == 'esx' or Config.Framework == 'auto' then
    if GetResourceState('es_extended') == 'started' then
        Config.Framework = 'esx'
        print('^4[Trase_Garage] ^3[INFO]^0: ESX framework detected and set.')
    end
end

ESX = exports['es_extended']:getSharedObject()
if not ESX then
    print('^4[Trase_Garage] ^1[ERROR]^0: Failed to get ESX object. Make sure es_extended is running.')
    return
end

function GetPlayer(serverId)
    local xPlayer = ESX.GetPlayerFromId(serverId)
    if not xPlayer then
        print('^4[Trase_Garage] ^1[ERROR]^0: Failed to get player with server ID ' .. serverId)
        return nil
    end
    return xPlayer
end

function GetOwnedVehicles(serverId)
    local xPlayer = GetPlayer(serverId)
    if not xPlayer then return {} end

    local query = 'SELECT plate, vehicle, stored FROM owned_vehicles WHERE owner = @owner'
    if Config.Impound and Config.Impound.Enabled then
        query = query .. ' AND stored = 1'
    end

    local result = MySQL.Sync.fetchAll(query, {
        ['@owner'] = xPlayer.identifier
    })

    local vehicles = {}
    for i=1, #result do
        vehicles[#vehicles+1] = {
            vehicle = result[i].vehicle,
            plate   = result[i].plate,
            stored  = (result[i].stored == 1)
        }
    end
    return vehicles
end

function StoreVehicle(serverId, garage, props)
    local xPlayer = GetPlayer(serverId)
    if not xPlayer then return false end

    local plate = (props.plate or ''):upper():gsub('%s+$','')
    local row = MySQL.Sync.fetchAll(
        'SELECT stored FROM owned_vehicles WHERE owner = @owner AND plate = @plate LIMIT 1',
        { ['@owner'] = xPlayer.identifier, ['@plate'] = plate }
    )[1]
    if not row then return 'not_owner' end
    if tonumber(row.stored) == 1 then return 'already_stored' end

    local affected = MySQL.Sync.execute(
        'UPDATE owned_vehicles SET stored = 1, vehicle = @vehicle, parking = @garage WHERE owner = @owner AND plate = @plate',
        {
            ['@owner'] = xPlayer.identifier,
            ['@plate'] = plate,
            ['@vehicle'] = json.encode(props),
            ['@garage'] = garage
        }
    )

    return affected > 0
end

function PullOutVehicle(serverId, plate)
    local xPlayer = GetPlayer(serverId)
    if not xPlayer then return false end

    plate = (plate or ''):upper():gsub('%s+$','')
    local row = MySQL.Sync.fetchAll(
        'SELECT stored FROM owned_vehicles WHERE owner = @owner AND plate = @plate LIMIT 1',
        { ['@owner'] = xPlayer.identifier, ['@plate'] = plate }
    )[1]
    if not row then return 'not_owner' end
    if tonumber(row.stored) == 0 then return 'already_out' end

    local affected = MySQL.Sync.execute(
        'UPDATE owned_vehicles SET stored = 0 WHERE owner = @owner AND plate = @plate',
        {
            ['@owner'] = xPlayer.identifier,
            ['@plate'] = plate
        }
    )

    return affected > 0
end

function GetImpoundedVehicles(serverId)
    local xPlayer = GetPlayer(serverId)
    if not xPlayer then return {} end

    local result = MySQL.Sync.fetchAll(
        'SELECT plate, vehicle, stored FROM owned_vehicles WHERE owner = @owner AND stored = 0',
        { ['@owner'] = xPlayer.identifier }
    )

    local vehicles = {}
    for i = 1, #result do
        vehicles[#vehicles + 1] = {
            vehicle = result[i].vehicle,
            plate   = result[i].plate,
            stored  = (result[i].stored == 1)
        }
    end
    return vehicles
end

function ReleaseImpound(serverId, plate)
    local xPlayer = GetPlayer(serverId)
    if not xPlayer then return false end

    plate = (plate or ''):upper():gsub('%s+$','')
    local row = MySQL.Sync.fetchAll(
        'SELECT stored FROM owned_vehicles WHERE owner = @owner AND plate = @plate LIMIT 1',
        { ['@owner'] = xPlayer.identifier, ['@plate'] = plate }
    )[1]
    if not row then return 'not_owner' end
    if tonumber(row.stored) == 1 then return 'already_out' end

    if Config.Impound.Price > 0 then
        if xPlayer.getMoney() < Config.Impound.Price then
            return 'insufficient_funds'
        end
        xPlayer.removeMoney(Config.Impound.Price)
    end

    local affected = MySQL.Sync.execute(
        'UPDATE owned_vehicles SET stored = 1, parking = NULL WHERE owner = @owner AND plate = @plate',
        {
            ['@owner'] = xPlayer.identifier,
            ['@plate'] = plate
        }
    )

    return affected > 0
end