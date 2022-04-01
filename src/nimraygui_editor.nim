import std/[algorithm, macros, sequtils, strformat]

import nimraygui_editorpkg/[utils]

import nimraylib_now
import nimraylib_now/raygui
from nimraylib_now/rlgl import translatef, pushMatrix, popMatrix

# Properties

type
  PropertyKind* = enum
    pkNone, pkFloat, pkVector2, pkVector3, pkColor

  PropData*[T] = object
    name: cstring

    getValue*: proc(): T
    setValue*: proc(v: T)
    minMax*: (T, T)
    hasMinMax*: bool

  Properties* = ref object
    kinds*: seq[(PropertyKind, int)]

    floatData*: seq[PropData[float]]
    vector3Data*: seq[PropData[Vector3]]
    vector2Data*: seq[PropData[Vector2]]
    colorData*: seq[PropData[Color]]

  Prop*[T] = tuple
    kind: PropertyKind
    data: PropData[T]


template propTToPK(t: typedesc): PropertyKind =
  when t is float: pkFloat
  elif t is Vector3: pkVector3
  elif t is Vector2: pkVector2
  elif t is Color: pkColor
  else: pkNone

func betterName(kind: PropertyKind, title: cstring = ""): cstring {.inline.} =
  if title == "":
    ($kind)[2..high($kind)].cstring
  else:
    title

template withMinMax*[T](base: Prop[T], minV: T, maxV: T): Prop[T] =
  (
    base.kind,
    PropData[T](
      name: base.data.name,
      getValue: base.data.getValue,
      setValue: base.data.setValue,
      hasMinMax: true,
      minMax: (minV, maxV)
    )
  )

template newProp*[T](value: T, theName: cstring = ""): Prop[T] =
  (
    propTToPK(typeof(value)),
    PropData[T](
      name: betterName(propTToPK(typeof(value)), theName.cstring),
      hasMinMax: false,
      getValue: proc(): T = value,
      setValue: proc(v: T) = value = v
    )
  )

template addProp*[T](props: Properties, prop: Prop[T]) =
  var id = -1

  # This is here to give a compiel time error when I forget to
  # add a when clause for a type
  case prop.kind
  of pkFloat, pkVector3, pkVector2, pkColor, pkNone: discard

  when T is float:
    id = len(props.floatData)
    props.floatData.add(prop.data)
    props.floatData[id].minMax = prop.data.minMax

  elif T is Vector3:
    id = len(props.vector3Data)
    props.vector3Data.add(prop.data)
    props.vector3Data[id].minMax = prop.data.minMax

  elif T is Vector2:
    id = len(props.vector2Data)
    props.vector2Data.add(prop.data)
    props.vector2Data[id].minMax = prop.data.minMax

  elif T is Color:
    id = len(props.colorData)
    props.colorData.add(prop.data)
    props.colorData[id].minMax = prop.data.minMax

  else: discard
  props.kinds.add((prop.kind, id))

