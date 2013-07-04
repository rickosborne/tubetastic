d = (msg) ->
  document.getElementById('debug')?.innerHTML = msg
  console.log msg

window.addEventListener 'load', ( -> FastClick.attach(document.body) ), false

# via: http://indiegamr.com/quickfix-to-enable-touch-of-easeljs-displayobjects-in-cocoonjs/
createjs.Stage.prototype._updatePointerPosition = (id, pageX, pageY) ->
  rect = this._getElementRect this.canvas
  w = this.canvas.width
  h = this.canvas.height
  rect.left = 0 if isNaN(rect.left)
  rect.top = 0 if isNaN(rect.top)
  rect.right = w if isNaN(rect.right)
  rect.bottom = h if isNaN(rect.bottom)
  pageX -= rect.left
  pageY -= rect.top
  pageX /= (rect.right-rect.left)/w
  pageY /= (rect.bottom-rect.top)/h
  o = this._getPointerData(id);
  if (o.inBounds = (pageX >= 0 && pageY >= 0 && pageX <= w-1 && pageY <= h-1))
    o.x = pageX
    o.y = pageY
  else if this.mouseMoveOutside
    o.x = if pageX < 0 then 0 else (pageX > w-1 ? w-1 : pageX)
    o.y = if pageY < 0 then 0 else (pageY > h-1 ? h-1 : pageY)
  o.rawX = pageX;
  o.rawY = pageY;
  if id == this._primaryPointerID
    this.mouseX = o.x
    this.mouseY = o.y
    this.mouseInBounds = o.inBounds

# Port of seedrandom.js by David Bau: http://davidbau.com/encode/seedrandom.js
class SeedRandom
  @init: (initVector) ->
    SeedRandom.initialize window, [], Math, 256, 6, 52
    Math.seedrandom initVector
  @initialize: (global, pool, math, width, chunks, digits) ->
    startdenom = math.pow(width, chunks)
    significance = math.pow(2, digits)
    overflow = significance * 2
    mask = width - 1
    class ARC4
      constructor: (key) ->
        t = key.length
        keylen = key.length
        i = 0
        j = @i = @j = 0
        s = @S = []
        key = [keylen++] unless keylen
        s[i] = i++ while i < width
        for i in [0..width-1]
          s[i] = s[j = mask & (j + key[i % keylen] + (t = s[i]))]
          s[j] = t
        @g width
      g: (count) =>
        r = 0
        t = 0
        i = @i
        j = @j
        s = @S
        while count--
          t = s[i = mask & (i + 1)]
          r = r * width + s[mask & ((s[i] = s[j = mask & (j + t)]) + (s[j] = t))]
        @i = i
        @j = j
        r
    flatten = (obj, depth) ->
      result = []
      typ = (typeof obj)[0]
      if (depth != 0) and (typ == 'o')
        for prop of obj
          try
            result.push(flatten(obj[prop], depth - 1))
          catch e
      return result if result.length
      return obj if typ == 's'
      return obj + '\0'
    mixkey = (seed, key) ->
      stringseed = seed + ''
      smear = 0
      j = 0
      while j < stringseed.length
        key[mask & j] = mask & ((smear ^= key[mask & j] * 19) + stringseed.charCodeAt(j++))
      tostring key
    autoseed = (seed) ->
      try
        global.crypto.getRandomValues(seed = new Uint8Array(width))
        return tostring(seed)
      catch e
      return [+new Date, global, global.navigator.plugins, global.screen, tostring(pool)]
    tostring = (a) ->
      String.fromCharCode.apply(0, a)
    math['seedrandom'] = (seed, use_entropy) ->
      key = []
      if use_entropy
        to_flatten = [seed, tostring(pool)]
      else if 0 of arguments
        to_flatten = seed
      else
        to_flatten = autoseed()
      shortseed = mixkey(flatten(to_flatten, 3), key)
      arc4 = new ARC4(key)
      mixkey(tostring(arc4.S), pool)
      math['random'] = ->
        n = arc4.g chunks
        dd = startdenom
        x = 0
        while n < significance
          n = (n + x) * width
          dd *= width
          x = arc4.g 1
        while n >= overflow
          n /= 2
          dd /= 2
          x >>>= 1
        (n + x) / dd
      shortseed
    mixkey(math.random(), pool)

