###
Copyright 2014 Versul Tecnologias Ltda

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
###

require "coffee-script/register"
require("better-require")()

path = require 'path'
http = require 'http'
Exceptions = require './Util/Exceptions'
Sync = require './Util/Sync'
Logger = require './Component/Builtin/Logger'
RequestHandler = require './Controller/RequestHandler'
os = require 'os'

WaferPie = ->
    @_version = "0.8.0"
    @_applications = {}
    @_configured = false
    @_configs =
        console: false
        urlFormat: "/$controller"

    Sync.createDirIfNotExists "logs"
    return
WaferPie::info = (message) ->
    @_logger.info "[WaferPie] " + message
    return


###
Initiate an application inside the framework
Create the directory structure if it does not exist
It loads all application files on memory
It is possible to have more then one application running on the same NodeJS server
It is possible to have one core.json by each host that will run the server

@method setUp
@param {string} appName The name of application, it will be also used as directory's name
###
WaferPie::setUp = (appName) ->
    app = undefined
    srcPath = undefined
    testPath = undefined
    srcPath = path.resolve(path.join(appName, "src"))
    testPath = path.resolve(path.join(appName, "test"))
    app =
        constants:
            basePath: path.resolve(path.join(appName))
            srcPath: srcPath
            logsPath: path.resolve(path.join(appName, "logs"))
            controllersPath: path.resolve(path.join(srcPath, "Controller"))
            componentsPath: path.resolve(path.join(srcPath, "Component"))
            configPath: path.resolve(path.join(srcPath, "Config"))
            modelsPath: path.resolve(path.join(srcPath, "Model"))
            filtersPath: path.resolve(path.join(srcPath, "Filter"))
            testPath: testPath
            controllersTestPath: path.resolve(path.join(testPath, "Controller"))
            componentsTestPath: path.resolve(path.join(testPath, "Component"))
            modelsTestPath: path.resolve(path.join(testPath, "Model"))
            filtersTestPath: path.resolve(path.join(testPath, "Filter"))

        hostname: os.hostname()

    (shouldPointCoreFileBasedOnHost = ->
        if Sync.isFile(path.join(app.constants.srcPath, "Config", app.hostname, ".json"))
            app.coreFileName = path.join(app.constants.srcPath, "Config", app.hostname, ".json")
        else
            app.coreFileName = path.join(app.constants.srcPath, "Config", "core.json")
        return
    )()
    Sync.createDirIfNotExists app.constants.basePath
    Sync.createDirIfNotExists app.constants.srcPath
    Sync.createDirIfNotExists app.constants.controllersPath
    Sync.createDirIfNotExists app.constants.componentsPath
    Sync.createDirIfNotExists app.constants.filtersPath
    Sync.createDirIfNotExists app.constants.modelsPath
    Sync.createDirIfNotExists app.constants.configPath
    Sync.createDirIfNotExists app.constants.testPath
    Sync.createDirIfNotExists app.constants.controllersTestPath
    Sync.createDirIfNotExists app.constants.modelsTestPath
    Sync.createDirIfNotExists app.constants.componentsTestPath
    Sync.createDirIfNotExists app.constants.filtersTestPath
    Sync.createDirIfNotExists app.constants.logsPath
    Sync.copyIfNotExists path.join(__dirname, "Copy", "core.json"), app.coreFileName
    Sync.copyIfNotExists path.join(__dirname, "Controller", "Exceptions.js"), path.join("Exceptions.js")
    app.controllers = @_loadElements(app.constants.controllersPath)
    app.filters = @_loadElements(app.constants.filtersPath)
    app.components = @_loadComponents(app.constants.componentsPath)
    app.models = @_loadElements(app.constants.modelsPath)
    try
        app.core = Sync.fileToJSON(app.coreFileName)
    catch e
        throw new Exceptions.Fatal("The core configuration file is not a valid JSON", e)
    @_loadAllConfigJSONFiles app, app.constants.configPath
    @_validateCoreFile app.core
    @_applications[appName] = app
    @ExceptionsController = require("./Controller/Exceptions.js")
    @_validateControllers app.controllers
    @_validateControllers app.filters
    @_validateComponents app.components
    @_validateModels app.models
    return

WaferPie::_validateModels = (models) ->
    Model = undefined
    name = undefined
    for name of models
        if models.hasOwnProperty(name)
            Model = models[name]
            throw new Exceptions.Fatal("Model does not export a function: " + name)  unless Model instanceof Function
    return

