class ElementManager

    # Responsible for creating components and models
    # @param logger
    # @param application The application object
    # @constructor
    constructor: (logger, application) ->
        @_application = application
        @_logger = logger
        @_models = []
        @_dynamicComponents = []
        @_staticComponents = {}
        @log 'ElementManager created'

    log: (msg) -> @_logger?.log?('[ElementManager] ' + msg)

    # Return all components instantiated by this factory (both dynamic and static)
    # @returns {{}|*}
    getComponents: ->
        instances = []
        @_dynamicComponents.forEach (instance) -> instances.push instance
        for componentName of @_staticComponents
            instances.push @_staticComponents[componentName] if @_staticComponents.hasOwnProperty(componentName)
        instances

    # Instantiate a component (builtin or application)
    # @param {string} type Element type: 'component' or 'model'
    # @param {string} componentName The name of the component to be instantiated. If there are folder, they must be separated by dot.
    # @param {object=} params Parameters passed to the component constructor
    # @returns {object} The component instantiated or null if it does not exist
    create: (type, elementName, params) ->
        @log '[' + elementName + '] Creating ' + type
        $this = this
        ElementConstructor = null
        if type is 'model' and @_application.models[elementName] isnt undefined
            ElementConstructor = @_application.models[elementName]
        else if type is 'component' and @_application.components[elementName] isnt undefined
            ElementConstructor = @_application.components[elementName]
        else
            @log '[' + elementName + '] Component not found'
            return null

        elementInstance = new ElementConstructor(params)
        if type is 'component'
            if elementInstance.singleInstance is true
                alreadyInstantiated = @_staticComponents[elementName] isnt undefined
                if alreadyInstantiated
                    @log '[' + elementName + '] Recycling component'
                    return @_staticComponents[elementName]

        elementInstance.name = elementName
        elementInstance.constants = @_application.constants
        elementInstance.model = (modelName, params) ->
            instance = $this.create('model', modelName, params)
            $this.init instance
            instance

        elementInstance.component = (componentName, params) ->
            instance = $this.create('component', componentName, params)
            $this.init instance
            instance

        elementInstance.core = @_application.core
        elementInstance.configs = @_application.configs
        @log '[' + elementName + '] Element created'

        if type is 'component'
            if elementInstance.singleInstance
                @_staticComponents[elementName] = elementInstance
            else
                @_dynamicComponents.push elementInstance
        else
            @_models.push elementInstance
        elementInstance

    # Calls the component init() method if defined
    # @param {object} componentInstance The component instance
    init: (elementInstance) ->
        if elementInstance isnt null
            @log '[' + elementInstance.name + '] Element initialized'
            elementInstance.init?()
        elementInstance

module.exports = ElementManager