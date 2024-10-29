local transfer = require("modules.transfer")

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
        if from.count == nil then from.count = 1 end
        if from.count > 0 then
          local stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = from.count }
          local sourceInv = { proxy.proxy_target.get_inventory(from.inventory)[from.stack + 1] }
          local diff = transfer.transfer_stack(stack, sourceInv, playerInv, true)
          if diff then changed_removal_plan = true end
          from.count = from.count - diff
        end
      end
    end
  end
  for _, plan in ipairs(insert_plan) do
    if plan and plan.items then
      for _, to in ipairs(plan.items.in_inventory) do
        if to.count == nil then to.count = 1 end
        if to.count > 0 then
          local stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = to.count }
          local targetInv = { proxy.proxy_target.get_inventory(to.inventory)[to.stack + 1] }
          local diff = transfer.transfer_stack(stack, playerInv, targetInv, true)
          if diff > 0 then changed_insert_plan = true end
          to.count = to.count - diff
        end
      end
    end
  end
  for _, plan in ipairs(removal_plan) do
    if plan and plan.items then
      for _, from in ipairs(plan.items.in_inventory) do
        if from.count == nil then from.count = 1 end
        if from.count > 0 then
          local stack = { name = plan.id.name, quality = plan.id.quality or "normal", count = from.count }
          local sourceInv = { proxy.proxy_target.get_inventory(from.inventory)[from.stack + 1] }
          local diff = transfer.transfer_stack(stack, sourceInv, playerInv, true)
          if diff then changed_removal_plan = true end
          from.count = from.count - diff
        end
      end
    end
  end
  if changed_removal_plan then proxy.removal_plan = removal_plan end
  if changed_insert_plan then proxy.insert_plan = insert_plan end

  local request_count = 0
  for _, plan in ipairs(proxy.removal_plan) do
    if plan and plan.items then request_count = request_count + 1 end
  end
  for _, plan in ipairs(proxy.insert_plan) do
    if plan and plan.items then request_count = request_count + 1 end
  end
  if request_count == 0 then
    proxy.destroy()
  end

  if not changed_removal_plan and not changed_insert_plan then
    player.play_sound { path = "utility/cannot_build" }
  else
    player.play_sound { path = "utility/inventory_move" }
  end
end

--- complete all request proxies of an entity
--- @param player LuaPlayer
--- @param hovered_entity LuaEntity
return function(player, hovered_entity)
  local entities = player.surface.find_entities_filtered({
    name = "item-request-proxy",
    position = hovered_entity.position,
  })
  for _, proxy in ipairs(entities) do
    fill_request_proxy(player, proxy)
  end
end