class AsyncSoundManager
  sounds = {}
  onSoundReady = (evt) =>
    # console.log evt
    sounds[evt.id] = evt
    return
  createjs.Sound.addEventListener 'fileload', createjs.proxy(onSoundReady, @)
  @load: (id) =>
    unless id of sounds
      paths = "audio/tube-#{id}.ogg|audio/tube-#{id}.mp3|audio/tube-#{id}.wav"
      sounds[id] = true
      # console.log "load #{paths}", sounds
      createjs.Sound.registerSound paths, id
    @
  @play: (id, volume = 1.0) =>
    if sounds[id]
      createjs.Sound.play(id).setVolume(volume)
    @

class TileGraphics
  @cache = {}
  @resize: =>
    @cache = {}
  @get: (id) => @cache[id]
  @put: (id, val) => @cache[id] = val

class Tile extends createjs.Container
  @outletRotationsReverse =
    0: { N: 'N', E: 'E', S: 'S', W: 'W' }
    90: { N: 'W', E: 'N', S: 'E', W: 'S' }
    180: { N: 'S', E: 'W', S: 'N', W: 'E' }
    270: { N: 'E', E: 'S', S: 'W', W: 'N' }
  @outletDirections = [ 'N', 'E', 'S', 'W' ]
  @outletOffsets =
    N: { col:  0, row: -1 }
    E: { col:  1, row:  0 }
    S: { col:  0, row:  1 }
    W: { col: -1, row:  0 }
  @directionReverse =
    N: 'S'
    E: 'W'
    S: 'N'
    W: 'E'
  @POWER_NONE    = 0
  @POWER_SOURCED = 1
  @POWER_SUNK    = 2
  @arcShadow = {}
  @arcShadow[@POWER_NONE]    = null
  @arcShadow[@POWER_SOURCED] = new createjs.Shadow('#ff9900', 0, 0, 8)
  @arcShadow[@POWER_SUNK]    = new createjs.Shadow('#0099ff', 0, 0, 8)
  @tileBack = {}
  @tileBack[@POWER_NONE]    = 'rgba(255,255,255,0.25)'
  @tileBack[@POWER_SOURCED] = 'rgba(255,255,255,0.25)'
  @tileBack[@POWER_SUNK]    = 'rgba(255,255,255,0.25)'
  @arcColor = '#eee'
  @padding = 1 / 16
  constructor: (colNum, rowNum, x, y, s, board) ->
    # d 'new Tile(' + x + ',' + y + ',' + s + ')'
    @initialize colNum, rowNum, x, y, s, board
  initialize: (@colNum, @rowNum, x, y, s, @board) ->
    # d 'Tile::initialize'
    super()
    @power = Tile.POWER_NONE
    @id = Tile.makeId(@colNum, @rowNum)
    @outlets =
      N: false
      E: false
      S: false
      W: false
    @rotation = 0
    @outletRotation = 0
    @resize x, y, s
  hasOutletTo: (outletDirection) =>
    originalDirection = Tile.outletRotationsReverse[@outletRotation][outletDirection]
    hasOutlet = @outlets[originalDirection]
    hasOutlet
  getConnectedNeighbors: =>
    ret = {}
    for direction in Tile.outletDirections when @hasOutletTo direction
      neighbor = @neighbor direction
      continue unless neighbor and neighbor.hasOutletTo Tile.directionReverse[direction]
      ret[direction] = neighbor if neighbor
    # console.log "Tile(#{@id}) has neighbors:", ret
    ret
  neighbor: (outletDirection) =>
    offsets = Tile.outletOffsets[outletDirection]
    return @board.tileAt @colNum + offsets.col, @rowNum + offsets.row
  setPower: (@power) =>
  isSourced: => @power == Tile.POWER_SOURCED
  isSunk: => @power == Tile.POWER_SUNK
  @makeId: (colNum, rowNum) => [colNum, rowNum].join(',')
  resize: (x, y, s) =>
    @midpoint = s / 2
    @x = x + @midpoint
    @y = y + @midpoint
    @regX = @midpoint
    @regY = @midpoint

