UltraSyncView = require './ultra-sync-view'
{CompositeDisposable} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
# Added maplists
module.exports = UltraSync =
  ultraSyncView: null
  modalPanel: null
  subscriptions: null
  mapList : null
  offset : null
  editor : null
  paneView : null
  editorView : null
  holes : null
  mapLists : null
  offsets : null
  synced : false
  items : null
  paneList : null
  activate: (state) ->
    @mapLists = []
    @offsets = []
    @paneList =[]
    @ultraSyncView = new UltraSyncView(state.ultraSyncViewState)
    # @modalPanel = atom.workspace.addModalPanel(item: @ultraSyncView.getElement(), visible: false)
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'ultra-sync:toggle': => @toggle()
    @subscriptions.add atom.workspace.observeActivePaneItem (pane) =>
      if atom.workspace.isTextEditor(pane)
        @editor = pane
      else
        @paneView = atom.views.getView(pane)

  deactivate: ->
    @subscriptions.dispose()
    @ultraSyncView.destroy()

  toggle: ->
    @editor = atom.workspace.getActiveTextEditor()
    if @editor?
      @editorView = atom.views.getView(@editor)
      panes = atom.workspace.getPanes()
      @items = panes[panes.length - 1].getItems()
      if panes.length > 1
        @mapLists[@editor.id] = []
        @offsets[@editor.id] = []
        pane = panes[panes.length - 1].activeItem
        @paneList[@editor.id] = atom.views.getView(pane)
        @paneView = atom.views.getView(pane)
        config = { subtree: true, childList: true, characterData: true }
        observer = new MutationObserver((mutation) => @sync() )
        observer.observe(@paneView, config)
        # @paneView.addEventListener("DOMSubtreeModified", (() => @sync()), {once:true})
        @subscriptions.add @editorView.onDidChangeScrollTop => @ultraSync()
        @subscriptions.add @editor.buffer.onDidStopChanging =>
          @synced = false
        @synced = false
        @sync()

  matchWords: (A, B, j) ->
    if A? and B?
      size1 = A.length
      size2 = B.length
      if j >= size2
        return 0
      else
        iter = 0
        while iter < 50 && j + iter < size2
          if A[0] == B[j + iter]
            if B[j+size1 + iter - 1] == A[size1 - 1]
              return j + size1 + iter
          iter = iter + 1
    return -1

  matchWordsLatest: (A, B, textLine, textView, j) ->
    if A? and B?
      size1 = A.length
      size2 = B.length
      if j >= size2
        return 0
      else
        iter = 0
        while iter < 50 && j + iter < size2
          if A[0] == B[j + iter]
            if B[j+size1 + iter - 1] == A[size1 - 1]
              return j + size1 + iter
          iter = iter + 1
      A = textLine.match /[A-Za-z]+/ig
      B = textView.match /[A-Za-z]+/ig
      if A? and B?
        size3 = A.length
        if size3/size1 > 0.3
          size1 = size3
          size2 = B.length
          iter = 0
          while iter < 50 && j + iter < size2
            if A[0] == B[j + iter]
              if B[j+size1 + iter - 1] == A[size1 - 1]
                return j + size1 + iter
            iter = iter + 1
    return -1

  placeInNodes: (nodes, buf, length, i) ->
    size = nodes.length
    counter = i
    while counter < size
      k = @checkIfNodeExists(nodes, length, counter, buf)
      if k != -1
        return {"line":k; "node":counter}
      counter = counter + 1
    return null

  calculateOffset: (start, end, nodes, i) ->
    countLines = 0
    buf = start
    while start <= end
      if @mapLists[@editor.id][start] != null
        @offsets[@editor.id][start] = countLines
        countLines = countLines + 1
      start = start + 1
    start = buf
    while start <= end
      if @mapLists[@editor.id][start] != null
        @offsets[@editor.id][start] = @offsets[@editor.id][start]/countLines
      start = start + 1

  nearVision: (buf, i, nodes) ->
    counter = i
    line = @editor.lineTextForBufferRow buf
    line = line?.replace(/(\<[^>]*\>)*/ig, '')
    matches = line?.match /[A-Za-z0-9]+/ig
    nodeSize = nodes.length
    while counter < nodeSize
      text = nodes[counter].node.innerText
      text = text.replace(/(\<[^>]*\>)+/ig, '')
      matchesNode = text.match /[A-Za-z0-9]+/ig
      k = @matchWordsLatest(matches, matchesNode, line, text, 0)
      if k != -1
        j = 0
        giter = 0
        maxiter = 0
        size = matchesNode.length
        while maxiter < 10
          if giter >= 5
            return true
          localLine = @editor.lineTextForBufferRow (buf + maxiter)
          localLine = localLine?.replace(/(\<[^>]*\>)*/ig, '')
          localMatches = localLine?.match /[A-Za-z0-9]+/ig
          l = @matchWordsLatest(localMatches, matchesNode, localLine, text, j)
          if l >= size
            return true
          else
            if l >= 1
              j = l
              giter = giter + 1
          maxiter = maxiter + 1
      counter = counter + 1
    return false

  checkIfNodeExists: (nodes, length, i, buf) ->
    # console.log "START"
    text = nodes[i].node.innerText
    text = text.replace(/(\<[^>]*\>)+/ig, '')
    matches2 = text.match /[A-Za-z0-9]+/ig
    if not matches2
      return -1
    matched = false
    size = matches2.length
    counter = buf
    j = 0
    matchedWords = 0
    lastSuccessful = -1
    nullIterations = 0
    while counter < length
      if nullIterations > 0.25 * length
        # console.log "NULL"
        if matchedWords/size > 0.8
          return lastSuccessful
        return -1
      line = @editor.lineTextForBufferRow counter
      line = line?.replace(/(\<[^>]*\>)*/ig, '')
      matches = line?.match /[A-Za-z0-9]+/ig
      if matches
        # console.log matches
        # console.log matches2
        k = @matchWordsLatest(matches, matches2, line, text, j)
        if k >= size
          # console.log "DONE"
          @offsets[@editor.id][counter] = j/size
          @mapLists[@editor.id][counter] = nodes[i]
          return counter
        if k >= 1
          # console.log matches
          # console.log "TADA"
          @offsets[@editor.id][counter] = j/size
          lastSuccessful = counter
          j = k
          matchedWords = matchedWords + matches.length
          @mapLists[@editor.id][counter] = nodes[i]
        else
          if not @mapLists[@editor.id][counter]
            if matchedWords/size > 0.8
              # console.log "NEAR"
              # console.log j
              if @nearVision(counter, i+1, nodes)
                return lastSuccessful
            nullIterations = nullIterations + 1
            @mapLists[@editor.id][counter] = null
      else
        @mapLists[@editor.id][counter] = -1
      counter = counter + 1
    if matchedWords/size > 0.8
      # console.log "GUH"
      return lastSuccessful
    return -1

  cleanMapList: (nodes)->
    counter = 0
    while @mapLists[@editor.id][counter] == -1 || @mapLists[@editor.id][counter] == null
      counter = counter + 1
    lastNode = @mapLists[@editor.id][counter]
    firstLastNode = lastNode
    size = @mapLists[@editor.id].length
    @findHoles(nodes)
    lastSuccessfulCounter = 0
    # while counter < size
    #   if @mapLists[@editor.id][counter] and @mapLists[@editor.id][counter] != -1
    #     if @mapLists[@editor.id][counter] != nodes[lastNode]
    #       if not @holes[lastSuccessfulCounter] and @mapLists[@editor.id][counter] != nodes[lastNode + 1]
    #         @mapLists[@editor.id][counter] = -1
    #       else
    #         lastNode = @mapLists[@editor.id][counter]
    #     lastSuccessfulCounter = counter
    #   counter = counter + 1
    @stitchHoles(nodes)
    # counter = 0
    # lastNode = firstLastNode
    # while counter < size
    #   if @mapLists[@editor.id][size - counter - 1] != null
    #     if @mapLists[@editor.id][size - counter - 1] == -1
    #       @mapLists[@editor.id][size - 1 -counter] = lastNode
    #     else
    #       lastNode = @mapLists[@editor.id][size - 1 - counter]
    #   counter = counter + 1
    # @interpolate(nodes)

  sync: ->
    if not @synced
      if @paneList[@editor.id] == null
        return
      nodes = []
      nodeOrder = []
      @mapLists[@editor.id] = []
      @offsets[@editor.id] = []
      nodes = (div for div in @paneList[@editor.id].childNodes)[0...]
      countNodes = 0
      nodes = @cleanNodes(nodes)
      while countNodes < nodes.length
        element = {}
        element.id = countNodes
        element.node = nodes[countNodes]
        nodeOrder.push(element)
        countNodes = countNodes + 1
      nodes = nodeOrder
      countLines = 0
      buf = 0
      i = 0
      lineSize = @editor.getLastBufferRow() + 1
      while buf < lineSize
        check = @placeInNodes(nodes, buf, @editor.getLastBufferRow() + 1, i)
        if check
          i = check["node"]
          buf = check["line"]
          i = i + 1
        buf = buf + 1
      @cleanMapList(nodes)
      @interpolate(nodes)
      @synced = true

  findHoles:(nodes) ->
    @holes = []
    size = @editor.getLastBufferRow() + 1
    counter = 0
    lastNumber = 0
    nodeSize = nodes.length
    lastSuccessfulCounter = 0
    while counter < size
      if @mapLists[@editor.id][counter] and @mapLists[@editor.id][counter] != -1
        lastNumber = @mapLists[@editor.id][counter].id
        break
      counter = counter + 1
    lastSuccessfulCounter = counter
    while counter < size
      if @mapLists[@editor.id][counter] and @mapLists[@editor.id][counter] != -1
        if @mapLists[@editor.id][counter].id > lastNumber
          if @mapLists[@editor.id][counter] == nodes[lastNumber + 1]
            lastNumber = lastNumber + 1
          else
            temp = lastNumber
            lastNumber = @mapLists[@editor.id][counter].id
            @holes[lastSuccessfulCounter] = {'begin':temp + 1; 'end':lastNumber - 1; 'endRow':counter}
        else
          if @mapLists[@editor.id][counter].id != lastNumber
            @mapLists[@editor.id][counter] = -1
            # @mapLists[@editor.id][counter] = @mapLists[@editor.id][lastSuccessfulCounter]
        lastSuccessfulCounter = counter
      counter = counter + 1

  stitchHoles:(nodes) ->
    size = @editor.getLastBufferRow() + 1
    counter = 0
    while counter < size
      if @holes[counter]
        obj = @holes[counter]
        height = 0
        startNode = obj['begin']
        endNode = obj['end']
        nodeCounter = startNode
        while nodeCounter <= endNode
          height = height + nodes[nodeCounter].node.getBoundingClientRect().height
          nodeCounter = nodeCounter + 1
        ratio = height/nodes[startNode].node.getBoundingClientRect().height
        counter2 = counter + 1
        size = obj['endRow']
        countLines = 0
        delta = size - counter - 1
        while counter2 < size
          @offsets[@editor.id][counter2] = countLines * ratio / delta
          @mapLists[@editor.id][counter2] = nodes[startNode]
          counter2 = counter2 + 1
          countLines = countLines + 1
        counter = obj['endRow']
      else
        counter = counter + 1

  interpolate:(nodes) ->
    size = @mapLists[@editor.id].length
    counter = 1
    while counter < size
      if ((not @offsets[@editor.id][counter]?) || (@offsets[@editor.id][counter] == -1))
        counter2 = counter
        countLines = 0
        while (not @offsets[@editor.id][counter2]? || (@offsets[@editor.id][counter2] == -1))and counter2 < size
          @offsets[@editor.id][counter2] = countLines + 1
          @mapLists[@editor.id][counter2] = @mapLists[@editor.id][counter - 1]
          countLines = countLines + 1
          counter2 = counter2 + 1
        if @mapLists[@editor.id][counter2] == @mapLists[@editor.id][counter - 1]
          delta = @offsets[@editor.id][counter2] - @offsets[@editor.id][counter - 1]
        else
          delta = 1 - @offsets[@editor.id][counter - 1]
        counter2 = counter
        iterator = 0
        while iterator < countLines
          @offsets[@editor.id][counter2 + iterator] = @offsets[@editor.id][counter - 1] + @offsets[@editor.id][counter2 + iterator] * delta/ countLines
          iterator = iterator + 1
        counter = counter2 + iterator
      else
        counter = counter + 1

  cleanNodes:(nodes) ->
    size = nodes.length
    tmpNodes = []
    i = 0
    k = 0
    while i < size
      if nodes[i].innerText
        tmpNodes[k] = nodes[i]
        k = k + 1
      i = i + 1
    return tmpNodes

  ultraSync: () ->
    if @editor and @paneView == @paneList[@editor.id]
      rn = @editor.getFirstVisibleScreenRow()
      top = @mapLists[@editor.id][rn]
      offf = @offsets[@editor.id][rn]
      if top != null and top != -1 and top?
        offs = top.node.getBoundingClientRect().height
        top.node.scrollIntoView()
        offs = offs*offf + @paneList[@editor.id].scrollTop
        @paneList[@editor.id].scrollTop = offs
