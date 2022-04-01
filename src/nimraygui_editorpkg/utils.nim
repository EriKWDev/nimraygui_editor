import nimraylib_now

template rect*(tx, ty, tw, th = 0.0): Rectangle = Rectangle(x: tx, y: ty, width: tw, height: th)
template rgba*(tr, tg, tb: uint8 = 0, ta: uint8 = 255): Color = Color(r: tr, g: tg, b: tb, a: ta)
template vec3*(tx, ty, tz = 0.0): Vector3 = Vector3(x: tx, y: ty, z: tz)
template vec2*(tx, ty = 0.0): Vector2 = Vector2(x: tx, y: ty)

func contains*(rectangle: Rectangle, pos: Vector2): bool =
  return pos.x >= rectangle.x and
         pos.y >= rectangle.y and
         pos.x <= rectangle.width + rectangle.x and
         pos.y <= rectangle.height + rectangle.y

template withState*(state: ControlState, body) =
  let oldState = getState()
  setState(state)
  block:
    body
  setState(oldState)
