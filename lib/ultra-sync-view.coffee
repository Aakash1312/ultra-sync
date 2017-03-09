module.exports =
class UltraSyncView
  constructor: (serializedState) ->
    # Create syncing element

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    if @synced?
      @synced.remove()

  getSynced: ->
    @synced = document.createElement('div')
    @synced.innerHTML = "Synced &#10004;"
    @synced.classList.add('synced')
    @synced.style.visibility = "visible"
    @synced

  hide: ->
    if @synced?
      @synced.style.visibility = "hidden"

  show: ->
    if @synced?
      @synced.style.visibility = "visible"
