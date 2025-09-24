-----------------------------------------------------
---- For more scripts and updates, visit ------------
--------- https://discord.gg/trase ------------------
-----------------------------------------------------

if Config.Framework == 'qb' or Config.Framework == 'auto' then
    if GetResourceState('qb-core') == 'started' then
        Config.Framework = 'qb'
        print('^4[Trase_Garage] ^3[INFO]^0: QBCore detected and set.')
    end
end

if Config.Framework ~= 'qb' then
    print('^4[Trase_Garage] ^1[ERROR]^0: QBCore not active.')
    return
end

local QBCore = exports['qb-core']:GetCoreObject()
if not QBCore then
    print('^4[Trase_Garage] ^1[ERROR]^0: Failed to get QBCore object.')
    return
end

local function CID(p) return p and p.PlayerData and p.PlayerData.citizenid or nil end

function GetPlayer(serverId)
    local src = tonumber(serverId)
    local p = QBCore.Functions.GetPlayer(src)
    if not p then
        print(('^4[Trase_Garage] ^1[ERROR]^0: Failed to get player %s'):format(serverId))
        return nil
    end
    return p
end

function GetOwnedVehicles(serverId)
    local p = GetPlayer(serverId)
    if not p then return {} end
    local query = 'SELECT plate, mods, state FROM player_vehicles WHERE citizenid = @cid'
    if Config.Impound and Config.Impound.Enabled then
        query = query .. ' AND state = 1'
    end
    local result = MySQL.Sync.fetchAll(query, { ['@cid'] = CID(p) })
    local vehicles = {}
    for i=1, #result do
        vehicles[#vehicles+1] = {
            vehicle = result[i].mods,
            plate   = result[i].plate,
            stored  = (tonumber(result[i].state) == 1)
        }
    end
    return vehicles
end

function StoreVehicle(serverId, garage, props)
    local p = GetPlayer(serverId)
    if not p then return false end
    local plate = (props.plate or ''):upper():gsub('%s+$','')
    local row = MySQL.Sync.fetchAll(
        'SELECT state FROM player_vehicles WHERE citizenid = @cid AND plate = @plate LIMIT 1',
        { ['@cid'] = CID(p), ['@plate'] = plate }
    )[1]
    if not row then return 'not_owner' end
    if tonumber(row.state) == 1 then return 'already_stored' end
    local affected = MySQL.Sync.execute(
        'UPDATE player_vehicles SET state = 1, mods = @mods, garage = @garage WHERE citizenid = @cid AND plate = @plate',
        { ['@cid']=CID(p), ['@plate']=plate, ['@mods']=json.encode(props), ['@garage']=garage }
    )
    return affected > 0
end

function PullOutVehicle(serverId, plate)
    local p = GetPlayer(serverId)
    if not p then return false end
    plate = (plate or ''):upper():gsub('%s+$','')
    local row = MySQL.Sync.fetchAll(
        'SELECT state FROM player_vehicles WHERE citizenid = @cid AND plate = @plate LIMIT 1',
        { ['@cid'] = CID(p), ['@plate'] = plate }
    )[1]
    if not row then return 'not_owner' end
    if tonumber(row.state) == 0 then return 'already_out' end
    local affected = MySQL.Sync.execute(
        'UPDATE player_vehicles SET state = 0 WHERE citizenid = @cid AND plate = @plate',
        { ['@cid']=CID(p), ['@plate']=plate }
    )
    return affected > 0
end

function GetImpoundedVehicles(serverId)
    local p = GetPlayer(serverId)
    if not p then return {} end
    local result = MySQL.Sync.fetchAll(
        'SELECT plate, mods, state FROM player_vehicles WHERE citizenid = @cid AND state = 0',
        { ['@cid'] = CID(p) }
    )
    local vehicles = {}
    for i=1, #result do
        vehicles[#vehicles+1] = {
            vehicle = result[i].mods,
            plate   = result[i].plate,
            stored  = (tonumber(result[i].state) == 1)
        }
    end
    return vehicles
end

function ReleaseImpound(serverId, plate)
    local p = GetPlayer(serverId)
    if not p then return false end
    plate = (plate or ''):upper():gsub('%s+$','')
    local row = MySQL.Sync.fetchAll(
        'SELECT state FROM player_vehicles WHERE citizenid = @cid AND plate = @plate LIMIT 1',
        { ['@cid'] = CID(p), ['@plate'] = plate }
    )[1]
    if not row then return 'not_owner' end
    if tonumber(row.state) == 1 then return 'already_out' end

    if Config.Impound.Price > 0 then
        local price = tonumber(Config.Impound.Price) or 0
        local cash  = p.Functions.GetMoney('cash')
        local bank  = p.Functions.GetMoney('bank')
        if cash + bank < price then return 'insufficient_funds' end
        local takeCash = math.min(cash, price)
        if takeCash > 0 then p.Functions.RemoveMoney('cash', takeCash, 'impound-release') end
        local remain = price - takeCash
        if remain > 0 then p.Functions.RemoveMoney('bank', remain, 'impound-release') end
    end

    local affected = MySQL.Sync.execute(
        'UPDATE player_vehicles SET state = 1, garage = NULL WHERE citizenid = @cid AND plate = @plate',
        { ['@cid']=CID(p), ['@plate']=plate }
    )
    return affected > 0
end
