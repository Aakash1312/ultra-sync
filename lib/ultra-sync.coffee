UltraSyncView = require './ultra-sync-view'
{CompositeDisposable} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'

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

  activate: (state) ->
    @ultraSyncView = new UltraSyncView(state.ultraSyncViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @ultraSyncView.getElement(), visible: false)
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'ultra-sync:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()
    @ultraSyncView.destroy()

  toggle: ->
    panes = atom.workspace.getPaneItems()
    pane = panes[panes.length - 1]
    @editor = atom.workspace.getActiveTextEditor()
    @paneView = atom.views.getView(pane)
    @editorView = atom.views.getView(@editor)
    @subscriptions.add @editorView.onDidChangeScrollTop => @ultraSync()
    # @paneView.addEventListener("DOMSubtreeModified", (() => @sync()), {once:true})
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
      if @mapList[start] != null
        @offset[start] = countLines
        countLines = countLines + 1
      start = start + 1
    start = buf
    while start <= end
      if @mapList[start] != null
        @offset[start] = @offset[start]/countLines
      start = start + 1

  nearVision: (buf, i, nodes) ->
    counter = i
    line = @editor.lineTextForBufferRow buf
    line = line?.replace(/(\<[^>]*\>)*/ig, '')
    matches = line?.match /[A-Za-z0-9]+/ig
    nodeSize = nodes.length
    while counter < nodeSize
      text = nodes[counter].innerText
      text = text.replace(/(\<[^>]*\>)+/ig, '')
      matchesNode = text.match /[A-Za-z0-9]+/ig
      k = @matchWords(matches, matchesNode, 0)
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
          l = @matchWords(localMatches, matchesNode, j)
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
    text = nodes[i].innerText
    text = text.replace(/(\<[^>]*\>)+/ig, '')
    matches2 = text.match /[A-Za-z0-9]+/ig
    if not matches2
      return -1
    matched = false
    size = matches2.length
    counter = buf
    j = 0
    lastSuccessful = -1
    nullIterations = 0
    while counter < length
      if nullIterations > 0.25 * size
        if j/size > 0.8
          return lastSuccessful
        return -1
      line = @editor.lineTextForBufferRow counter
      line = line?.replace(/(\<[^>]*\>)*/ig, '')
      matches = line?.match /[A-Za-z0-9]+/ig
      if matches
        k = @matchWords(matches, matches2, j)
        if k >= size
          @offset[counter] = j/size
          @mapList[counter] = nodes[i]
          return counter
        if k >= 1
          @offset[counter] = j/size
          lastSuccessful = counter
          j = k
          @mapList[counter] = nodes[i]
        else
          if not @mapList[counter]
            if j/size > 0.8
              if @nearVision(counter, i+1, nodes)
                return lastSuccessful
            nullIterations = nullIterations + 1
            @mapList[counter] = null
      else
        @mapList[counter] = -1
      counter = counter + 1
    if j/size > 0.8
      return lastSuccessful
    return -1

  cleanMapList: (nodes)->
    counter = 0
    while @mapList[counter] == -1 || @mapList[counter] == null
      counter = counter + 1
    lastNode = @mapList[counter]
    firstLastNode = lastNode
    size = @mapList.length
    @findHoles(nodes)
    lastSuccessfulCounter = 0
    # while counter < size
    #   if @mapList[counter] and @mapList[counter] != -1
    #     if @mapList[counter] != nodes[lastNode]
    #       if not @holes[lastSuccessfulCounter] and @mapList[counter] != nodes[lastNode + 1]
    #         @mapList[counter] = -1
    #       else
    #         lastNode = @mapList[counter]
    #     lastSuccessfulCounter = counter
    #   counter = counter + 1
    @stitchHoles(nodes)
    counter = 0
    # lastNode = firstLastNode
    while counter < size
      if @mapList[size - counter - 1] != null
        if @mapList[size - counter - 1] == -1
          @mapList[size - 1 -counter] = lastNode
        else
          lastNode = @mapList[size - 1 - counter]
      counter = counter + 1
    @interpolate(nodes)

  sync: ->
    nodes = []
    @mapList = []
    @offset = []
    nodes = (div for div in @paneView.childNodes)[0...]
    nodes = @cleanNodes(nodes)
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

  findHoles:(nodes) ->
    @holes = []
    size = @editor.getLastBufferRow() + 1
    counter = 0
    lastNumber = 0
    nodeSize = nodes.length
    lastSuccessfulCounter = 0
    while counter < size
      if @mapList[counter]
        lastNumber = counter
        break
      counter = counter + 1
    lastSuccessfulCounter = counter
    while counter < size
      if @mapList[counter] and @mapList[counter] != -1
        if @mapList[counter] != nodes[lastNumber]
          if @mapList[counter] == nodes[lastNumber + 1]
            lastNumber = lastNumber + 1
          else
            temp = lastNumber
            while @mapList[counter] != nodes[lastNumber] and lastNumber < nodeSize
              lastNumber = lastNumber + 1
            if lastNumber != nodeSize
              @holes[lastSuccessfulCounter] = {'begin':temp + 1; 'end':lastNumber - 1; 'endRow':counter}
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
        while nodeCounter < endNode
          height = height + nodes[nodeCounter].getBoundingClientRect().height
          nodeCounter = nodeCounter + 1
        ratio = height/nodes[startNode].getBoundingClientRect().height
        counter2 = counter + 1
        size = obj['endRow']
        countLines = 0
        delta = size - counter - 1
        while counter2 < size
          @offset[counter2] = countLines * ratio / delta
          @mapList[counter2] = nodes[startNode]
          counter2 = counter2 + 1
          countLines = countLines + 1
        counter = obj['endRow']
      else
        counter = counter + 1

  interpolate:(nodes) ->
    size = @mapList.length
    counter = 1
    while counter < size
      if not @offset[counter]?
        counter2 = counter
        countLines = 0
        while not @offset[counter2]? and counter2 < size
          @offset[counter2] = countLines + 1
          @mapList[counter2] = @mapList[counter - 1]
          countLines = countLines + 1
          counter2 = counter2 + 1
        if @mapList[counter2] == @mapList[counter - 1]
          delta = @offset[counter2] - @offset[counter - 1]
        else
          delta = 1 - @offset[counter - 1]
        counter2 = counter
        iterator = 0
        while iterator < countLines
          @offset[counter2 + iterator] = @offset[counter - 1] + @offset[counter2 + iterator] * delta/ countLines
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
    tmpNodes

  ultraSync: () ->
    @editor = atom.workspace.getActiveTextEditor()
    rn = @editor.getFirstVisibleScreenRow()
    top = @mapList[rn]
    offf = @offset[rn]
    if top != null and top != -1
      offs = top.getBoundingClientRect().height
      top.scrollIntoView()
      offs = offs*offf + @paneView.scrollTop
      @paneView.scrollTop = offs
