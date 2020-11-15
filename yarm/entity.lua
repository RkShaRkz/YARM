require 'libs/yutil'

if yarm == nil then yarm = {} end

local P = {}
yarm.entity = P

P.persisted_members = {}

table.insert(P.persisted_members, 'spawned_ents')
P.spawned_ents = {
    -- array of LuaEntity
}

table.insert(P.persisted_members, 'infinite_resource_names')
P.infinite_resource_names = {}

local function init_infinite_resources()
    local resource_protos = game.get_filtered_entity_prototypes({{filter = "type", type = "resource"}})
    for name, proto in pairs(resource_protos) do
        if proto.infinite_resource then
            P.infinite_resource_names[name] = true
        end
    end
end

function P.on_init()
    init_infinite_resources()
end

function P.on_configuration_changed()
    init_infinite_resources()
end

function P.is_infinite_resource(name)
    return P.infinite_resource_names[name] or false -- don't really want to return nil, who knows what shit could happen
end

function P.infinite_resources()
    local current = nil
    return function ()
        current = next(P.infinite_resource_names, current)
        return current
    end
end

--- Spawn an entity and remember it in `spawned_ents` for later
function P.spawn(surface, name, position, force, extra_opts)
    local base_opts = {
        name = name,
        position = position,
        force = force,
        create_build_effect_smoke = false,
    }

    local ent = surface.create_entity(yutil.table_merge(base_opts, extra_opts))
    table.insert(P.spawned_ents, ent)
    return ent
end

P.BASIC_MONITOR_NAME = 'yarm-monitor-basic'
P.WIRELESS_MONITOR_NAME = 'yarm-monitor-wireless'
P.INVISIBLE_POLE_NAME = 'yarm-invisible-electric-pole'
P.MONITOR_NAMES = {
    P.BASIC_MONITOR_NAME, P.WIRELESS_MONITOR_NAME
}

--- Entry point: when a monitor is built/revived/whatever
-- Spawns an invisible pole on top of the monitor and connects them with red
-- wire. Then tells the monitor module about both entities.
function P.on_built_monitor(e)
    if not yutil.contains(P.MONITOR_NAMES, e.created_entity.name) then
        return
    end
    if not e.created_entity.valid then return end

    local mon = e.created_entity
    local pole = yarm.entity.spawn(mon.surface, P.INVISIBLE_POLE_NAME, mon.position, mon.force)
    pole.disconnect_neighbour()

    local connected = pole.connect_neighbour{ wire = defines.wire_type.red, target_entity = mon }
    if not connected then
        error("Failed to connect invisible pole to monitor!")
    end

    yarm.monitor.add(mon, pole)
end

local BUILT_EVENTS = {
    defines.events.on_built_entity,
    defines.events.on_entity_cloned,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
}
for _, evname in pairs(BUILT_EVENTS) do
    yarm.on_event(evname, P.on_built_monitor,
        yutil.materialize(yutil.select(P.MONITOR_NAMES, function (mon_name)
            return { filter = 'name', name = mon_name }
        end)))
end

return P
