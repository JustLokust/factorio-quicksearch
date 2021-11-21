local Fact = require("factorio")

local Recipe = {}

-- Helper to collect a list of recipes that match the query.
function Recipe.findMatches(player, matchFunc, showHidden)
  local matches = {}
  local itemsAdded = {}
  for name, recipe in pairs(player.force.recipes) do
    local itemProto = recipe.prototype.main_product and game.item_prototypes[recipe.prototype.main_product.name]
    local visible = (not recipe.hidden and recipe.enabled) or showHidden
    local canPlaceOrCraft = itemProto and (itemProto.place_result or recipe.category == "crafting")
    if itemProto and not itemsAdded[itemProto.name] and visible and canPlaceOrCraft and matchFunc(player, name) then
      itemsAdded[itemProto.name] = true
      matches[name] = {
        recipe = recipe,
        name = name,
--        number = player.get_craftable_count(recipe), -- too slow
        order = (isFavorite(player, name) and "[a]" or "[b]") .. (placeable and "[a]" or "[b]") .. recipe.group.name .. recipe.subgroup.name .. recipe.order,
        sprite = "recipe/"..name,
        tooltip = {
          "",
          itemProto.localised_name,
          " (", name, ")",
          "\nclick = pick up ghost of item",
          "\nctrl+click = craft single item",
          "\nshift+click = craft stack of item",
          "\alt+click = toggle favorite",
        },
        acceptFunc = "recipe",
      }
    end
  end
  return matches
end

-- Player chose a recipe.
function Recipe.pick(player, match, event)
  local itemProto = game.item_prototypes[match.recipe.prototype.main_product.name]
  local craft =
    (event.shift) and 100 or -- "100" means "a full stack"
    (event.control and event.button == defines.mouse_button_type.right) and 5 or
    (event.control) and 1 or
    0
  if craft == 0 then
    -- Grab ghost of the item.
    if itemProto.place_result then
      Fact.createGhostTool(player, itemProto.place_result)
    end
    return
  end
  -- Craft the item.
  if (player.controller_type == defines.controllers.god or player.controller_type == defines.controllers.editor) then
    player.insert{count=craft == 100 and itemProto.stack_size or craft, name=itemProto.name}
  else
    if craft == 100 then
      local amount = match.recipe.prototype.main_product.amount or match.recipe.prototype.main_product.amount_min or 1
      craft = math.ceil(itemProto.stack_size / amount)
    end
    player.begin_crafting{count=craft, recipe=match.recipe}
  end
end

return Recipe