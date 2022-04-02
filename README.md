
# Nimraygui Editor
A simple editor and "window manager" for nimraylib_now.
The library depends on `nimraylib_now` which is a port of the amazing `raylib`.
This is a thin layer around `raygui` to easily create windows with variables that are editable at runtime.

The package uses templates to encapsulate getter and setter methods for the variable you add using `addProp` to a window
so that you don't have to write them manually. The editor can be toggled using `editor.toggleVisibility()`

# Installation
using nimble and git:
```sh
nimble install https://github.com/EriKWDev/nimraygui_editor
```

or, to run the example:
```sh
git clone git@github.com:EriKWDev/nimraygui_editor.git
cd nimraygui_editor
nimble develop
nim r examples/main.nim
```

# Example
![demo.gif](./demo.gif)


## The example's code
```nim

import nimraygui_editor
import nimraylib_now

template rect*(tx, ty, tw, th = 0.0): Rectangle = Rectangle(x: tx, y: ty, width: tw, height: th)
template rgba*(tr, tg, tb: uint8 = 0, ta: uint8 = 255): Color = Color(r: tr, g: tg, b: tb, a: ta)
template vec3*(tx, ty, tz = 0.0): Vector3 = Vector3(x: tx, y: ty, z: tz)
template vec2*(tx, ty = 0.0): Vector2 = Vector2(x: tx, y: ty)

proc main() =
  setConfigFlags(WINDOW_RESIZABLE or MSAA_4X_HINT)
  initWindow(950, 800, "Nim Editor Example")
  setTargetFPS 0

  let
    editor = newEditor("Editor 1")
    window1 = newEWindow("Window 1, Props using pragma", rect(130, 30, 350, 670))
    window2 = newEWindow("Window 2, Manual props with names", rect(540, 50, 350, 670))

  # Properties can be added using the {.prop: <window>.} pragma...
  var
    testVector2 {.prop: window1.} = vec2(0, 0)
    testFloat {.prop: window1.} = 20.0
    intValue {.prop: window1.} = 42
    background {.prop: window1.} = BLUE
    circleColor {.prop: window1.} = ORANGE
    testVector3 {.prop: window1.} = vec3(0.0, 0.0, 0.0)
    testBool {.prop: window1.} = false

  editor.addWindow window1

  # Properties can also be added manually using addProp and newProp
  # When added manually, addditional options such as a name and
  # .withMinMax can be provided
  window2.addProp newProp(testVector2, "Position").withMinMax(vec2(0, 0), vec2(500, 500))
  window2.addProp newProp(testFloat, "Radius").withMinMax(0.01, 500.0)
  window2.addProp newProp(intValue, "Test Int").withMinMax(-50, 120)
  window2.addProp newProp(background, "Background Color")
  window2.addProp newProp(circleColor, "Circle Color")
  window2.addProp newProp(testVector3, "Test Vector")
  window2.addProp newProp(testBool, "Show FPS")
  editor.addWindow window2

  while not windowShouldClose():
    updateEditor(editor) # Update the editor as often as you like

    beginDrawing():
      clearBackground background

      beginEditor(editor): # Begin drawing the editor. Can also call editor.drawEditor()
        if isKeyPressed(KeyboardKey.F10):
          editor.toggleVisibility() # editor.enabled = not editor.enabled

        drawCircleV(testVector2 + vec2(100.0, 100.0), testFloat, circleColor)
        if testBool:
          drawFPS 10, 10

  closeWindow()


when isMainModule:
  main()

```

# Currently Supported Types
- [X] Vector3
- [X] Vector2
- [X] Color
- [X] float
- [X] int
- [X] bool

- [ ] seq
- [ ] array
- [ ] Tables
- [ ] Enums

# Future goals
- [ ] Arbitrarily nested type editing such as tuples and objects
- [ ] Data serialization and deserialization
  - [ ] Perhaps simple way to copy the code to set the variable as temporary workaround?
- [ ] Dockable windows with tabs

# License
All code in this repository is released under the MIT license.
