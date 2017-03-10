module.exports =
class UltraSyncView
  constructor: (serializedState) ->
    console.log "Do nothing"
    # Create syncing element

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    if @synced?
      console.log "Destroying status"
      @synced.remove()

  getSynced: ->
    @synced = document.createElement('div')
    @synced.innerHTML = "Synced &#10004;"
    @synced.classList.add('synced')
    @synced.style.visibility = "visible"
    console.log "Built status"
    @synced

  hide: ->
    console.log "Hiding status"
    if @synced?
      @synced.style.visibility = "hidden"

  show: ->
    console.log "Showing status"
    if @synced?
      @synced.style.visibility = "visible"
