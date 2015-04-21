# This class implements two main functionalities:

# 1. Checks if global interactive state is availble on page load and if so,
#    it posts 'interactiveLoadGlobal' to all interactives (iframes).
# 2. When 'interactiveStateGlobal' message is received from any iframe, it:
#   2.1. sends the state to LARA server
#   2.2. posts 'interactiveLoadGlobal' message with a new state to all interactives
#        (except from sender of save message).

class GlobalIframeSaver

  constructor: (config) ->
    @_saveUrl = config.save_url
    @_globalState = if config.raw_data then JSON.parse(config.raw_data) else null
    @_save_indicator = SaveIndicator.instance()

    @_iframePhones = []

  addNewInteractive: (iframeEl) ->
    phone = IframePhoneManager.getPhone iframeEl
    @_iframePhones.push phone
    @_setupPhoneListeners phone
    if @_globalState
      @_loadGlobalState phone

  _setupPhoneListeners: (phone) ->
    phone.addListener 'interactiveStateGlobal', (state) =>
      @_globalState = state
      @_saveGlobalState()
      @_broadcastGlobalState phone

  _loadGlobalState: (phone) ->
    phone.post 'loadInteractiveGlobal', @_globalState

  _broadcastGlobalState: (sender) ->
    @_iframePhones.forEach (phone) =>
      # Do not send state again to the same iframe that posted global state.
      @_loadGlobalState phone if phone != sender

  _saveGlobalState: ->
    @save_indicator.showSaving()
    $.ajax
      type: 'POST'
      url: @_saveUrl
      data:
        raw_data: JSON.stringify(@_globalState)
      success: (response) =>
        console.log 'Global interactive save success.'
        @_save_indicator.showSaved()
      error: (jqxhr, status, error) =>
        console.error 'Global interactive save failed!'
        if jqxhr.status is 401
          @_save_indicator.showUnauthorized()
          $(document).trigger 'unauthorized'
        else
          @_save_indicator.showSaveFailed()

$(document).ready ->
  if gon.globalInteractiveState?
    window.globalIframeSaver = new GlobalIframeSaver gon.globalInteractiveState