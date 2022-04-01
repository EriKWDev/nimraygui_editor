
import nimraygui_editor
import nimraylib_now

template rect*(tx, ty, tw, th = 0.0): Rectangle = Rectangle(x: tx, y: ty, width: tw, height: th)
template rgba*(tr, tg, tb: uint8 = 0, ta: uint8 = 255): Color = Color(r: tr, g: tg, b: tb, a: ta)
template vec3*(tx, ty, tz = 0.0): Vector3 = Vector3(x: tx, y: ty, z: tz)
template vec2*(tx, ty = 0.0): Vector2 = Vector2(x: tx, y: ty)

proc main() =
  setConfigFlags(WINDOW_RESIZABLE or MSAA_4X_HINT)
  initWindow(800, 700, "Nim Editor Example")
  setTargetFPS 60

  let
    editor = newEditor("Editor 1")
    window1 = newEWindow("Window 1", rect(130, 30, 350, 620))

  var
    testVector2 {.prop: window1.} = vec2(0, 0)
    testFloat {.prop: window1.} = 20.0
    background {.prop: window1.} = BLACK
    circleColor {.prop: window1.} = RED
    testVector3 {.prop: window1.} = vec3(0.0, 0.0, 0.0)
    testBool {.prop: window1.} = false

  editor.addWindow window1

  while not windowShouldClose():
    updateEditor(editor)

    beginDrawing():
      clearBackground background

      beginEditor(editor):
        if isKeyPressed(KeyboardKey.F10):
          editor.enabled = not editor.enabled

        drawCircleV(testVector2 + vec2(100.0, 100.0), testFloat, circleColor)
        if testBool:
          drawFPS 10, 10

  closeWindow()


when isMainModule:
  main()
