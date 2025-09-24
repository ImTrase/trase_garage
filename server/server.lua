-----------------------------------------------------
---- For more scripts and updates, visit ------------
--------- https://discord.gg/trase ------------------
-----------------------------------------------------

lib.callback.register('trase_garage:getVehicles', function()
    local vehicles = GetOwnedVehicles(source)
    if not vehicles then vehicles = {} end
    return vehicles
end)

lib.callback.register('trase_garage:storeVehicle', function(source, garage, props)
    local vehicleStored = StoreVehicle(source, garage, props)
    return vehicleStored
end)

lib.callback.register('trase_garage:pullOutVehicle', function(source, plate)
    local result = PullOutVehicle(source, plate)
    return result
end)

lib.callback.register('trase_garage:getImpoundedVehicles', function(source)
    local vehicles = GetImpoundedVehicles(source)
    if not vehicles then vehicles = {} end
    return vehicles
end)

lib.callback.register('trase_garage:releaseImpound', function(source, plate)
    local result = ReleaseImpound(source, plate)
    return result
end)