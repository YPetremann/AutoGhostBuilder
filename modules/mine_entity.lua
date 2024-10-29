return function(player, entity)
  if not entity.to_be_deconstructed() then return end
  if not player.can_reach_entity(entity) then return end
  local mined = player.mine_entity(entity, false)
  if mined then
    player.play_sound { path = "utility/deconstruct_small" }
  else
    player.play_sound { path = "utility/cannot_build" }
  end
end
