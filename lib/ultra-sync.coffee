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
    @paneView.addEventListener("DOMSubtreeModified", (() => @sync()), {once:true})
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
        # if matched
          # @calculateOffset(buf, lastSuccessful, nodes, i)
        return -1
      line = @editor.lineTextForBufferRow counter
      line = line?.replace(/(\<[^>]*\>)*/ig, '')
      matches = line?.match /[A-Za-z0-9]+/ig
      if matches
        k = @matchWords(matches, matches2, j)
        if k >= size
          @mapList[counter] = nodes[i]
          return counter
        if k >= 1
          lastSuccessful = counter
          j = k
          @mapList[counter] = nodes[i]
          if not matched
            matched = true
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
    # if matched
      # @calculateOffset(buf, lastSuccessful, nodes, i)
    return -1

  cleanMapList: ()->
    counter = 0
    while @mapList[counter] == -1
      counter = counter + 1
    lastNode = @mapList[counter]
    firstLastNode = lastNode
    size = @mapList.length
    while counter < size
      if @mapList[counter] != lastNode and @mapList[counter] != -1 and @mapList[counter] != null
        lastNode = @mapList[counter]
        @mapList[counter] = -1
      counter = counter + 1
    counter = 0
    lastNode = firstLastNode
    while counter < size
      if @mapList[counter] == -1
        @mapList[counter] = lastNode
      else
        lastNode = @mapList[counter]
      counter = counter + 1
    counter = 0
    counter2 = 0
    while counter < size
      if @mapList[counter]
        if @mapList[counter] != lastNode and @mapList[counter] != null
          lastNode = @mapList[counter]
          @calculateOffset(counter2, counter - 1, null, 0)
          counter2 = counter
      counter = counter + 1

  sync: ->
    nodes = []
    @mapList = []
    @offset = []
    nodes = (div for div in $(@paneView.childNodes))[0...]
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
    @cleanMapList()

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
    if top? and top != -1
      offs = top.getBoundingClientRect().height
      top.scrollIntoView()
      offs = offs*offf + @paneView.scrollTop
      @paneView.scrollTop = offs
