# inputmangler
An input-mapping module for the 2D game framework Löve.  It supports chording (commands composed
of multiple keys) and contexts (inputs can be bound to different commands simultaneously, separated
into, say, a "menu" and a "game" context).  It supports both keyboard keys and mouse/gamepad buttons
and axes, but handles them slightly differently to avoid having to rename anything.

Written for Löve 0.10, but see the section on earlier versions at the bottom if you want to use
it with 0.9 or 0.8.


#Installing

Just copy inputmangler.lua into your project and `require` it.  The main.lua included in the 
repository is just an extended example, and can be discarded without causing problems.  Likewise, 
you don't need to include the documentation package.


#Default Setup

When first initialized, inputmangler activates the first gamepad it finds (if there is
one), and loads a few simple keybindings and modifiers suitable for navigating a
"New Game"/"Load"/"Options" type of menu.

To clear the keybindings out of the default context, use `addContext("_")`.

To switch to a different gampad, use `setJoystick(gamepad)`


#Basic Usage

```lua
  local input = require "inputmangler"

  function love.load()
    input:addKeyCommand("command 1", "1")
    input:addButtonCommand("command 1", "a")
  end

  function love.keypressed(key, scancode, isrepeat)
    local cmd = input:testKey(key)
    if cmd then
      --do something with cmd (store it for the next call to love.update, or whatever)
    end
  end
```

The `addKeyCommand` function takes up to four parameters:  a command name, a love.keyboard.KeyConstant,
an optional context name, and an optional list of modifiers (more on those a couple of sections down).
There is a matching `delKeyCommand` that takes a KeyConstant and the optional context name and modifiers.

`testKey` takes a KeyConstant and optional context name, and tells you which command corresponds to
that key (it returns nil if there is no command).

`addButtonCommand`, `delButtonCommand`, and `testButton` do the same things as the `...Key...`
commands except that the KeyConstant parameter is replaced by a GamepadButton, GamepadAxis, or
mouse button number.


#Saving and Loading

Call the `saveBindings(filename)` function to write an inputmangler instance to disc.  All key and 
button bindings (including modifier information, on which more later) are included in the file.  Use
`loadBindings(filename)` to load the saved information back into the program.

Both functions take two parameters:  a filename, and an optional boolean called rawio.  Normally
files are saved and loaded using the love.filesystem functions, but setting rawio to true makes
inputmangler use the raw Lua io.[foo] functions (and require) instead.  This gives you more
flexibility regarding where the files are saved, but may cause problems if your game is being
shipped as a .love file or an executable concantenation.

The file format is ordinary Lua.


#Contexts

A context is a named grouping of key bindings that correspond to a distinct game state.
Some games may have only one context, while others may have many.

Let's say you've written a game that's divided into levels, and the player can choose what level
they want to play next by moving around a map (think Super Mario World).  On the map, pressing
the "down" key on the keyboard moves the player toward the bottom of the screen, but when the
player is inside a level, "down" could mean "duck" or "drop a bomb" or "slow down" or "reduce
power" or nothing at all, depending on the game.

You could put up with the "down" key being tied to a command name that makes no sense while
the player is moving around the map.  Or remap it every time the player switches between
the map and a level.  Or you could use contexts. ;)

```lua
  input:addContext("map")
  input:addContext("level")
  input:addKeyCommand("down", "down", "map")
  input:addKeyCommand("slower", "down", "level")
```

`addContext` creates a new context, taking a context name as its only parameter.  Applying it to
a context that already exists will cause that context to be blanked (all the commands and modifiers
in it will be removed, but the context itself will still exist).

`delContext` deletes a context.  It also takes the context's name as a parameter.


#Modifiers and Chording