class SourceTile extends Tile
  initialize: (colNum, rowNum, x, y, s, board) ->
    # d 'SourceTile::initialize(' + x + ',' + y + ',' + s + ')'
    super colNum, rowNum, x, y, s, board
    @back = null
    @arc = null
    @power = Tile.POWER_SOURCED
    @outlets['E'] = true
    @resize x, y, s
  setPower: =>
  resize: (x, y, s) =>
    super x, y, s
    @removeAllChildren()
    gfxBack = TileGraphics.get 'sourceBack'
    unless gfxBack
      gfxBack = new createjs.Graphics().beginFill(Tile.tileBack[@power]).drawRoundRect(s * Tile.padding * 3, s * Tile.padding * 3, s * (1 - (6 * Tile.padding)), s * (1 - (6 * Tile.padding)), s * Tile.padding * 6)
      TileGraphics.put 'sourceBack', gfxBack
    back = new createjs.Shape(gfxBack)
    back.shadow = Tile.arcShadow[@power]
    @addChild back
    gfxArc = TileGraphics.get 'sourceArc'
    unless gfxArc
      gfxArc = new createjs.Graphics().beginFill(Tile.arcColor).drawCircle(@midpoint, @midpoint, s / 16).drawRect(@midpoint, @midpoint - s / 16, @midpoint, s / 8)
      TileGraphics.put 'sourceArc', gfxArc
    arc = new createjs.Shape(gfxArc)
    arc.shadow = Tile.arcShadow[@power]
    @addChild arc
    @


class SinkTile extends Tile
  initialize: (colNum, rowNum, x, y, s, board) ->
    # d 'SinkTile::initialize(' + x + ',' + y + ',' + s + ')'
    super colNum, rowNum, x, y, s, board
    @outlets['W'] = true
    @resize x, y, s
  setPower: (power) =>
    return if power == @power
    AsyncSoundManager.play 'boom' if (power == Tile.POWER_SOURCED) and @board.settled
    @arc.shadow = Tile.arcShadow[power]
    # console.log "Sink(#{@colNum},#{@rowNum}).setPower(#{@power} => #{power})"
    @power = power
    @
  resize: (x, y, s) =>
    super x, y, s
    @removeAllChildren()
    gfxBack = TileGraphics.get 'sinkBack'
    unless gfxBack
      gfxBack = new createjs.Graphics().beginFill(Tile.tileBack[@power]).drawRoundRect(s * Tile.padding * 3, s * Tile.padding * 3, s * (1 - (6 * Tile.padding)), s * (1 - (6 * Tile.padding)), s * Tile.padding * 6)
      TileGraphics.put 'sinkBack', gfxBack
    back = new createjs.Shape(gfxBack)
    back.shadow = Tile.arcShadow[@power]
    @addChild back
    gfxArc = TileGraphics.get 'sinkArc'
    unless gfxArc
      gfxArc = new createjs.Graphics().beginFill(Tile.arcColor).drawCircle(@midpoint, @midpoint, s / 16).drawRect(0, @midpoint - s / 16, @midpoint, s / 8)
      TileGraphics.put 'sinkArc', gfxArc
    @arc = new createjs.Shape(gfxArc)
    @arc.shadow = Tile.arcShadow[@power]
    @addChild @arc
    @

