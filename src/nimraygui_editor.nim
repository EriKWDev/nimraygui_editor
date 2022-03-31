
import nimraylib_now
import nimraylib_now/raygui

from nimraylib_now/rlgl import translatef, pushMatrix, popMatrix

import std/[algorithm, sequtils]

type
  EditorProperty*[T] = object
    getValue: proc(): T
    setValue: proc(v: T)
    minMax: (T, T)

  EditorEntryKind* = enum
    eekFloat, eekVector2, eekVector3, eekColor

  EditorEntry* = object
    name: cstring
    collapsed: bool

    case kind: EditorEntryKind
    of eekFloat:    floatProperty: EditorProperty[float]
    of eekVector2:  vector2Property: EditorProperty[Vector2]
    of eekVector3:  vector3Property: EditorProperty[Vector3]
    of eekColor:    colorProperty: EditorProperty[Color]

  EditorWindow* = ref object
    title*: cstring
    enabled*: bool
    entries*: seq[EditorEntry]

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

func rect(x, y, w, h = 0.0): Rectangle {.inline.} = Rectangle(x: x, y: y, width: w, height: h)
func rgba(r, g, b: uint8 = 0, a: uint8 = 255): Color {.inline.} = Color(r: r, g: g, b: b, a: a)
func vec3(x, y, z = 0.0): Vector3 {.inline.} = Vector3(x: x, y: y, z: z)
func vec2(x, y = 0.0): Vector2 {.inline.} = Vector2(x: x, y: y)
func contains(rectangle: Rectangle, pos: Vector2): bool =
  return pos.x >= rectangle.x and
         pos.y >= rectangle.y and
         pos.x <= rectangle.width + rectangle.x and
         pos.y <= rectangle.height + rectangle.y


const defaultSize = 100.0
template defaultEntryVals[T](): (cstring, EditorEntryKind, (T, T)) =
  when T is Vector3:
    ("Vector3".cstring, eekVector3, (vec3(-1, -1, -1) * defaultSize, vec3(1, 1, 1) * defaultSize))
  elif T is Vector2:
    ("Vector2".cstring, eekVector2, (vec2(-1, -1) * defaultSize, vec2(1, 1) * defaultSize))
  elif T is float:
    ("Float".cstring, eekFloat, (-defaultSize, defaultSize))
  elif T is Color:
    ("Color".cstring, eekColor, (rgba(0, 0, 0, 0), rgba(255, 255, 255, 255)))

template newEntry*[T](value: T, theName: cstring = "", theMinMax: (T, T)): EditorEntry =
  let default = defaultEntryVals[T]()

  var theResult = EditorEntry(
    kind: default[1],
    name: if theName == "": default[0] else: theName
  )

  let theProperty = EditorProperty[T](
    getValue: proc(): T = value,
    setValue: proc(v: T) = value = v,
    minMax: theMinMax,
  )

  when T is float: theResult.floatProperty = theProperty
  elif T is Vector2: theResult.vector2Property = theProperty
  elif T is Vector3: theResult.vector3Property = theProperty
  elif T is Color: theResult.colorProperty = theProperty

  theResult

template newEntry*[T](value: T, theName: cstring = ""): auto =
  let default = defaultEntryVals[T]()
  newEntry(value, theName, default[2])

func addEntry*(window: EditorWindow, entry: EditorEntry) =
  window.entries.add(entry)


template withState(state: ControlState, body) =
  let oldState = getState()
  setState(state)
  block:
    body
  setState(oldState)

func newEWindow*(title: cstring, bounds: Rectangle): EditorWindow =
  new(result)
  result.title = title
  result.bounds = bounds

  result.enabled = true
  result.dragged = false
  result.active = true
  result.lastPressed = getTime()

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


proc drawEntry(entry: EditorEntry, bounds: Rectangle): float =
  var
    x = bounds.x
    y = bounds.y

  proc drawBox(h: float): float =
    groupBox(rect(x, y, bounds.width, h), entry.name)
    return h + 10.0

  proc drawFloat(currentValue: float, minV: float, maxV: float, extra = 0.0): float =
    let theText = textFormat("%04.04f", currentValue)
    result = slider(rect(x + 5.0, y, bounds.width - 55.0, 20.0), "", theText, currentValue, minV, maxV)
    y += 20.0 + extra

  proc drawColor(currentValue: Color, extra = 0.0): Color =
    result = colorPicker(rect(x + 5.0, y, bounds.width - 55.0, 200.0), currentValue)
    y += 200.0 + extra

  case entry.kind

  # Float
  of eekFloat:
    result = drawBox(30.0)
    y += 5.0

    let
      currentValue = entry.floatProperty.getValue()
      (minV, maxV) = entry.floatProperty.minMax
      newValue = drawFloat(currentValue, minV, maxV)
    entry.floatProperty.setValue(newValue)

  # Vector2
  of eekVector2:
    result = drawBox(52.0)
    y += 5.0

    let
      currentValue = entry.vector2Property.getValue()
      (minV, maxV) = entry.vector2Property.minMax
      newx = drawFloat(currentValue.x, minV.x, maxV.x, 2.0)
      newy = drawFloat(currentValue.y, minV.y, maxV.y, 0.0)
    entry.vector2Property.setValue(vec2(newx, newy))

  # Vector3
  of eekVector3:
    result = drawBox(80.0)
    y += 5.0

    let
      currentValue = entry.vector3Property.getValue()
      (minV, maxV) = entry.vector3Property.minMax
      newx = drawFloat(currentValue.x, minV.x, maxV.x, 2.0)
      newy = drawFloat(currentValue.y, minV.y, maxV.y, 2.0)
      newz = drawFloat(currentValue.z, minV.z, maxV.z, 0.0)
    entry.vector3Property.setValue(vec3(newx, newy, newz))

  # Color
  of eekColor:
    result = drawBox(210.0)
    y += 5.0

    let
      currentValue = entry.colorProperty.getValue()
      newValue = drawColor(currentValue)
    entry.colorProperty.setValue(newValue)

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

  beginScissorMode(window.bounds.x.toInt(), window.bounds.y.toInt() + 25, window.bounds.width.toInt(), window.bounds.height.toInt() - 25):
    var
      x = window.bounds.x + 5.0
      y = window.bounds.y + 8.0 + 25.0

    y -= window.scrollOffset.toFloat()

    for i in 0 .. high(window.entries):
      let th = drawEntry(window.entries[i], rect(x, y, w, h - y))
      y += th

    let v = y - window.bounds.y - 25.0
    if v > h or window.scrollOffset > 0:
      window.scrollOffset = scrollBar(rect(window.bounds.x + window.bounds.width - 15.0, window.bounds.y + 25.0, 15.0, window.bounds.height - 25.0), window.scrollOffset, 0, max(v.toInt(), 0))

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