*Chording* means holding down multiple buttons at the same time to produce a single action.
(Well, when you're talking about computers, anyway.)  Most common GUI environments use chords
for some commands.  For instance, pressing **CTRL+home** on a Windows PC does something different
from just pressing **home** by itself.

Why would you want to use something like that in a game?  Well, how about mapping four different 
commands to a three-button mouse?  Recreating classic Roguelikes that use **w** and **W** (and maybe 
also **CTRL+w**) for different things?  Hidden commands like the TCELES B HSUP from the original Final
Fantasy?  Commands for which "hold **x** and push up or down to adjust" makes intuitive sense?

Using inputmangler for chorded commands requires two steps.  First, some keys or buttons have to be 
set up as modifiers (keys which are never used as commands on their own, but are added to others to
produce chords).  Secondly, commands must be mapped using modifiers + another key.

Let's bind the **w** key to four different commands, depending on whether it's pressed alone,
with shift, with CTRL, or with both:

```lua
  input:addModifierKey("shift")
  input:addModifierKey("ctrl")
  input:addKeyCommand("wield", "w")
  input:addKeyCommand("wear", "w", nil, {"shift"})
  input:addKeyCommand("wait", "w", nil, {"ctrl"})
  input:addKeyCommand("whisper", "w", nil, {"shift", "ctrl"})
```

`addModifierKey` takes a KeyConstant and an optional context name, and adds that key to the list
of modifiers.  There's no delModifierKey, since I couldn't see how it would be useful, but it would
be trivial to add.  There are four special modifier "KeyConstants" that cover multiple keys:

* "shift" matches both shift keys (lshift + rshift)
* "alt" matches both ALT keys (lalt + ralt)
* "ctrl" matches both CTRL keys (lctrl + rctrl)
* "meta" matches . . . both gui keys (lgui + rgui)

Notice that when you're adding commands with modifiers, the list of modifiers is a table even if
there's only one item in it.

The module will detect on its own what modifiers are being held when `testKey` (or `testButton`)
is called.

As with most other commands, there's a corresponding `addModifierButton` that takes a GamepadButton,
GamepadAxis, or mouse button number.  For instance, we can map four commands to a three-button mouse
by mapping buttons 1 and 2 to different commands depending on whether button 3 is held down:

```lua
  input:addModifierButton("3")
  input:addButtonCommand("command A", "1")
  input:addButtonCommand("command B", "2")
  input:addButtonCommand("command C", "1", nil, {"3"})
  input:addButtonCommand("command D", "2", nil, {"3"})
```

`isKeyModifier` and `isButtonModifier` take an input (KeyConstant, GamepadButton, whatever) and
an optional context name and return **true** if that input is a modifier.

`getModifiers` takes an optional context name and returns the list of modifiers currently being
held down.  It's useful mainly for remapping commands in response to user input, as in the
example main.lua


#Tricks, Tips, and Limitations

##The Default Context
The "no-name" context is actually called "_", as the *Default Setup* section implies.  It can
be manipulated directly by that name if you feel the need.

##Mix-and-Match Buttons with Keys
It's perfectly acceptable to mix modifier keys with buttons, or modifier buttons with
keys, as in `input:addButtonCommand("command C", "1", nil, {"shift"})`.

##Arbitrary Strings
None of these functions except the add[Foo]Modifier pair care if what they're being passed 
actually is a KeyConstant, GamepadButton, or whatever.  This means that you could, for instance,
map a command to an on-screen button, use Scancodes instead of KeyConstants, or assign different
commands to press and release of the same key:

```lua
  input:addKeyCommand("command A", "1")
  input:addKeyCommand("command B", "1-release")

  function love.keyreleased(key, scancode)
    local cmd = input:testKey(key .. "-release")
    if cmd then
      --do something with cmd (store it for the next call to love.update, or whatever)
    end
  end
```

##A, B, X, and Y Are Evil Modifiers
The modifier testing code can't distinguish between the keys **a**, **b**, **x**, or **y** 
and the buttons, so be careful when using those buttons as modifiers.

##Axes Have No Direction
inputmangler only knows that an axis being used as a modifier is being pressed, not which
direction it's going in (unless you cheat and use arbitrary strings).

##Filenames and Rawio
Because the rawio version of the load function uses `require` to load the file, the rawio
version of the save function appends ".lua" to whatever filename it's passed.  Normally
this shouldn't matter unless you mix and match modes.


#Earlier Versions of Löve

Joystick and mouse handling have changed in recent version of Löve, which means that some of
inputmangler's functions related to button modifiers will not work in versions before 0.10.0.
Everything else is vanilla Lua except for a few calls to love.keyboard.isDown, which has been
part of the framework since forever, and some filesystem calls in the save/load routines.

##0.9.x
Using mouse buttons as modifiers will not work in Löve 0.9.x or earlier, but the code should
just be bypassed and not cause any problems.  (No, I didn't actually test that, but the logic's
pretty clear.)

##0.8.x or earlier
Joystick handling changed radically in Löve 0.9.0, so in order to use inputmangler in 0.8.x or
earlier, it's necessary to comment out two sections of code:

* In `function InputManager:getModifiers(context)`, comment out everything from `--and finally joystick` to the next blank line.
* In the initialization section at the bottom, comment out everything from `--Set default gamepad to test for modifiers.  For a single-player game, this should Just Work.` to the next `end` keyword.

`addModifierButton` is now useless, but everything else should work, including KeyConstant
modifiers and all context-related functions.
