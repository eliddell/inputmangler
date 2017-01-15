---Maps keyboard/gamepad inputs and modifier keys/buttons to commands.
--@classmod InputMangler
--@alias InputManager
--
--"modifiers" are keys and/or buttons held down at the same time as the main input is pressed.
--This allows input chords like CTRL+q to be mapped to a different command than just q.
--
--Mapping may optionally be restricted to a named context (in other words, you can have a "game" 
--context, a "paused" context, a "menu" context, etc., and the same key or button will return a 
--different command depending on context).

local InputManager = {}
InputManager._VERSION = "0.1"

---list of Löve joystick axis names, to filter them out during joystick modifier testing
local axes = {["leftx"] = true,
              ["lefty"] = true,
              ["rightx"] = true,
              ["righty"] = true,
              ["triggerleft"] = true,
              ["triggerright"] = true}


-------------------
--@section locals--
-------------------

---Walks a modifier tree down to the bottom level, optionally creating missing levels.
--@param base           the table to start from
--@param modifiers      list of modifiers (table of strings) to follow down levels
--@param createmissing  true if missing levels are to be created
--@return               the bottom-level table if successful, nil if it fails
local function walkModifiers(base, modifiers, createmissing)
  if not base or not modifiers then 
    return base
  end

  for _, modifier in ipairs(modifiers) do
    if not base[modifier] then
      if createmissing then
        base[modifier] = {}
      else
        return nil
      end
    end
    base = base[modifier]
  end
  return base
end

---Attempts to get a valid modifier sequence leading down from the specified table, even if not all modifiers are valid.
--@param base       the table to start from
--@param modifiers  list of modifiers (table of strings) to follow down levels
--@return           the lowest-level table that can be found by following the modifier sequence (can be base)
local function testModifiers(base, modifiers)
  if base and modifiers then
    local seq = walkModifiers(base, modifiers, false)
    if seq and seq.cmd then
      base = seq  --all modifiers were valid
    else
      --some modifiers weren't applicable, so we'll do our best to gather a valid sequence
      local lastTested = 1
      local max = table.maxn(modifiers)
      while lastTested <= max do
        if base[modifiers[lastTested]] then
          base = base[modifiers[lastTested]]
        end
        lastTested = lastTested + 1
      end
    end
  end
  return base
end