WaferPie::_validateComponents = (components) ->
    name = undefined
    Component = undefined
    for name of components
        if components.hasOwnProperty(name)
            Component = components[name]
            throw new Exceptions.Fatal("Component does not export a function: " + name)  unless Component instanceof Function
    return

WaferPie::_validateControllers = (controllers) ->
    methods = undefined
    name = undefined
    Controller = undefined
    instance = undefined
    methodsLength = undefined
    methodName = undefined
    j = undefined
    methods = [
        "before"
        "after"
        "put"
        "delete"
        "get"
        "post"
        "options"
        "head"
        "path"
    ]
    for name of controllers
        if controllers.hasOwnProperty(name)
            Controller = controllers[name]
            throw new Exceptions.Fatal("Controller does not export a function: " + name)  unless Controller instanceof Function
            instance = new Controller()
            methodsLength = methods.length
            j = 0
            while j < methodsLength
                methodName = methods[j]
                throw new Exceptions.Fatal(name + "." + methodName + "() must be a function!")  unless instance[methodName] instanceof Function  if instance[methodName] isnt `undefined`
                j += 1
    return

WaferPie::_loadAllConfigJSONFiles = (app, configPath) ->
    files = undefined
    elementNames = []
    files = Sync.listFilesFromDir(configPath)
    files.forEach (file) ->
        relative = undefined
        extensionIndex = undefined
        relativeWithoutExt = undefined
        elementName = undefined
        if file.indexOf(".json") isnt -1
            relative = file.substring(configPath.length + 1)
            extensionIndex = relative.lastIndexOf(".")
            relativeWithoutExt = relative.substring(0, extensionIndex)
            elementName = relativeWithoutExt.replace(/\//g, ".")
            elementNames[elementName] = file
        return

        app.configs = Sync.loadNodeFilesIntoArray(elementNames)
    return


###
Load builtin and application components
@param {string} componentsPath Path to the application components
@returns {object} Components
@private
###
WaferPie::_loadComponents = (componentsPath) ->
    components = @_loadElements(path.join(__dirname, "Component", "Builtin"))
    appComponents = @_loadElements(componentsPath)
    componentName = undefined
    for componentName of appComponents
        components[componentName] = appComponents[componentName]  if appComponents.hasOwnProperty(componentName)
    components

WaferPie::_loadElements = (dirPath) ->
    elementNames = []
    files = Sync.listFilesFromDir(dirPath)
    files.forEach (file) ->
        relative = file.substring(dirPath.length + 1)
        extensionIndex = relative.lastIndexOf(".")
        relativeWithoutExt = relative.substring(0, extensionIndex)
        elementName = relativeWithoutExt.replace(/\//g, ".")
        elementNames[elementName] = file
        return

    Sync.loadNodeFilesIntoArray elementNames

WaferPie::_validateCoreFile = (core) ->
    throw new Exceptions.Fatal("The requestTimeout configuration is not defined")  if core.requestTimeout is `undefined`
    throw new Exceptions.Fatal("The requestTimeout configuration is not a number")  if typeof core.requestTimeout isnt "number"

###
It parses the configuration file, a json object, that controls the framework behavior, such url parameters,
data sources, etc...

@method configure
@param {string} configFile The file name that contains your configuration object
###
WaferPie::configure = (configFile) ->
    if configFile
        try
            @_configs = require(path.resolve("./" + configFile))
        catch e
            throw new Exceptions.Fatal("Configuration file is not a valid configuration file", e)
        throw new Exceptions.Fatal("urlFormat has not been specified or it is not a string")  if typeof @_configs.urlFormat isnt "string"
    @_logger = new Logger("server.log")
    @_logger.config
        path: "logs"
        console: @_configs.debug

    @_logger.init()
    @_configured = true
    return


###*
Starts the NodeJS server for all your applications

@method start
@param {string} address The listening address of NodeJS http.createServer function
@param {number} port The listening port of NodeJS http.createServer function
###
WaferPie::start = (address, port) ->
    throw new Exceptions.Fatal("Please call configure() before start()!")  unless @_configured
    $this = this
    @info "Starting..."
    http.createServer((request, response) ->
        requestHandler = new RequestHandler($this._logger, $this._configs, $this._applications, $this.ExceptionsController, $this._version)
        requestHandler.process request, response
        return
    ).listen port, address
    @info address + ":" + port
    @info "Started!"
    return

WaferPie.Testing = require("./Test/Testing")
module.exports = WaferPie