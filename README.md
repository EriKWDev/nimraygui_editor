

# Nimraygui Editor
A simple editor and "window manager" for nimraylib_now.
The library depends on `nimraylib_now` which is a port of the amazing `raylib`.
This is a thin layer around `raygui` to easily create windows with variables that are editable at runtime.

# Example
![demo.gif](./demo.gif)

```nim
import nimraygui_editor
import nimraylib_now

func rect(x, y, w, h = 0.0): Rectangle {.inline.} = Rectangle(x: x, y: y, width: w, height: h)
func rgba(r, g, b, a: uint8 = 0): Color {.inline.} = Color(r: r, g: g, b: b, a: a)
func vec3(x, y, z = 0.0): Vector3 {.inline.} = Vector3(x: x, y: y, z: z)
func vec2(x, y = 0.0): Vector2 {.inline.} = Vector2(x: x, y: y)

proc main() =
  setConfigFlags(WINDOW_RESIZABLE or MSAA_4X_HINT)
  initWindow(800, 700, "Nim Editor Example")

  var
    testVector2 = vec2(0, 0)
    testFloat = 20.0

    background = BLACK
    circleColor = RED

  let
    editor = newEditor("Editor 1")
    window2 = newEWindow("Window 2", rect(50, 50, 400, 500))
    window1 = newEWindow("Window 1", rect(30, 30, 300, 600))

  window1.addEntry newEntry(testVector2, "Position")
  window1.addEntry newEntry(testFloat, "Radius", (0.001, 500.0))
  window1.addEntry newEntry(circleColor, "Circle")
  window1.addEntry newEntry(background, "Background")
  editor.addWindow window1

  window2.addEntry newEntry(testVector2)
  window2.addEntry newEntry(testFloat)
  editor.addWindow window2


  while not windowShouldClose():
    updateEditor(editor)

    beginDrawing():
      clearBackground background

      beginEditor(editor):
        if isKeyPressed(KeyboardKey.F10):
          editor.enabled = not editor.enabled

        drawCircleV(testVector2 + vec2(100.0, 100.0), testFloat, circleColor)

        drawFPS 10, 10


  closeWindow()


when isMainModule:
  main()

```