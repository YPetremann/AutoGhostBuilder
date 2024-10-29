local lib = {}

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
lib.can_transfer_stack = function(stack, sources, targets)
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
lib.transfer_stack = function(stack, sources, targets, partial)
  local max_count = stack.count or 1
  local amount = lib.can_transfer_stack(stack, sources, targets)
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

return lib
