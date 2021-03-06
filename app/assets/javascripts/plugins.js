window.Plugins = {
  /****************************************************************************
   Private variables to keep track of our plugins.
    @var Plugins._pluginClasses: {[label:string]: ()=> PluginClass}
      Note, we call these `classes` but any constructor function will do.
    @var Plugins._plugins: [PluginClass]
    @var Plugins._pluginLabels: [string]
    @var Plugins._pluginStatePaths: {[string]:{savePath: string, loadPath: string}
  ****************************************************************************/
  _pluginClasses: {},
  _plugins:[],
  _pluginLabels:[],
  _pluginStatePaths: {},

  _pluginError: function(e, other) {
    console.group('LARA Plugin Error');
    console.error(e);
    console.dir(other);
    console.groupEnd();
  },

  /****************************************************************************
  @function initPlugin
  This method is called to initialize the external scripts
  Called at runtime by LARA to create an instance of the plugin
  as would happen in `views/plugin/_show.html.haml`
  @arg {string} label - the the script identifier.
  @arg {IRuntimContext} runtimeContext - context for the plugin
  @arg {IPluginStatePath} pluginStatePaths – for saving & loading learner data

  Interface IPluginStatePath {
    savePath: string;
    loadPath: string;
  }

  Interface IRuntimeContext {
    name: string;               // Name of the plugin
    url: string;                // Url from which the plugin was loaded
    pluginId: string;           // Active record ID of the plugin scope id
    authorData: string;         // The authored configuration for this instance
    learnerData: string;        // The saved learner data for this instance
    div: HTMLElement;           // reserved HTMLElement for the plugin output
  }
  ****************************************************************************/
  initPlugin: function(label, runtimeContext, pluginStatePaths) {
    var constructor = this._pluginClasses[label];
    var plugin = null;
    if (typeof constructor === 'function') {
      try {
        plugin = new constructor(runtimeContext);
        this._plugins.push(plugin);
        this._pluginLabels.push(label);
        this._pluginStatePaths[runtimeContext.pluginId] = pluginStatePaths;
      }
      catch(e) { this._pluginError(e, runtimeContext); }
      console.info('Plugin', label, 'is now registered');
    }
    else {
      console.error('No plugin registered for label:', label);
    }
  },

  /****************************************************************************
   @function saveLearnerPluginState: Ask LARA to save the users state for the plugin
   @arg {string} pluginId - ID of the plugin trying to save data, initially passed to plugin constructor in the context
   @arg {string} state - A JSON string representing serialized plugin state.
   @example
    LARA.saveLearnerPluginState(pluginId, '{"one": 1}').then((data) => console.log(data))
   @returns Promise resolve: <string>
  ****************************************************************************/
  saveLearnerPluginState: function(pluginId, state) {
    var paths = this._pluginStatePaths[pluginId];
    if(paths && paths.savePath) {
      return new Promise(function(resolve, reject) {
        $.ajax({
          url: paths.savePath,
          type: 'PUT',
          data: {state: state},
          success: function(data) { resolve(data); },
          error: function(jqXHR, errText, err) { reject(err); }
        });
      });
    }
    const msg = 'Not saved.`pluginStatePaths` missing for plugin ID:'
    console.warn(msg , pluginId);
    return Promise.reject(msg)
  },

  /****************************************************************************
   @function registerPlugin
   Register a new external script as `label` with `_class `
   @arg {string} label - the identifier of the script
   @arg {class} _class - the Plugin Class being associated with the identifier
   @example: `Plugins.register('debugger', Dubugger)`
   @returns {boolean} – true if plugin was registered correctly.
   ***************************************************************************/
  registerPlugin: function(label, _class) {
    if (typeof _class !== 'function') {
      console.error('Plugin did not provide constructor', label);
      return false;
    }
    if(this._pluginClasses[label]) {
      console.error('Duplicate Plugin for label', label);
      return false
    } else {
      this._pluginClasses[label] = _class;
      return true
    }
  }

};
