Brushes = require "./brushes"
{circle, line, rect, rectOutline, endDeltoid} = require "./util"

neighbors = (point) ->
  [
    {x: point.x, y: point.y-1}
    {x: point.x-1, y: point.y}
    {x: point.x+1, y: point.y}
    {x: point.x, y: point.y+1}
  ]

shapeTool = (hotkey, offsetX, offsetY, icon, fn) ->
  start = null
  end = null

  hotkeys: hotkey
  iconUrl: icon
  iconOffset:
    x: offsetX
    y: offsetY
  touch: ({position}) ->
    start = position

  move: ({editor, position}) ->
    end = position

    editor.restore()
    fn(editor, editor.canvas, start, end)

  release: ({position, editor}) ->
    editor.restore()
    fn(editor, editor.canvas, start, end)

sizedTool = (hotkey, offsetX, offsetY, icon, options) ->
  previousPosition = null

  OP = (out) ->
    (p) ->
      out(p, options)

  paint = (out) ->
    (p) ->
      brush = Brushes.sizes[self.settings.size.value()]

      brush(p).forEach OP out

  self =
    hotkeys: hotkey
    iconUrl: icon
    iconOffset:
      x: offsetX
      y: offsetY
    touch: ({position, editor})->
      paint(editor.draw) position
      previousPosition = position
    move: ({editor, position})->
      line previousPosition, position, paint(editor.draw)
      previousPosition = position
    release: ->
      previousPosition = null
    settings:
      size:
        type: 'range'
        min: 0
        max: 3
        value: Observable 0