class TubeTile extends Tile
  outletRadians =
    N: Math.PI / 2
    E: 0
    S: 3 * Math.PI / 2
    W: Math.PI
  outletProbabilities = [
    { p: 0.05, c: 4, n: 1, b: [ 15 ] }
    { p: 0.50, c: 3, n: 4, b: [ 7, 11, 13, 14 ] }
    { p: 0.90, c: 2, n: 6, b: [ 3, 5, 6, 9, 10, 12 ] }
    { p:    0, c: 1, n: 4, b: [ 8, 4, 2, 1 ] }
  ]
  outletPaths = [
    { s: 'N', d: 'S', t: 'L', x1:  0, y1: -1, x2: 0, y2: 1 }
    { s: 'E', d: 'W', t: 'L', x1: -1, y1:  0, x2: 1, y2: 0 }
    { s: 'N', d: 'E', t: 'A', x:  1, y: -1, a1: outletRadians.N, a2: outletRadians.W, x1:  0, y1: -1, x2:  1, y2:  0 }
    { s: 'E', d: 'S', t: 'A', x:  1, y:  1, a1: outletRadians.W, a2: outletRadians.S, x1:  1, y1:  0, x2:  0, y2:  1 }
    { s: 'S', d: 'W', t: 'A', x: -1, y:  1, a1: outletRadians.S, a2: outletRadians.E, x1:  0, y1:  1, x2: -1, y2:  0 }
    { s: 'W', d: 'N', t: 'A', x: -1, y: -1, a1: outletRadians.E, a2: outletRadians.N, x1: -1, y1:  0, x2:  0, y2: -1 }
    { b: 8, t: 'L', x1:    0, y1:  -1, x2:    0, y2: -1/4 }
    { b: 4, t: 'L', x1:  1/4, y1:   0, x2:    1, y2:    0 }
    { b: 2, t: 'L', x1:    0, y1: 1/4, x2:    0, y2:    1 }
    { b: 1, t: 'L', x1:   -1, y1:   0, x2: -1/4, y2:    0 }
  ]
  outletRotations =
    0: { N: 'N', E: 'E', S: 'S', W: 'W' }
    90: { N: 'E', E: 'S', S: 'W', W: 'N' }
    180: { N: 'S', E: 'W', S: 'N', W: 'E' }
    270: { N: 'W', E: 'N', S: 'E', W: 'S' }
  initialize: (colNum, rowNum, x, y, s, board) ->
    # d 'TubeTile::initialize(' + x + ',' + y + ',' + s + ')'
    super colNum, rowNum, x, y, s, board
    r = Math.random()
    @outletBits = 0
    @outletCount = 0
    for prob in outletProbabilities
      if (prob.p == 0) or (r <= prob.p)
        @outletBits = prob.b[Math.floor(Math.random() * prob.b.length)]
        @outletCount = prob.c
        break
    @outlets =
      N: !!(@outletBits & 8)
      E: !!(@outletBits & 4)
      S: !!(@outletBits & 2)
      W: !!(@outletBits & 1)
    @spinRemain = 0
    @resize x, y, s
    @ready = true
    # @addEventListener 'click', @onClick
    AsyncSoundManager.load 'sh'
  resize: (x, y, s) =>
    super x, y, s
    @removeAllChildren()
    gfxBack = TileGraphics.get 'tileBack'
    unless gfxBack
      gfxBack = new createjs.Graphics().beginFill(Tile.tileBack[Tile.POWER_NONE]).drawRoundRect(s * Tile.padding, s * Tile.padding, s * (1 - (2 * Tile.padding)), s * (1 - (2 * Tile.padding)), s * Tile.padding * 2)
      TileGraphics.put 'tileBack', gfxBack
    @back = new createjs.Shape(gfxBack)
    @back.shadow = Tile.arcShadow[@power]
    @addChild @back
    gfxArc = TileGraphics.get 'tileArc' + @outletBits
    unless gfxArc
      gfxArc = new createjs.Graphics().setStrokeStyle(s / 8).beginStroke(Tile.arcColor)
      for path in outletPaths when (('b' of path) and (@outletBits == path.b)) or (('s' of path) and @outlets[path.s] and @outlets[path.d])
        gfxArc.moveTo(path.x2 * @midpoint, path.y2 * @midpoint)
        switch path.t
          when 'L' then gfxArc.lineTo(path.x1 * @midpoint, path.y1 * @midpoint)
          when 'A' then gfxArc.arc(path.x * @midpoint, path.y * @midpoint, @midpoint, path.a1, path.a2, false)
          else false
      gfxArc.endStroke()
      TileGraphics.put 'tileArc' + @outletBits, gfxArc
    @arc = new createjs.Shape(gfxArc)
    @arc.shadow = Tile.arcShadow[@power]
    @arc.x = @midpoint
    @arc.y = @midpoint
    @addChild @arc
    @
  onClick: =>
    # console.log "TubeTile(#{@id})::click", evt, @board.ready
    return unless @board.ready
    @spinRemain++
    @spin() if @ready
  spin: =>
    if (@spinRemain > 0)
      AsyncSoundManager.play 'sh', 0.3
      @ready = false
      @spinRemain--
      createjs.Tween.get(@)
        .to({scaleX:0.7,scaleY:0.7}, 25)
        .to({rotation:@rotation + 90}, 100)
        .to({scaleX:1,scaleY:1}, 25)
        .call(@spin)
      @setPower false
      @board.interruptSweep()
    else
      @rotation %= 360 if @rotation >= 360
      @outletRotation = @rotation
      @board.readyForSweep()
      @ready = true
  setPower: (power) =>
    return if power == @power
    shadow = Tile.arcShadow[power]
    @arc.shadow = shadow
    @back.shadow = shadow
    @power = power
    @
  vanish: (onGone) =>
    @ready = false
    @setPower Tile.POWER_NONE
    if @board.settled
      createjs.Tween.get(@)
        .to({alpha:0, scaleX: 0, scaleY: 0}, 500)
        .call(onGone)
    else
      onGone()
      # console.log "skipping anim for Tile(#{@id}).vanish"
    @
  dropTo: (colNum, rowNum, x, y, onDropped) =>
    # console.log "Tile(#{@id}).dropTo(#{colNum},#{rowNum},#{x},#{y})"
    @ready = false
    @setPower Tile.POWER_NONE
    dropDone = =>
      @colNum = colNum
      @rowNum = rowNum
      @id = Tile.makeId(colNum, rowNum)
      onDropped(this, colNum, rowNum)
      @ready = true
    if @board.settled
      createjs.Tween.get(@)
        .to({x: x + @midpoint, y: y + @midpoint}, 250)
        .call(dropDone)
    else
      @x = x + @midpoint
      @y = y + @midpoint
      dropDone()
      # console.log "skipping anim for Tile(#{@id}).drop"
    @

