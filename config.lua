-----------------------------------------------------
---- For more scripts and updates, visit ------------
--------- https://discord.gg/trase ------------------
-----------------------------------------------------
Config = {}
Config.Framework = 'auto' -- 'auto', 'esx', 'qb', 'qbx'
Config.DrawDistance = 25.0 -- Distance to draw markers

Config.Blips = {
    Garages = {
        Enabled = true,
        Sprite = 357,
        Color = 3,
        Scale = 0.7,
        Name = 'Garage'
    },
    Impounds = {
        Enabled = true,
        Sprite = 524,
        Color = 47,
        Scale = 0.7,
        Name = 'Impound'
    }
}

Config.Garages = { -- Add as many as you want
    ['Legion'] = {
        Enter = vec3(215.1587, -809.5308, 30.7485),
        Browse = vec4(230.8425, -795.6925, 30.5864, 161.3799),
        Store = vec3(214.6054, -792.4926, 30.8434)
    }
}

Config.Impound = { -- Add as many as you want
    Enabled = true, -- Enable/Disable impound system
    Price = 2500, -- Price to retrieve impounded vehicle
    Locations = {
        ['Hayes Auto'] = {
            Enter = vec3(484.0731, -1312.2666, 29.2153),
            Browse = vec4(490.5146, -1313.6351, 29.2581, 304.4655)
        }
    }
}