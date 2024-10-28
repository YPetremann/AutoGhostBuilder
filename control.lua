local ghost_builder_enabled = {}

--- try to set the ghost builder enabled state for a player
--- @param player any
--- @param value any
local function set_ghost_builder_enabled(player, value)
    ghost_builder_enabled[player.index] = value
    pcall(function()
        player.set_shortcut_toggled("ghost-builder-togglse", value)
    end)
end

--- get the ghost builder enabled state for a player
--- @param player any
--- @return boolean
local function get_ghost_builder_enabled(player)
    local enabled = ghost_builder_enabled[player.index]
    if enabled ~= nil then return enabled end
    enabled = true
    pcall(function()
        enabled = player.is_shortcut_toggled("ghost-builder-togglse")
    end)
    return enabled
end

--- get_item_count but for LuaItemStack instead of LuaInventory
--- @param stack LuaItemStack
--- @param item SimpleItemStack
--- @return integer
local function stack_get_item_count(stack, item)
    if not stack then return 0 end
    if not stack.valid_for_read then return 0 end
    if stack.name ~= item.name then return 0 end
    if stack.quality.name ~= item.quality then return 0 end
    return stack.count
end
--- get_insertable_count but for LuaItemStack instead of LuaInventory
--- @param stack LuaItemStack
--- @param item SimpleItemStack
--- @return integer
local function stack_get_insertable_count(stack, item)
    if not stack then return 0 end
    if not stack.valid_for_read then
        stack.set_stack({ name = item.name, quality = item.quality, count = 1 })
        local count = stack.prototype.stack_size
        stack.clear()
        return count
    end
    if stack.name ~= item.name then return 0 end
    if stack.quality.name ~= item.quality then return 0 end
    return stack.prototype.stack_size - stack.count
end
--- remove but for LuaItemStack instead of LuaInventory
--- @param stack LuaItemStack
--- @param item SimpleItemStack
--- @return integer
local function stack_remove(stack, item)
    local to_remove = math.min(item.count, stack_get_item_count(stack, item))
    if to_remove == 0 then return 0 end
    stack.count = stack.count - to_remove
    return to_remove
end
--- insert but for LuaItemStack instead of LuaInventory
--- @param stack LuaItemStack
--- @param item SimpleItemStack
--- @return integer
local function stack_insert(stack, item)
    local to_insert = math.min(item.count, stack_get_insertable_count(stack, item))
    if not stack.valid_for_read then
        stack.transfer_stack(item)
    else
        if to_insert == 0 then return 0 end
        stack.count = stack.count + to_insert
    end
    return to_insert
end


--- check transfer items from a group of sources to a group of targets
--- @param stack SimpleItemStack|LuaItemStack the stack to transfer
--- @param sources (LuaInventory|LuaItemStack)[]|nil the source of transfer
--- sources can be composed of multiple LuaInventory or LuaItemStack in the order of priority
--- if sources is nil, then the stack is not taken from any inventory but created from scratch
--- @param targets (LuaInventory|LuaItemStack)[]|nil the target of transfer
--- targets can be composed of multiple LuaInventory or LuaItemStack in the order of priority
--- if targets is nil, then the stack is not put in any inventory but removed from the game
--- @return integer amount amount that can be transfered
local function can_transfer_stack(stack, sources, targets)
    local amount = stack.count or 1
    if sources then
        local count_source = 0
        for _, source in ipairs(sources) do
            if not source then -- ignore
            elseif source.object_name == "LuaInventory" then
                count_source = count_source + source.get_item_count(stack)
            elseif source.object_name == "LuaItemStack" then
                count_source = count_source + stack_get_item_count(source, stack)
            else
                error("Invalid source object")
            end
        end
        amount = math.min(amount, count_source)
    end
    if targets then
        local count_target = 0
        for _, target in ipairs(targets) do
            if not target then -- ignore
            elseif target.object_name == "LuaInventory" then
                count_target = count_target + target.get_insertable_count(stack)
            elseif target.object_name == "LuaItemStack" then
                count_target = count_target + stack_get_insertable_count(target, stack)
            else
                error("Invalid target object")
            end
        end
        amount = math.min(amount, count_target)
    end
    return amount
end

--- transfer items from a group of sources to a group of targets
--- @param stack SimpleItemStack|LuaItemStack the stack to transfer
--- @param sources (LuaInventory|LuaItemStack)[]|nil the source of transfer
--- sources can be composed of multiple LuaInventory or LuaItemStack in the order of priority
--- if sources is nil, then the stack is not taken from any inventory but created from scratch
--- @param targets (LuaInventory|LuaItemStack)[]|nil the target of transfer
--- targets can be composed of multiple LuaInventory or LuaItemStack in the order of priority
--- if targets is nil, then the stack is not put in any inventory but removed from the game
--- @param partial boolean? is the transfer partial
--- if false, the transfer must be completed, or it will not transfer at all
--- if true, the transfer is made as much as possible, even if it is not complete
--- @return integer amount amount that got transfered
local function transfer_stack(stack, sources, targets, partial)
    local max_count = stack.count or 1
    local amount = can_transfer_stack(stack, sources, targets)
    if (not partial and amount ~= max_count) or amount == 0 then return 0 end

    -- remove the stack from sources
    if sources then
        stack.count = amount
        for _, source in ipairs(sources) do
            if not source then -- ignore
            elseif source.object_name == "LuaInventory" then
                stack.count = stack.count - source.remove(stack)
            elseif source.object_name == "LuaItemStack" then
                stack.count = stack.count - stack_remove(source, stack)
            else
                error("Invalid source object")
            end
            if stack.count <= 0 then break end
        end
    end
    -- insert the stack into targets
    if targets then
        stack.count = amount
        for _, target in ipairs(targets) do
            if not target then -- ignore
            elseif target.object_name == "LuaInventory" then
                stack.count = stack.count - target.insert(stack)
            elseif target.object_name == "LuaItemStack" then
                stack.count = stack.count - stack_insert(target, stack)
            else
                error("Invalid target object")
            end
            if stack.count <= 0 then break end
        end
    end
    stack.count = amount
    return amount