class GameBoard extends createjs.Container
  constructor: (@stage, @sourceCount, @hopDepth) ->
    # d 'new GameBoard(...,rows=' + @sourceCount + ',cols=' + @hopDepth + ')'
    @initialize(@sourceCount, @hopDepth)
  initialize: (@sourceCount, @hopDepth) ->
    # d 'GameBoard::initialize(rows=' + @sourceCount + ',cols=' + @hopDepth + ')'
    super()
    @board = []
    @resize()
    for rowNum in [0..@sourceCount-1]
      row = []
      for colNum in [0..@hopDepth-1]
        tileType = TubeTile
        if colNum == 0
          tileType = SourceTile
        else if colNum == @hopDepth - 1
          tileType = SinkTile
        tile = new tileType(colNum, rowNum, @xForColumn(colNum), @yForRow(rowNum), @tileSize, @)
        @addChild tile
        row.push tile
      @board.push row
    @settled = false
    @powerSweep()
    return
  resize: =>
    @tileSize = Math.floor Math.min(@stage.canvas.width / @hopDepth, @stage.canvas.height / @sourceCount)
    @x = Math.floor (@stage.canvas.width - (@tileSize * @hopDepth)) / 2
    @y = Math.floor (@stage.canvas.height - (@tileSize * @sourceCount)) / 2
    console.log "board #{@x},#{@y} size:#{@tileSize} #{@stage.canvas.width}x#{@stage.canvas.height}"
    TileGraphics.resize()
    for row, rowNum in @board
      for tile, colNum in row
        tile.resize @xForColumn(colNum), @yForRow(rowNum), @tileSize
  xForColumn: (colNum) => colNum * @tileSize
  yForRow: (rowNum) => rowNum * @tileSize
  readyForSweep: =>
    @sweepTimer = setTimeout(@powerSweep, 125) unless @sweepTimer
  interruptSweep: =>
    if @sweepTimer
      clearTimeout @sweepTimer
      @sweepTimer = null
  powerSweep: =>
    sweepStart = Date.now()
    @ready = false
    toCheck = []
    toCheck.push @board[rowNum][0] for rowNum in [@sourceCount - 1..0] by -1
    sourced = {}
    sunk = {}
    neither = {}
    toRemove = {}
    for rowNum in [0..@sourceCount-1]
      for colNum in [0..@hopDepth-1]
        neither[Tile.makeId(colNum, rowNum)] = @board[rowNum][colNum]
    while toCheck.length > 0
      tile = toCheck.pop()
      tile.setPower Tile.POWER_SOURCED unless tile.power == Tile.POWER_SOURCED
      sourced[tile.id] = true
      delete neither[tile.id]
      toRemove[tile.id] = tile if tile instanceof SinkTile
      toCheck.push neighbor for direction, neighbor of tile.getConnectedNeighbors() when neighbor.id not of sourced
    toCheck.push @board[rowNum][@hopDepth-1] for rowNum in [@sourceCount - 1..0] by -1 when "#{@hopDepth-1},#{rowNum}" not of sourced
    while toCheck.length > 0
      tile = toCheck.pop()
      tile.setPower Tile.POWER_SUNK unless tile.power == Tile.POWER_SUNK
      sunk[tile.id] = true
      delete neither[tile.id]
      toCheck.push neighbor for direction, neighbor of tile.getConnectedNeighbors() when (neighbor.id not of sourced) and (neighbor.id not of sunk)
    tile.setPower Tile.POWER_NONE for id, tile of neither when tile.power isnt Tile.POWER_NONE
    toCheck.push tile for id, tile of toRemove
    if toCheck.length == 0
      @ready = true
      @sweepTimer = null
      @settled = true
      d 'powerSweep took ' + (Date.now() - sweepStart) + 'ms'
      # console.log 'board ready'
    vanishCount = 0
    dropCount = 0
    toVanish = []
    toDrop = []
    onVanished = =>
      vanishCount--
      return unless vanishCount <= 0
      console.log 'all destroyed'
      onDropped = (tile, colNum, rowNum) =>
        dropCount--
        @board[rowNum][colNum] = tile
        return unless dropCount <= 0
        setTimeout @powerSweep, 0
      for colNum in [1..@hopDepth-2]
        destRowNum = @sourceCount
        colX = @xForColumn(colNum)
        for rowNum in [@sourceCount-1..0] by -1
          tile = @board[rowNum][colNum]
          if tile.id of toRemove
            @board[rowNum][colNum] = null
            @removeChild tile
          else
            destRowNum--
            if destRowNum > rowNum
              dropCount++
              toDrop.push {tile: tile, colNum: colNum, rowNum: destRowNum, colX: colX}
              @board[rowNum][colNum] = null
        for rowNum in [destRowNum-1..0] by -1
          dropCount++
          tile = new TubeTile(-2, -2, colX, @yForRow(rowNum - destRowNum), @tileSize, @)
          toDrop.push {tile: tile, colNum: colNum, rowNum: rowNum, colX: colX}
          @addChild tile
      drop.tile.dropTo drop.colNum, drop.rowNum, drop.colX, @yForRow(drop.rowNum), onDropped for drop in toDrop
    while toCheck.length > 0
      tile = toCheck.pop()
      toRemove[tile.id] = tile
      toCheck.push neighbor for direction, neighbor of tile.getConnectedNeighbors() when neighbor.id not of toRemove
      continue unless tile instanceof TubeTile
      toVanish.push tile
      vanishCount++
    tile.vanish onVanished for tile in toVanish
    @
  tileAt: (colNum, rowNum) =>
    return @board[rowNum][colNum] if (colNum >= 0) and (colNum < @hopDepth) and (rowNum >= 0) and (rowNum < @sourceCount)
    return null

class TubetasticGame
  constructor: (canvasName) ->
    SeedRandom.init("TubeTastic!")
    # d 'TubetasticGame'
    AsyncSoundManager.load 'sh'
    AsyncSoundManager.load 'boom'
    @stage = new createjs.Stage(canvasName)
    createjs.Ticker.setFPS 30
    createjs.Ticker.useRAF = true
    createjs.Ticker.addEventListener 'tick', => @stage.update()
    board = new GameBoard(@stage, 8, 7)
    @stage.addChild board
    createjs.Touch.enable @stage, true, false
    window.onresize = =>
      @stage.canvas.width = window.innerWidth
      @stage.canvas.height = window.innerHeight
      board.resize()
    window.onresize()

new TubetasticGame('gameCanvas')