proc drawProps*(props: Properties, tx, ty: float, bounds: Rectangle): float =
  var
    x = tx
    y = ty

  proc drawBox(h: float, title: cstring = "") =
    groupBox(rect(x, y, bounds.width - 10.0, h), title)
    y += 5.0

  proc drawColor(value: Color): Color =
    result = colorPicker(rect(x, y, bounds.width - 50.0, 150.0), value)
    y += 150.0

  proc drawFloat(value: float, minV: float, maxV: float, extra = 0.0, left: cstring = ""): float =
    let
      right = textFormat("%03.03f", value)
      realBounds = block:
        if left == "":
          rect(x, y, bounds.width - 60.0, 20.0)
        else:
          let d = measureText(left, 16).toFloat() + 5.0
          rect(x + d, y, bounds.width - 60.0 - d, 20.0)

    result = slider(realBounds, left, right, value, minV, maxV)
    y += 20.0 + extra

  for (kind, id) in props.kinds:
    case kind
    of pkFloat:
      let data = props.floatData[id]
      drawBox(30.0, data.name)

      x += 5.0
      var (minV, maxV) = data.minMax
      if not data.hasMinMax:
        (minV, maxV) = (-100.0, 100.0)

      let
        currentValue = data.getValue()
        newValue = drawFloat(currentValue, minV, maxV)
      data.setValue(newValue)
      x -= 5.0
      y += 15.0

    of pkVector3:
      let data = props.vector3Data[id]
      drawBox(74.0, data.name)

      x += 5.0
      var (minV, maxV) = data.minMax
      if not data.hasMinMax:
        (minV, maxV) = (vec3(-100.0, -100.0, -100.0), vec3(100.0, 100.0, 100.0))

      let
        currentValue = data.getValue()
        newValueX = drawFloat(currentValue.x, minV.x, maxV.x, 2.0, "x:")
        newValueY = drawFloat(currentValue.y, minV.y, maxV.y, 2.0, "y:")
        newValueZ = drawFloat(currentValue.z, minV.z, maxV.z, 0.0, "z:")
      data.setValue(vec3(newValueX, newValueY, newValueZ))
      x -= 5.0
      y += 15.0

    of pkVector2:
      let data = props.vector2Data[id]
      drawBox(52.0, data.name)

      x += 5.0
      var (minV, maxV) = data.minMax
      if not data.hasMinMax:
        (minV, maxV) = (vec2(-100.0, -100.0), vec2(100.0, 100.0))

      let
        currentValue = data.getValue()
        newValueX = drawFloat(currentValue.x, minV.x, maxV.x, 2.0, "x:")
        newValueY = drawFloat(currentValue.y, minV.y, maxV.y, 0.0, "y:")
      data.setValue(vec2(newValueX, newValueY))
      x -= 5.0
      y += 15.0

    of pkColor:
      let data = props.colorData[id]
      drawBox(160.0, data.name)
      x += 5.0

      let
        currentValue = data.getValue()
        newValue = drawColor(currentValue)
      data.setValue(newValue)

      x -= 5.0
      y += 15.0

    of pkNone: discard

  return y - ty

macro prop*(properties, propVarNode) =
  echo treeRepr(propVarNode)
  propVarNode.expectKind(nnkVarSection)

  result = newStmtList()

  for identDef in propVarNode:
    let
      tmp = identDef.children.toSeq()
      (varName, _, def) = (tmp[0], tmp[1], tmp[2])
      name = newLit($varName)

    result.add quote do:
      var `varName` = `def`
      `properties`.addProp newProp(`varName`, $`name`)


# Editor

type
  EditorWindow* = ref object
    title*: cstring
    enabled*: bool
    props*: Properties

    bounds: Rectangle
    dragged: bool
    resized: bool

    lastPressed: float
    active: bool
    scrollOffset: int

  Editor* = ref object
    title*: cstring
    enabled*: bool
    windows*: seq[EditorWindow]

    didDrag: bool

template addProp*[T](window: EditorWindow, prop: Prop[T]) =
  window.props.addProp(prop)

proc newEWindow*(title: cstring, bounds: Rectangle): EditorWindow =
  new(result)
  result.title = title
  result.bounds = bounds

  result.enabled = true
  result.dragged = false
  result.active = true
  result.lastPressed = getTime()
  result.props = Properties.new()

func addWindow*(editor: Editor, window: EditorWindow) =
  editor.windows.add(window)

func updateEWindow*(editor: Editor, window: EditorWindow) =
  if not window.enabled: return

  let
    mousePos = getMousePosition()
    delta = getMouseDelta()

  if not editor.didDrag:
    if isMouseButtonPressed(MouseButton.LEFT):
      # Header
      let
        headerBounds = rect(window.bounds.x, window.bounds.y, window.bounds.width, 25.0)

      if mousePos in headerBounds:
        window.dragged = true
        window.lastPressed = getTime()
        editor.didDrag = true

      # Resize
      let
        resizeSide = 10.0
        resizeBounds = rect(
          window.bounds.x + window.bounds.width - resizeSide/2.0,
          window.bounds.y + window.bounds.height - resizeSide/2.0,
          resizeSide, resizeSide
        )

      if mousePos in resizeBounds:
        window.resized = true
        window.lastPressed = getTime()
        editor.didDrag = true

    else:
      if isMouseButtonDown(MouseButton.LEFT):
        # Dragging
        if window.dragged:
          window.bounds.x += delta.x
          window.bounds.y += delta.y
          window.lastPressed = getTime()
          editor.didDrag = true

        # Resizing
        if window.resized:
          window.bounds.width += delta.x
          window.bounds.height += delta.y
          window.lastPressed = getTime()
          editor.didDrag = true

      else:
        window.dragged = false
        window.resized = false


  window.bounds.x = max(window.bounds.x, 0.0)
  window.bounds.y = max(window.bounds.y, 25.0)
  window.bounds.x = min(window.bounds.x, (getScreenWidth() - 25).toFloat())
  window.bounds.y = min(window.bounds.y, (getScreenHeight() - 25).toFloat())
  window.bounds.width = max(window.bounds.width, measureText(window.title, 20).toFloat())
  window.bounds.height = max(window.bounds.height, 30.0)