end

---complete a request proxy
---@param player LuaPlayer
---@param proxy LuaEntity
local function fill_request_proxy(player, proxy)
    local playerInv = { player.get_inventory(defines.inventory.character_main), player.cursor_stack }
    local removal_plan = proxy.removal_plan
    local insert_plan = proxy.insert_plan
    local changed_removal_plan = false
    local changed_insert_plan = false
    for _, plan in ipairs(removal_plan) do
        if plan and plan.items then
            for _, from in ipairs(plan.items.in_inventory) do
                if from.count > 0 then
                    local stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = from.count }
                    local sourceInv = { proxy.proxy_target.get_inventory(from.inventory)[from.stack + 1] }
                    local diff = transfer_stack(stack, sourceInv, playerInv, true)
                    if diff then changed_removal_plan = true end
                    from.count = from.count - diff
                end
            end
        end
    end
    for _, plan in ipairs(insert_plan) do
        if plan and plan.items then
            for _, to in ipairs(plan.items.in_inventory) do
                if to.count > 0 then
                    local stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = to.count }
                    local targetInv = { proxy.proxy_target.get_inventory(to.inventory)[to.stack + 1] }
                    local diff = transfer_stack(stack, playerInv, targetInv, true)
                    if diff then changed_insert_plan = true end
                    to.count = to.count - diff
                end
            end
        end
    end
    for _, plan in ipairs(removal_plan) do
        if plan and plan.items then
            for _, from in ipairs(plan.items.in_inventory) do
                if from.count > 0 then
                    local stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = from.count }
                    local sourceInv = { proxy.proxy_target.get_inventory(from.inventory)[from.stack + 1] }
                    local diff = transfer_stack(stack, sourceInv, playerInv, true)
                    if diff then changed_removal_plan = true end
                    from.count = from.count - diff
                end
            end
        end
    end
    if changed_removal_plan then proxy.removal_plan = removal_plan end
    if changed_insert_plan then proxy.insert_plan = insert_plan end
end

--- complete all request proxies of an entity
--- @param player LuaPlayer
--- @param hovered_entity LuaEntity
local function fill_request_proxies(player, hovered_entity)
    local entities = player.surface.find_entities_filtered({
        name = "item-request-proxy",
        position = hovered_entity.position,
    })
    for _, proxy in ipairs(entities) do
        fill_request_proxy(player, proxy)
    end
end


--- Build the ghost entity
--- @param player LuaPlayer
--- @param hovered_entity LuaEntity
local function build_ghost(player, hovered_entity)
    -- Get the ghost items SimpleItemStacks
    local items = hovered_entity.ghost_prototype.items_to_place_this
    for _, item in ipairs(items) do item.quality = hovered_entity.quality.name end

    -- Ensure the player can place the entity at the specified position
    local can_place_entity = player.can_place_entity({
        name = hovered_entity.ghost_name,
        position = hovered_entity.position,
        direction = hovered_entity.direction
    })
    if not can_place_entity then return end
    local playerInv = { player.cursor_stack, player.get_inventory(defines.inventory.character_main) }
    -- Iterate through the item list and attempt to use one to build the entity
    for _, item in pairs(items) do
        if can_transfer_stack(item, playerInv, nil) == item.count then
            local revived, entity = hovered_entity.revive({ raise_revive = true })
            if revived and entity then
                transfer_stack(item, playerInv, nil)
                fill_request_proxies(player, entity)
                return
            end
        end
    end
end

-- Event for checking and building ghosts
script.on_event(defines.events.on_selected_entity_changed, function(event)
    local player = game.get_player(event.player_index)

    if not player then return end
    if not get_ghost_builder_enabled(player) then return end

    -- Check if the player is hovering over a ghost entity
    local hovered_entity = player.selected
    if not hovered_entity then return end
    if hovered_entity.name == "entity-ghost" then
        build_ghost(player, hovered_entity)
    else
        fill_request_proxies(player, hovered_entity)
    end
end)

local function toggle_ghost_builder(player)
    local enabled = not get_ghost_builder_enabled(player)
    set_ghost_builder_enabled(player, enabled)
    player.print(enabled and "Auto Ghost Builder enabled" or "Auto Ghost Builder disabled")
end
commands.add_command("toggle-ghost-builder", "toggle auto ghost builder", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_ghost_builder(player)
end)

--- ^^^ this is minimal code to inject in scenario script without loading mods
--- vvv this part simply makes easier to use

script.on_event(defines.events.on_lua_shortcut, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    if event.prototype_name ~= "ghost-builder-toggle" then return end
    toggle_ghost_builder(player)
end)
script.on_event("ghost-builder-toggle", function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_ghost_builder(player)
end)