---Cleans up empty subtables of the specified table.  Recursive.
--@param base   the table to clean
--@return       true if there is at least one valid entry somewhere in base (meaning it can't be cleaned any further), false otherwise.
local function cleanTree(base)
  for k, v in pairs(base) do
    if type(v) == "table" then
      if not InputManager._cleanTree(v) then
        base[k] = nil
      else
        return true --there's a valid entry at a lower level
      end
    else  --there's a valid entry in this tree at this level
      return true
    end
  end
  
  --we made it through all this level's children without finding a valid entry -> this level is empty
  return false
end

---Does the actual adding of commands, based on the parent table passed.
--@param parent     the parent table (a list of input => command mappings)
--@param command    the command (string)
--@param input      a string (KeyConstant, GamepadButton, or arbitrary) indicating the input to be mapped
--@param modifiers  list of modifiers (table of string) or nil
local function addCommand(parent, command, input, modifiers)
  --first we need to walk down to the command's level
  if not parent[input] then
    parent[input] = {}
  end
  parent = walkModifiers(parent[input], modifiers, true)
  
  --Now we're finally at the correct level--set the command
  parent.cmd = command
end  

---Does the actual deletion of commands, based on the parent table passed. 
--@param parent     the parent table (a list of input => command mappings)
--@param input      a string (KeyConstant, GamepadButton, or arbitrary) indicating the input to be mapped
--@param modifiers  list of modifiers (table of string) or nil
local function delCommand(parent, input, modifiers)
  --first we need to walk down to the command's level
  local subparent = walkModifiers(parent[input], modifiers, false)

  --if we didn't make it all the way down, the command doesn't exist
  if not subparent then
    return nil
  end
  
  subparent.cmd = nil

  --clean up empty key commands to reduce memory leakage
  if not cleanTree(subparent) then
    parent[input] = nil
  end
end

---Does the actual saving of data.  Recursive.
--@param file       an open filehandle
--@param data       data to save
--@param level      how far have we recursed?
local function saveAll(file, data, level)
  
  if level == 1 then
    file:write("local InputManglerSaveTable = ")
  end
  if type(data) == "table" then
    file:write("{")
    for k,v in pairs(data) do
      file:write("\n" .. string.rep("  ", level))
      file:write("[" .. string.format("%q", k) .. "] = ")
      saveAll(file, v, level + 1)
      file:write(",")
    end
    file:write("\n" .. string.rep("  ", level) .. "}")
  elseif type(data) == "string" then
    file:write(string.format("%q", data))
  else    
    file:write("")
  end
  if level == 1 then
    file:write("\n\n return InputManglerSaveTable")
  end  
end

---------------------
--@section contexts--
---------------------

---Creates a new context.  Warning: If there is already a context named "context", calling this will blank it.
--@param context  name of the new context (string)
function InputManager:addContext(context)
  InputManager.contexts[context] = {}
  local new = InputManager.contexts[context]
  new.keys = {}
  new.buttons = {}
  new.modifiers = {}
  new.modifiers.keys = {}
  new.modifiers.buttons = {}
  return new
end

---Deletes the named context.
--@param context  name of the context to be deleted (string)
function InputManager:delContext(context)
  InputManager.contexts[context] = nil
end


----------------------
--@section modifiers--
----------------------

---Adds a modifier key to the specified context.
--Note:  Adding the same modifier twice won't actually break anything (just slow things down slightly when the keys are tested).
--@param modifier   a KeyConstant
--@param context    name of the context to apply this modifier to (or nil to apply it to the default context)
function InputManager:addModifierKey(modifier, context)
  context = context or "_"
  table.insert(InputManager.contexts[context].modifiers.keys, modifier)
end

---Adds a modifier button to the specified context.
--Note:  Adding the same modifier twice won't actually break anything (just slow things down slightly when the keys are tested).
--@param modifier   a GamepadButton
--@param context    name of the context to apply this modifier to (or nil to apply it to the default context)
function InputManager:addModifierButton(modifier, context)
  context = context or "_"
  table.insert(InputManager.contexts[context].modifiers.buttons, modifier)
end

---Returns the modifier keys and buttons that are currently being held down.  
--@param context    The name of an existing context (string) containing the modifier list to test.
--@return           list of held modifiers (table containing a mix of KeyConstants and GampabButtons) or nil if no modifiers are being held.
function InputManager:getModifiers(context)
  local modKeys = self.contexts[context].modifiers.keys
  local modButtons = self.contexts[context].modifiers.buttons
  local joystick = self.gamepad
  
  local activeModifiers = {}
  local isEmpty = true
  
  --keyboard first
  for _, keysym in ipairs(modKeys) do
    if keysym == "shift" then
      if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        table.insert(activeModifiers, keysym)
        isEmpty = false    
      end
    elseif keysym == "alt" then
      if love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt") then
        table.insert(activeModifiers, keysym)
        isEmpty = false    
      end    
    elseif keysym == "ctrl" then
      if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        table.insert(activeModifiers, keysym)
        isEmpty = false    
      end    
    elseif keysym == "meta" then
      if love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui") then
        table.insert(activeModifiers, keysym)
        isEmpty = false    
      end
    elseif love.keyboard.isDown(keysym) then
      table.insert(activeModifiers, keysym)
      isEmpty = false
    end
  end
  
  --then mouse
  for _, btn in ipairs(modButtons) do
    if tonumber(btn) and love.mouse.isDown(tonumber(btn)) then
      table.insert(activeModifiers, btn)
      isEmpty = false
    end
  end
  
  --and finally joystick
  if joystick then
    for _, btn in ipairs(modButtons) do
      if tonumber(btn) then
        --oops, this is a mouse button.  Better not do anything with it.
        --Note: this check relies on the fact that mouse buttons have numeric identifiers in Löve 0.10+
      elseif not axes[btn] and joystick:isGamepadDown(btn) then
        --actual button      
        table.insert(activeModifiers, btn)
        isEmpty = false
      elseif axes[btn] and math.abs(joystick:getGamepadAxis(btn)) > 0 then
        --axis (mainly to check to see if the triggers have been pressed)        
        table.insert(activeModifiers, btn)
        isEmpty = false
      end
    end
  end
  
  if isEmpty then
    return nil
  end
  return activeModifiers
end

---Tests whether or not the given key is a modifier.
--@param keysym   The KeyConstant to test
--@param context  The name of an existing context (string) to test this key in (or nil to use the default context)
--return          True
function InputManager:isKeyModifier(keysym, context)
  context = context or "_"  
  
  for _, modifier in pairs(self.contexts[context].modifiers.keys) do
    if modifier == keysym then
      return true
    elseif modifier == "shift" and (keysym == "lshift" or keysym == "rshift") then
      return true
    elseif modifier == "alt" and (keysym == "lalt" or keysym == "ralt") then
      return true
    elseif modifier == "ctrl" and (keysym == "lctrl" or keysym == "rctrl") then
      return true
    elseif modifier == "meta" and (keysym == "lgui" or keysym == "rgui") then
      return true
    end
  end
  return false
end

---Tests whether or not the given button is a modifier.
--@param button   The GamepadButton, GamepadAxis, or numeric mouse button identifier to test
--@param context  The name of an existing context (string) to test this key in (or nil to use the default context)
--return          True
function InputManager:isButtonModifier(button, context)
  context = context or "_"  
  
  for _, modifier in pairs(self.contexts[context].modifiers.buttons) do
    if modifier == button then
      return true
    end
  end
  return false
end


---------------------
--@section commands--
---------------------

---Adds a key binding to the specified context.  
--@param command    command name (string)
--@param keysym     KeyConstant to bind the command to
--@param context    the name of an existing context (string) to place this command in (or nil to use the default context)
--@param modifiers  a list of modifier keys or buttons to complete the input chord (or nil for no modifiers)
function InputManager:addKeyCommand(command, keysym, context, modifiers)
  context = context or "_"  
  addCommand(self.contexts[context].keys, command, keysym, modifiers)
end  

---Removes a key binding from the specified context.
--@param keysym     the KeyConstant to remove
--@param context    the name of an existing context (string) to place this command in (or nil to use the default context)
--@param modifiers  a list of modifier keys or buttons to complete the input chord (or nil for no modifiers)
function InputManager:delKeyCommand(keysym, context, modifiers)
  context = context or "_"
  delCommand(self.contexts[context].keys, keysym, modifiers)
end

---Adds a button, axis, or arbitrary binding to the specified context.  
--@param command    command name (string)
--@param button     a GamepadButton or arbitrary input name (string) to bind the command to
--@param context    the name of an existing context (string) to place this command in (or nil to use the default context)
--@param modifiers  a list of modifier keys or buttons to complete the input chord (or nil for no modifiers)
function InputManager:addButtonCommand(command, button, context, modifiers)
  context = context or "_"  
  addCommand(self.contexts[context].buttons, command, button, modifiers)
end

---Removes a button, axis, or arbitrary binding from the specified context.
--@param button     a GamepadButton or arbitrary input name (string) to remove
--@param context    the name of an existing context (string) to place this command in (or nil to use the default context)
--@param modifiers  a list of modifier keys or buttons to complete the input chord (or nil for no modifiers)
function InputManager:delButtonCommand(button, context, modifiers)
  context = context or "_"
  delCommand(self.contexts[context].buttons, button, modifiers)
end

---Returns the command bound to the specified GamepadButton or arbitrary input, taking modifiers into account.
--@param button   a GamepadButton or arbitrary input name (string) to test
--@param context  the name of an existing context (string) to check (or nil to use the default context)
--@return         a command (string) if a mapping for the button exists in the specified context, nil if it doesn't.
function InputManager:testButton(button, context)
  context = context or "_"
  
  --test modifiers until we get a valid sequence
  local modifiers = self:getModifiers(context)       --see which modifiers are pressed
  local parent = testModifiers(self.contexts[context].buttons[button], modifiers) --see which ones pertain to this key
  
  --now we can return a command, if there is one
  if parent then
    return parent.cmd
  end
  return nil
end

---Returns the command bound to the specified KeyConstant, taking modifiers into account.
--@param keysym   a KeyConstant to test
--@param context  the name of an existing context (string) to check (or nil to use the default context)
--@return         a command (string) if a mapping for the key exists in the specified context, nil if it doesn't.
function InputManager:testKey(keysym, context)
  context = context or "_"
  
  --test modifiers until we get a valid sequence
  local modifiers = self:getModifiers(context)  
  local parent = testModifiers(self.contexts[context].keys[keysym], modifiers)
  
  --now we can return a command, if there is one
  if parent then
    return parent.cmd
  end
  return nil
end


----------------------
--@section save-load--
----------------------

---Saves all bindings and modifiers to a file.
--@param filename   the name of a file
--@param rawio      set to true in order to bypass love.filesystem and use standard Lua io routines.
function InputManager:saveBindings(filename, rawio)
  local file = nil
  
  --we need to open the file differently depending on what type of fle object we're using
  if rawio then
    file = assert(io.open(filename .. ".lua", "w"))
  else
    file = love.filesystem.newFile(filename)
    file:open("w")
  end
  
  --now we write everything to the file and close it.
  saveAll(file, self.contexts, 1)
  file:close()
end

---Loads bindings and modifiers from a file saved with the saveBindings function.  Warning:  this will wipe away any
--modifiers or bindings already in teh system.
--@param filename   the name of a file
--@param rawio      set to true in order to bypass love.filesystem and use standard Lua io routines.
function InputManager:loadBindings(filename, rawio)
  local temp = nil
  if rawio then
    temp = require(filename)  
  else  
    local chunk = love.filesystem.load(filename)
    temp = chunk()
  end
  self.contexts = temp
  temp = nil
end


-----------------
--@section misc--
-----------------

---Sets the gamepad to test for modifier buttons.
--You only need to call this if you want to test a gamepad other than the one that was love.joysticks.getJoysticks[1]
--when the module was initialized.
--@param joystick   a love.joysticks.Joystick to test for modifier buttons, or nil to not test any
function InputManager:setJoystick(joystick)
  InputManager.gamepad = joystick
end


-----------------
--@section init--
-----------------

--sets up a default context with some commands (intended for menu, etc. usage)
do
  --each context has its own lists of keys, buttons, and modifiers
  InputManager.contexts = {}
  
  --initialize the default context
  local default = InputManager:addContext("_")
  
  --basic key constants for a menu or similar (quick'n'sloppy setup--don't do this at home, kids.  Use addKeyCommand instead.)
  default.keys["return"] = {cmd = "ok"}
  default.keys["kpenter"] = {cmd = "ok"}
  default.keys["escape"] = {cmd = "cancel"}
  default.keys["up"] = {cmd = "up"}
  default.keys["kp8"] = {cmd = "up"}
  default.keys["down"] = {cmd = "down"}
  default.keys["kp2"] = {cmd = "down"}
  default.keys["left"] = {cmd = "left"}
  default.keys["kp4"] = {cmd = "left"}
  default.keys["right"] = {cmd = "right"}
  default.keys["kp6"] = {cmd = "right"}
  
  --FYI:  buttons are stored separately for ease of indexing.
  --We don't want buttons["a"] overwriting keys["a"].
  default.buttons["a"] = {cmd = "ok"}
  default.buttons["b"] = {cmd = "cancel"}
  default.buttons["dpup"] = {cmd = "up"}
  default.buttons["dpdown"] = {cmd = "down"}
  default.buttons["dpleft"] = {cmd = "left"}
  default.buttons["dpright"] = {cmd = "right"}
  
  --Modifiers are keys or buttons whose held-down status modifies a command.
  default.modifiers.keys = {"shift", "alt", "ctrl", "meta"} --set both shift, both alt, both ctrl, and both gui keys
  
  --Set default gamepad to test for modifiers.  For a single-player game, this should Just Work.
  InputManager.gamepad = nil
  if love.joystick.getJoystickCount() > 0 then
    local joysticks = love.joystick.getJoysticks()    
    InputManager.gamepad = joysticks[1]
  end
end

return InputManager
