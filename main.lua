---Test program for InputMangler.

local input = require "inputmangler"
local commandbuff = {}  --record of recently given inputs
local mapping = nil     --command we're in the process of mapping, if any

function love.load()
  --Establish a new context, map keys 1-4, F1-F4 and buttons a, b, x, y, and set modifiers shift, alt, ctrl, meta
  input:addContext("test")
  
  input:addKeyCommand("command 1", "1", "test")
  input:addKeyCommand("command 2", "2", "test")
  input:addKeyCommand("command 3", "3", "test")
  input:addKeyCommand("command 4", "4", "test")
  
  input:addKeyCommand("set 1", "f1", "test")
  input:addKeyCommand("set 2", "f2", "test")
  input:addKeyCommand("set 3", "f3", "test")
  input:addKeyCommand("set 4", "f4", "test")
 
  input:addButtonCommand("command 1", "a", "test")
  input:addButtonCommand("command 2", "b", "test")
  input:addButtonCommand("command 3", "x", "test")  
  input:addButtonCommand("command 4", "y", "test")
 
  input:addModifierKey("shift", "test")
  input:addModifierKey("alt", "test")
  input:addModifierKey("ctrl", "test")
  input:addModifierKey("meta", "test")
end

--assembles all the control mappings in a table, complete with modifiers, for pretty-printing.
--Recursive and ugly.  Don't try this at home, kids.
local function striptree(tree)
  local returnthis = {}
  for key, entry in pairs(tree) do
    if key == "cmd" then
      table.insert(returnthis, entry)
    elseif (key == "shift") or (key == "alt") or (key == "ctrl") or (key == "meta") then
      local temp = striptree(entry)
      for subkey, subentry in pairs(temp) do
        table.insert(returnthis, "+" .. key .. ": " .. subentry)
      end
    else
      local temp = striptree(entry)
      for subkey, subentry in pairs(temp) do
        table.insert(returnthis, key .. ": " .. subentry)
      end
    end
  end
  return returnthis
end

---draws a column of text on the left side of the window, fading them out as we move down.
--@param text   table of strings to draw
local function drawLeft(text)
  if not text then
    return
  end
  
  local halfwidth = math.floor(love.graphics.getWidth() / 2) - 20
  
  for i, str in ipairs(text) do
    love.graphics.setColor(255, 255, 255, math.max(255 - ((i - 1) * 32), 64))
    love.graphics.printf(str, 10, 10 + ((i - 1) * 15), halfwidth)
  end
end

---draws a column of text on the right side of the window.
--@param text   table of strings to draw
local function drawRight(text)
  local halfwidth = math.floor(love.graphics.getWidth() / 2) - 20
  love.graphics.setColor(0, 255, 0, 255)  --green (why not?)
  
  for i, str in ipairs(text) do
    love.graphics.printf(str, 20 + halfwidth, 10 + ((i - 1) * 15), halfwidth)
  end
end

function love.draw()
  drawLeft(commandbuff)

  local right = {}
  if mapping then
    table.insert(right, "Mapping " .. mapping)
  else
    table.insert(right, "There are four commands (that don't actually do anything).")
    table.insert(right, "To bind a new key or button to a given command,")
    table.insert(right, "press the corresponding function key (F1-F4).")
    table.insert(right, "----------------------------------------------")
    local subright = striptree(input.contexts["test"].keys)
    table.sort(subright)
    for _, entry in pairs(subright) do
      table.insert(right, "key " .. entry)
    end
    table.insert(right, "----------------------------------------------")    
    subright = striptree(input.contexts["test"].buttons)
    table.sort(subright)    
    for _, entry in pairs(subright) do
      table.insert(right, "button " .. entry)
    end    
  end
  drawRight(right)
end

function love.mousepressed(x, y, button, istouch)
  if mapping and not input:isButtonModifier(button, "test") then
    input:addButtonCommand(mapping, button, "test", input:getModifiers("test"))
    mapping = nil
  else
    local cmd = input:testButton(button, "test")
    if cmd then
      table.insert(commandbuff, 1, "Pressed mouse " .. button .. " mapped to " .. cmd)
    end
  end
end

function love.keypressed(key, scancode, isrepeat)
  local cmd = input:testKey(key, "test")

  if mapping and (not input:isKeyModifier(key, "test")) and (not cmd or not (string.find(cmd, "^set %d$"))) then
    --map new key
    input:addKeyCommand(mapping, key, "test", input:getModifiers("test"))
    mapping = nil
  elseif cmd then
    if string.find(cmd, "^set %d$") then
      --enter command mapping mode
      local _, __, d = string.find(cmd, "^set (%d)$")
      mapping = "command " .. d
    elseif input:getModifiers("test") then
      --record the command chord
      table.insert(commandbuff, 1, "Pressed key " .. key .. "+" .. table.concat(input:getModifiers("test"), "+") .. " mapped to " .. cmd)
    else
      --record the command
      table.insert(commandbuff, 1, "Pressed key " .. key .. " mapped to " .. cmd)      
    end
  end
end

function love.gamepadpressed(joystick, button)
  if mapping and not input:isButtonModifier(button, "test") then
    input:addButtonCommand(mapping, button, "test", input:getModifiers("test"))
    mapping = nil
  else
    local cmd = input:testButton(button, "test")
    if cmd then
      table.insert(commandbuff, 1, "Pressed gamepad " .. button .. " mapped to " .. cmd)
    end
  end
end

function love.gamepadaxis(joystick, axis, value)
  if mapping and not input:isButtonModifier(axis, "test") then
    input:addButtonCommand(mapping, axis, "test", input:getModifiers("test"))
    mapping = nil
  else
    local cmd = input:testButton(axis, "test")
    if cmd then
      table.insert(commandbuff, 1, "Pressed axis " .. axis .. " mapped to " .. cmd)
    end
  end
end
