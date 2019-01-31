-- Utilities for working with inventories.

local Inventory = {}

local entityTypeToInventory = {
  ['car'] = defines.inventory.car_trunk,
  ['cargo-wagon'] = defines.inventory.cargo_wagon,
  ['container'] = defines.inventory.chest,
  ['logistic-container'] = defines.inventory.chest
}

-- Returns the inventory of the opened entity, like a chest or cargo wagon, or nil if one isn't opened.
function Inventory.getForOpenContainer(player)
  if player.opened and player.opened_gui_type == defines.gui_type.entity then
    return player.opened.get_inventory(entityTypeToInventory[player.opened.type] or 255)
  end
end

-- Finds a slot in the given inventory that is capable of holding more of the given item (either empty or a partial stack)
function Inventory.findAvailableSlot(inv, itemName)
  for i=1,#inv do
    if inv[i].valid and inv[i].valid_for_read and inv[i].name == itemName and inv[i].count < inv[i].prototype.stack_size then
      return inv[i]
    end
    if inv[i].valid and not inv[i].valid_for_read then
      return inv[i]
    end
  end
end

-- Transfers the given amount of the specified item between inventories.
function Inventory.transferItems(fromInventory, toInventory, item, amount)
  local itemName = item.name
  while amount > 0 and item and item.valid and item.valid_for_read do
    local targetSlot = Inventory.findAvailableSlot(toInventory, itemName)
    if not targetSlot then break end
    if targetSlot.valid_for_read then
      -- Add to existing slot.
      local transferred = math.min(targetSlot.prototype.stack_size - targetSlot.count, amount)
      targetSlot.count = targetSlot.count + transferred
      item.count = item.count - transferred
      amount = amount - transferred
    elseif amount < item.count then
      -- Transfer less than a full stack.
      targetSlot.set_stack(item)
      targetSlot.count = amount
      item.count = item.count - amount
      break -- none left
    else
      -- Transfer a full stack.
      amount = amount - item.count
      targetSlot.swap_stack(item)
    end
    item = fromInventory.find_item_stack(itemName)
  end
end

-- Helper to collect a list of items that match the query.
function Inventory.findMatches(player, inventories, matchFunc)
  local matches = {}
  local empty = {number = 0}
  for invIndex, inv in pairs(inventories) do
    for i = 1,#inv do
      local item = inv[i]
      if item.valid and item.valid_for_read and matchFunc(player, item.name) then
        matches[item.name] = {
          inventory = inv,
          name = item.name,
          number = (matches[item.name] or empty).number + item.count,
          order = (isFavorite(player, item.name) and "[a]" or "[b]") .. item.prototype.order,
          sprite = "item/"..item.name,
          tooltip = {
            "",
            item.prototype.localised_name,
            " (", item.name, ")",
            "\nclick = pick up item",
            "\nshift+click = transfer single stack to other inventory",
            "\nctrl+click = transfer all stacks to other inventory",
          },
          acceptFunc = "item",
        }
      end
    end
  end
  return matches
end

-- Player chose an item from the inventory list.
function Inventory.pick(player, match, event)
  local item = match.inventory.find_item_stack(match.name)
  local containerInventory = Inventory.getForOpenContainer(player)
  local transfer = event.control and "all" or event.shift and "single" or nil
  local half = event.button == defines.mouse_button_type.right

  if not (item.valid and item.valid_for_read) then return end
  if containerInventory and transfer then
    local otherInventory = match.inventory == containerInventory and player.get_main_inventory() or containerInventory
    local amount = transfer == "all" and match.number or math.min(match.number, item.prototype.stack_size)
    if half then amount = math.ceil(amount / 2) end

    debug(player, "Transferring %dx%s from %d slot inventory to %d slot inventory", amount, item.name, #match.inventory, #otherInventory)
    Inventory.transferItems(match.inventory, otherInventory, item, amount)
  else
    if half then
      if not player.cursor_stack.valid_for_read then
        player.cursor_stack.set_stack(item)
        player.cursor_stack.count = math.ceil(item.count / 2)
        item.count = item.count - player.cursor_stack.count
      end
    else
      player.cursor_stack.swap_stack(item)
    end
  end
end

return Inventory