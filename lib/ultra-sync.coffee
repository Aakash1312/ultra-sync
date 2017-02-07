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
  finalOccurence : null
  activate: (state) ->
    @ultraSyncView = new UltraSyncView(state.ultraSyncViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @ultraSyncView.getElement(), visible: false)
    # @editor = atom.workspace.get
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    # Register command that toggles this view
    @mapList = []
    @offset = []
    @finalOccurence = []
    @subscriptions.add atom.commands.add 'atom-workspace', 'ultra-sync:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @ultraSyncView.destroy()

  serialize: ->
    ultraSyncViewState: @ultraSyncView.serialize()

  toggle: ->
    panes = atom.workspace.getPaneItems()
    pane = panes[panes.length - 1]
    @editor = atom.workspace.getActiveTextEditor()
    @paneView = atom.views.getView(pane)
    @editorView = atom.views.getView(@editor)
    @subscriptions.add @editor.onDidChangeScrollTop => @ultraSync()
    # @sync()
    @sync2()
    #
    # if @modalPanel.isVisible()
    #   @modalPanel.hide()
    # else
    #   @modalPanel.show()

  sync: ->
    html = @paneView.querySelector('.scroll-view')
    nodes = (div for div in html)[0...]
    nodes = @cleanNodes(nodes)
    bufLines = new Array(@editor.getLastBufferRow() + 1)
    i = 0
    j = 0
    countLines = 0
    actualCount = 0
    prei = -2
    prebuf =0
    for buf in [0..@editor.getLastBufferRow()]
      line = @editor.lineTextForBufferRow buf
      matches = line?.match /[A-Za-z0-9]+/ig
      if matches
        i = @isInNodes(nodes, matches, j, i)
        if i != prei
          # height = nodes[prei].getBoundingClientRect().height
          # perLineHeight = height/countLines
          # index = buf - countLines
          # counter = 0
          # @mapList[index] = nodes[prei].getBoundingClientRect().top + @element.scrollTop
          # index = index + 1
          # while index < buf
          #   @mapList[index] = @mapList[index-1] + perLineHeight
          #   index = index + 1
          # countLines = 0
          if i != -1
            prei = i
            j = matches.length
            @mapList[buf] = nodes[i]
            @offset[buf] = 0
            counter = prebuf
            while counter < buf
              @offset[counter] = @offset[counter]/countLines
              counter = counter + 1
            prebuf = buf
            countLines = 0
            actualCount = 0
          else
            i = prei
            j = 0
            # countLines = 0
            @mapList[buf] = null
        else
          countLines = countLines + 1
          actualCount = actualCount + 1
          @offset[buf] = countLines
          @mapList[buf] = nodes[i]
          j = j + matches.length
      else
        countLines = countLines + 1
        actualCount = actualCount + 1
        @offset[buf] = countLines
        @mapList[buf] = nodes[i]

  matchWords: (A, B, j) ->
    if A? and B?
      size1 = A.length
      size2 = B.length
      if j >= size2
        return 0
      else
        while j < size2
          if A[0] == B[j]
            if B[j+size1-1] == A[size1 - 1]
              return j + size1
          j = j + 1
    return -1

  matchWords2: (A, B, j) ->
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

  isInNodes: (nodes, A, j, i) ->
    lim = 0
    if nodes[i]
      while lim < 4 and i < nodes.length
        text = nodes[i].innerText
        if text
          lim = lim + 1
          matches = text.match /[A-Za-z0-9]+/ig
          if @matchWords(A, matches, j) >= 1
            return i
          else
            i = i + 1
        else
          i = i + 1
        j = 0
    return -1

  isInNodes2: (nodes, buf, length, i) ->
    size = nodes.length
    counter = i
    while counter < size
      k = @checkIfNodeExists(nodes, length, counter, buf)
      if k != -1
        return {"line":k; "node":counter}
      counter = counter + 1
    return null

  connect: (start, end, nodes, i) ->
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
      k = @matchWords2(matches, matchesNode, 0)
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
          l = @matchWords2(localMatches, matchesNode, j)
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
          # @connect(buf, lastSuccessful, nodes, i)
        return -1
      line = @editor.lineTextForBufferRow counter
      line = line?.replace(/(\<[^>]*\>)*/ig, '')
      matches = line?.match /[A-Za-z0-9]+/ig
      if matches
        k = @matchWords2(matches, matches2, j)
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
      # @connect(buf, lastSuccessful, nodes, i)
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
          @connect(counter2, counter - 1, null, 0)
          counter2 = counter
      counter = counter + 1

  sync2: ->
    nodes = []
    nodes = (div for div in $(@paneView.childNodes))[0...]
    nodes = @cleanNodes(nodes)
    countLines = 0
    buf = 0
    i = 0
    lineSize = @editor.getLastBufferRow() + 1
    while buf < lineSize
      check = @isInNodes2(nodes, buf, @editor.getLastBufferRow() + 1, i)
      if check
        i = check["node"]
        # start = buf
        # end = check["line"]
        # countLines = 0
        # while start <= end
        #   if @mapList[start] != null
        #     # @mapList[start] = nodes[i]
        #     @offset[start] = countLines
        #     countLines = countLines + 1
        #   start = start + 1
        # start = buf
        # while start <= end
        #   if @mapList[start] != null
        #     @offset[start] = @offset[start]/countLines
        #   start = start + 1
        buf = check["line"]
        i = i + 1
      buf = buf + 1
    @cleanMapList()

  cleanNodes:(nodes) ->
    size = nodes.length
    tmpNodes = []
    tmpNodes2 = []
    i = 0
    k = 0
    # while i < size
    #   if not nodes[i].hasChildNodes
    #     tmpNodes2[k] = nodes[i]
    #     k = k + 1
    #   else
    #     childSize = nodes[i].childNodes.length
    #     counter = 0
    #     while counter < childSize
    #       if nodes[i].childNodes[counter].tagName == "DIV"
    #         break
    #       counter = counter + 1
    #     if counter == childSize
    #       tmpNodes2[k] = nodes[i]
    #       k = k + 1
    #   i = i + 1
    # k = 0
    # i = 0
    # size = tmpNodes2.length
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