proc drawEWindow*(window: EditorWindow) =
  if not window.enabled: return

  let state = if window.active: STATE_FOCUSED else: STATE_DISABLED

  var requestClose = false
  withState state:
    requestClose = windowBox(window.bounds, window.title)

  if requestClose:
    window.enabled = false

  let
    w = window.bounds.width - 5.0*2
    h = window.bounds.height - 25.0 - 5.0*2

  beginScissorMode(window.bounds.x.toInt(), window.bounds.y.toInt() + 25, window.bounds.width.toInt(),
      window.bounds.height.toInt() - 25):
    var
      x = window.bounds.x + 5.0
      y = window.bounds.y + 8.0 + 25.0

    y -= window.scrollOffset.toFloat()
    y += window.props.drawProps(x, y, window.bounds)

    let v = max(y - window.bounds.y - 25.0, 0.0)
    if v > h or window.scrollOffset > 0:
      let scrollRect = rect(window.bounds.x + window.bounds.width - 15.0,
                            window.bounds.y + 25.0,
                            15.0,
                            window.bounds.height - 25.0)

      window.scrollOffset = scrollBar(scrollRect, window.scrollOffset, 0, v.toInt())

  let
    resizeSide = 10.0
    resizeBounds = rect(
      window.bounds.x + window.bounds.width - resizeSide/2.0,
      window.bounds.y + window.bounds.height - resizeSide/2.0,
      resizeSide, resizeSide
    )

  panel(resizeBounds)

func newEditor*(title: cstring): Editor =
  new(result)
  result.title = title
  result.enabled = true
  result.windows = @[]

  if fileExists("theme.txt.rgs"):
    loadStyle("theme.txt.rgs")

func updateEditor*(editor: Editor) =
  if not editor.enabled: return

  editor.didDrag = false

  for i in countdown(high(editor.windows), 0):
    editor.windows[i].active = false
    updateEWindow(editor, editor.windows[i])

  editor.windows.sort() do (a, b: EditorWindow) -> int:
    ((a.lastPressed - b.lastPressed) * 10.0).toInt()

  if len(editor.windows) > 0:
    editor.windows[high(editor.windows)].active = true

proc drawEditor*(editor: Editor) =
  if not editor.enabled: return

  for i in 0 .. high(editor.windows):
    lock()
    if i == high(editor.windows):
      unlock()
    drawEWindow(editor.windows[i])

  let sortedByName = editor.windows.sortedByIt(it.title)
  panel(rect(0, 0, getScreenWidth().toFloat(), 25))

  var
    initial = editor.windows.anyIt(it.enabled)
    x = measureText(editor.title, 15).toFloat()

  var pressedEditor = false
  let state = if initial: STATE_PRESSED else: STATE_NORMAL
  withState state:
    pressedEditor = button(rect(0, 0, x, 25), editor.title)

  if pressedEditor:
    for window in editor.windows:
      window.enabled = not initial

  for i in 0 .. high(sortedByName):
    let
      title = sortedByName[i].title
      w = measureText(title, 15).toFloat()
      bw = 10.0
      pressed = checkBox(rect(x + 3.0, 2.0, bw, 25 - 4.0), title, sortedByName[i].enabled)

    x += w + bw

    sortedByName[i].enabled = pressed

template beginEditor*(editor: Editor, body) =
  pushMatrix()
  if editor.enabled:
    translatef(0.0, 25.0, 0.0)
  block:
    body
  popMatrix()
  drawEditor(editor)


# Example

when isMainModule:
  let
    window1 = newEWindow("Window 1", rect(30, 30, 300, 600))
    # editor = newEditor("Editor 1")

  var
    testVector2 = vec2(0, 0)
    testFloat = 20.0

    background = BLACK
    circleColor = RED

  window1.addProp newProp(testVector2, "Position").withMinMax(vec2(-100, -100), vec2(500, 500))
  window1.addProp newProp(testFloat, "Radius").withMinMax(0.001, 500.0)
  window1.addProp newProp(circleColor, "Circle")
  window1.addProp newProp(background, "Background")

  # editor.addWindow window1
