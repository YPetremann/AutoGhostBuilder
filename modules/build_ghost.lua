local transfer             = require("modules.transfer")
local mine_entity          = require("modules.mine_entity")
local fill_request_proxies = require("modules.fill_request_proxies")

--- Build the ghost entity
--- @param player LuaPlayer
--- @param hovered_entity LuaEntity
return function(player, hovered_entity)
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
    if transfer.can_transfer_stack(item, playerInv, nil) == item.count then
      local revived, entity = hovered_entity.revive({ raise_revive = true })
      if not revived then
        -- check if there is an entity blocking the ghost
        local entities = player.surface.find_entities_filtered({
          area = hovered_entity.bounding_box,
        })
        for _, entity in pairs(entities) do
          mine_entity(player, entity)
        end
        revived, entity = hovered_entity.revive({ raise_revive = true })
      end
      if revived and entity then
        transfer.transfer_stack(item, playerInv, nil)
        fill_request_proxies(player, entity)
        return
      end
    end
  end
end