TOOLS =

  pencil: sizedTool "p", 4, 14,
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA5klEQVQ4T5VTuw2DMBB9LmkZg54ZGCDpHYkJYBBYATcUSKnSwAy0iDFoKR0fDgiMDc5JLvy59969OzPchzSesP3+sLFgySoMweMYou/xmWe81VKx5d0CyCQBoghoGgiV/JombwDNzjkwjsAw/A8gswwgBWm6VPdU7L4laPa6BsrSyX6oxTBQ7munO1v9LgCv2ldCWxcWgDV4EDjZbQq0dDKv65ytuxokKdtWO08AagkhTr2/BiD2otBv8hyMurCbPHNaTQ8OBjJScZFs9eChTKMwB8byT5ajkwIC8E22AvyY7j7ZJugLVIZ5EV8R1SQAAAAASUVORK5CYII="

  eraser: sizedTool "e", 4, 11,
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABGdBTUEAAK/INwWK6QAAAIdJREFUeJzNUsERwCAIw15n031wDt0Hl0s/9VoF9NnmZzRBCERfI2zusdOtDABmopRGVoRCrdviADNMiADM6L873Mql2NYiw3E2WItzVi2dSuw8JBHNvQyegcU4vmjNFesWZrHFTSlYQ/RhRDgatKZFnXPy7zMIoVaYa3fH5i3PTHira4r/gQv1W1E4p9FksQAAAABJRU5ErkJggg==",
    color: "transparent"

  dropper:
    hotkeys: "i"
    iconUrl: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABGdBTUEAAK/INwWK6QAAAH1JREFUeJztjrsNhDAUBIfLTOiYsiClCHdEDUT0Q0rscElY3QkJOD4hI1nye/aOFm5S/Ny1sd/l43AdAqoq6hDWsr8aqIsRgLYsKcbRbzpq4wb0OQPQTJNXh+E18ulilFLyfBopJZmzEn+WhuGy5NvklWxKrgpYgrclFj3DDPqoerGlCYunAAAAAElFTkSuQmCC"
    iconOffset:
      x: 13
      y: 13
    touch: ({position, editor}) ->
      editor.activeColor(editor.getColor(position))
    move: ({position, editor}) ->
      editor.activeColor(editor.getColor(position))
    release: ->
      # Return to the previous tool
      editor.activeTool editor.previousTool()

  move: require("./tools/selection")()

  fill:
    hotkeys: "f"
    iconUrl: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABCklEQVQ4T52TPRKCMBCFX0pbj+HY0tJKY+UB8AqchCuYXofCRs9gy3ADW1rKmLeQTIBEZ0wTwu779idZhfQygUml3FIGikPb8ux5MUDM+S9AWAIjRrNNZYDLdov7MEiqx80G576PQqIAJ75NgJMFXPMc6vlcQZYAI842unq/YQ4HoKrGho1iqLqeQWadZuSyLKG1FmeWwMjY7QDCJlAIcQAj4iyDfr1kp4gggVgb9nsPUkXhs1gBJBpX1wFtC20BrpmSjS0pDbD1h8uJeQu+pKaJAmgfy5icQzH/sani9HgkAWLnLTAi0+YeiFmu+QXwEH5EHpAx7EFwld+GybVjOVTJdzBrYOKwGqoP9IV4EbRDWfEAAAAASUVORK5CYII="
    iconOffset:
      x: 12
      y: 13
    touch: ({position, editor}) ->
      color = editor.colorAsInt()

      imageData = editor.getSnapshot()
      {width, height} = imageData

      data = new Uint32Array(imageData.data.buffer)

      set = ({x, y}, color) ->
        if 0 <= x < width
          if 0 <= y < height
            data[y * width + x] = color

      get = ({x, y}) ->
        if 0 <= x < width
          if 0 <= y < height
            data[y * width + x]

      target = get(position)

      return unless target?
      return if color is target

      queue = [position]

      set(position, color)

      # Allow for interrupts if it takes too long
      safetyHatch = width * height

      while(queue.length and safetyHatch > 0)
        position = queue.pop()

        neighbors(position).forEach (position) ->
          pixelColor = get(position)
          if pixelColor is target
            # This is here because I HAVE been burned
            # Later I should fix the underlying cause, but it seems handy to keep
            # a hatch on any while loops.
            safetyHatch -= 1

            set position, color
            queue.push(position)

      editor.putImageData(imageData)

      return

    move: ->
    release: ->

  rect: shapeTool "r", 1, 4,
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAK0lEQVQ4T2NkoBAwUqifYfAY8J9MrzDCvDBqAAPDMAgDMpMBwyBKymR7AQAp1wgR44q8HgAAAABJRU5ErkJggg=="
    (editor, canvas, start, end) ->
      color = editor.activeColor()
      delta = end.subtract(start)

      editor.withCanvasMods (canvas) ->
        canvas.drawRect
          x: start.x
          y: start.y
          width: delta.x
          height: delta.y
          color: color

  rectOutline: shapeTool "shift+r", 1, 4,
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAN0lEQVQ4T2NkoBAwUqifgWoG/CfTJYwwF4AMINU1YD2jBgy7MCAnLcHTATmawXpITX0YFlFsAADRBBIRAZEL0wAAAABJRU5ErkJggg=="
    (editor, canvas, start, end) ->
      delta = end.subtract(start)
      color = editor.activeColor()

      editor.withCanvasMods (canvas) ->
        canvas.drawRect
          x: start.x - 0.5
          y: start.y - 0.5
          width: delta.x
          height: delta.y
          stroke:
            color: color
            width: 1

  circle: shapeTool "c", 0, 0, # TODO: Real offset
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAVklEQVQ4T2NkwA7+YxFmxKYUXRCmEZtirHLICkEKsNqCZjOKOpgGYjXDzIKrp4oBpNqO4gqQC0YNgAQJqeFA3WjESBw48gdWdVTNC8gWk50bCbgeUxoAvXwcEQnwKSYAAAAASUVORK5CYII="
    (editor, canvas, start, end) ->
      circle start, end, (x, y) ->
        editor.draw({x, y})

  line: shapeTool "l", 0, 0,
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAV0lEQVQ4T6XSyQ0AIAgEQOm/aIWHxoNzJTG+GASk9hnE+Z2P3FDMRBjZK0PI/fQyovVeQqzhpRFv+ikkWl+IRID8DRfJAC6SBUykAqhIFXgQBDgQFFjIAMAADxGQlO+iAAAAAElFTkSuQmCC"
    (editor, canvas, start, end) ->
      color = editor.activeColor()

      # Have to draw our own lines if we want them crisp ;_;
      line start, end, editor.draw

module.exports = (I={}, self=Core(I)) ->
  self.extend
    addTool: (tool) ->
      [].concat(tool.hotkeys or []).forEach (hotkey) ->
        self.addHotkey
          hotkey: hotkey
          method: -> self.activeTool tool

      self.tools.push tool

    activeTool: Observable()
    detailTool: Observable()
    previousTool: Observable()

    tools: Observable []

  # TODO: Probably want to let the editor add its own tools so this is more
  # reusable
  Object.keys(TOOLS).forEach (name) ->
    self.addTool TOOLS[name]

  setNthTool = (n) ->
    ->
      if tool = self.tools.get(n)
        self.activeTool tool

  [1..9].forEach (n) ->
    self.addHotkey
      hotkey: n.toString()
      method: setNthTool(n-1)

  self.addHotkey
    hotkey: "0",
    method: setNthTool(9)

  prevTool = null
  self.activeTool.observe (newTool) ->
    self.previousTool prevTool
    prevTool = newTool

  self.activeTool(self.tools()[0])

  return self
