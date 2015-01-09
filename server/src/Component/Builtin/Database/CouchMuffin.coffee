_ = require 'underscore'
uuid = require 'node-uuid'

class CouchMuffin
    constructor: (options) ->
        @_dataSourceName = options?.dataSourceName ? 'default'
        @_type = options?.type
        @_validate = options?.validate
        @_keyPrefix = '' || options?.keyPrefix
        @_autoId = '' || options?.autoId
        @_counterKey = "#{@_keyPrefix}counter"

    init: ->
        @_dataSource = @component 'DataSource.Couchbase', @_dataSourceName
        @_validator = @component 'Validator', validate: @_validate
        @_cherries = @component 'Cherries'
        @$ = @component 'QueryBuilder', true

    _query: (query, callback) ->
        @_dataSource.bucket.query (@_dataSource.n1ql.fromString query), (error, result) ->
            callback error if error
            callback null, result

    _createCounter: (callback) ->
        @insert @_counterKey, 1, (error) ->
            return callback error if error
            return callback null, 1

    _uuid: ->
        uuid.v4()

    _counter: (callback) ->
        @_dataSource.bucket.counter @_counterKey, 1, (error, result) ->
            _createCounter callback if error and error.code == 13
            return callback error if error
            return callback null, result.value

    # Bind all methods from MyNinja into the model instance (expect for init() and bind() itself)
    bind: (model) ->
        methodsToBind = ['findById', 'findManyById', 'removeById', 'save', 'insert', 'find', 'findAll']
        for methodName in methodsToBind
            muffinMethod = @[methodName]
            ((muffinMethod) =>
                model[methodName] = =>
                    return muffinMethod.apply(@, arguments)
            )(muffinMethod)

    # Finds a single record using the primary key (Facade to findManyById)
    # @param {string} id The record id
    # @param {function} callback Called when the operation is completed (error, result)
    findById: (id, callback) ->
        @findManyById [id], callback

    # Finds many records using the primary key
    # @param {array|string} ids The records id within an array of Strings
    # @param {function} callback Called when the operation is completed (error, result)
    findManyById: (ids, callback) ->
        idsWithPrefix = []
        idsWithPrefix = ("#{@_keyPrefix}#{value}" for value in ids)
        @_dataSource.bucket.getMulti idsWithPrefix, (error, result) ->
            return callback error if error and !_.isNumber error
            return callback null, result

    # Remove a single record using the primary key
    # @param {array|string} ids The records id within an array of Strings
    # @param {function} callback Called when the operation is completed (error, result)
    removeById: (params, callback) ->
        id = params.id || null
        options = params.options || {}

        idWithPrefix = "#{@_keyPrefix}#{id}"
        @_dataSource.bucket.remove idWithPrefix, options, (error, result) ->
            return callback error if error
            return callback null, result

    # Inserts a single record using the primary key, it updates if the key already exists
    # @param {string} [params]
    #  @param {string} id The record id
    #  @param {Object} data The document itself
    #  @param {Object} [options]
    #   @param {number} [options.expiry=0]
    #   Set the initial expiration time for the document.  A value of 0 represents
    #   never expiring.
    #   @param {number} [options.persist_to=0]
    #   Ensures this operation is persisted to this many nodes
    #   @param {number} [options.replicate_to=0]
    #   Ensures this operation is replicated to this many nodes
    # @param {function} callback Called after the operation (error, result)
    # @param {function} callback Called when the operation is completed (error, result)
    save: (params, callback) ->
        return callback error: 'InvalidId' if id is null
        id = params.id || null
        data = params.data || {}
        options = params.options || {}
        validate = options.validate ? true
        match = options.match ? true

        afterValidate = (error = null) =>
            return callback(error) if error

            if match and @_validate?
                matched = @_validator.match data
                return callback name: 'MatchFailed', fields: matched unless matched is true

            @_dataSource.bucket.upsert id, data, options, (error, result) ->
                return callback error if error
                return callback null, result

        if validate and @_validate?
            @_validator.validate data, afterValidate
        else
            afterValidate()

    # Inserts a single record using the primary key, it fails if the key already exists
    # @param {string} id The record id
    # @param {Object} data The document itself
    # @param {Object} [options]
    #  @param {number} [options.expiry=0]
    #  Set the initial expiration time for the document.  A value of 0 represents
    #  never expiring.
    #  @param {number} [options.persist_to=0]
    #  Ensures this operation is persisted to this many nodes
    #  @param {number} [options.replicate_to=0]
    #  Ensures this operation is replicated to this many nodes
    # @param {function} callback Called after the operation (error, result)
    # @param {function} callback Called when the operation is completed (error, result)
    insert: (params, callback) ->
        id = params.id || null
        data = params.data || {}
        options = params.options || {}
        validate = options.validate ? true
        match = options.match ? true

        afterId = (error, newId) =>
            return callback error if error

            afterValidate = (error = null) =>
                return callback error if error

                if match and @_validate?
                    matched = @_validator.match data
                    return callback name: 'MatchFailed', fields: matched unless matched is true

                @_dataSource.bucket.insert newId, data, options, (error, result) ->
                    return callback error if error
                    return callback null, result

            if validate and @_validate?
                @_validator.validate data, afterValidate
            else
                afterValidate()

        if id is null
            afterId null, @_uuid() if @_autoId is 'uuid'
            @_counter afterId if @_autoId is 'counter'
            return callback error: 'InvalidId' if @_autoId isnt 'uuid' and @_autoId isnt 'counter'
        else
            afterId null, id

    # Finds a single record using the specified conditions (Facade to findAll)
    find: (params, callback) ->
        params.limit = 1
        @findAll params, callback

    # Finds several records using the specified conditions
    findAll: (params, callback) ->
        conditions = params.conditions ? null
        builder = @$.selectStarFrom(@_dataSource.bucketName)
        builder.where(conditions) if conditions
        builder.groupBy(params.groupBy) if params.groupBy?
        builder.having(params.having) if params.having?
        builder.limit(params.limit) if params.limit?
        sql = builder.build()

        @_query sql, callback

#    # Issues a query to the database (just a wrapper)
#    # @param
#    query: (query, params, callback) ->
#        @_query query, callback
#
#    # Updates all records of the table with the given values and using the given conditions
#    updateAll: (params) ->
#        conditions = params.conditions
#        callback = params.callback
#        data = @_cherries.copy(params.data)
#        escape = params.escape ? true
#
#        if escape
#            for prop of data
#                data[prop] = @$.value(data[prop])
#
#        sql = @$.update(@_table).set(data).where(conditions).build()
#        @_mysql.query sql, [], callback

module.exports = CouchMuffin