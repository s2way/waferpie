/*jslint devel: true, node: true, indent: 4 */
/*globals describe, it */
var assert = require('assert');
var ModelInterface = require('./../../src/Model/ModelInterface');

describe('ModelInterface.js', function () {

    var configurations = {
        'uid' : 'pessoa'
    };
    var dataSource = {
        'bucket' : 'bucket',
        'type' : 'Mock'
    };

    describe('ModelInterface', function () {

        it('shoud instantiate the DataSource object', function () {
            var model = new ModelInterface(dataSource, configurations);
            assert.equal(true, model.model !== null);
        });

        it('should throw an IllegalArgument exception if the DataSource cannot be found', function () {
            try {
                var mi = new ModelInterface('Invalid', configurations);
                assert.equal(true, mi !== undefined);
                assert.fail();
            } catch (e) {
                assert.equal('IllegalArgument', e.name);
            }
        });
    });

    describe('findByKey', function () {
        it('should call the DataSource findByKey', function (done) {
            var model = new ModelInterface(dataSource, configurations);
            var emailValue = 'davi@versul.com.br';
            var emailName = 'email';
            model.model.findByKey = function (keyValue, keyName, callback) {
                assert.equal(emailValue, keyValue);
                assert.equal(emailName, keyName);
                assert.equal('function', typeof callback);
                done();
            };
            model.findByKey(emailValue, emailName, function () { return; });
        });
    });

    describe('save', function () {
        it('should call the DataSource save', function (done) {
            var model = new ModelInterface(dataSource, configurations);
            var id = '02895328099';
            var data = {};
            var options = {};

            model.model.save = function (_id, _data, callback, prefix, _options) {
                assert.equal(id, _id);
                assert.equal(data, _data);
                assert.equal(null, prefix);
                assert.equal(options, _options);
                assert.equal('function', typeof callback);
                done();
            };
            model.save(id, data, function () { return; }, null, options);
        });
    });

    describe('removeById', function () {
        it('should call the DataSource removeById', function (done) {
            var model = new ModelInterface(dataSource, configurations);
            var id = '02895328099';

            model.model.save = function (_id, callback) {
                assert.equal(id, _id);
                assert.equal('function', typeof callback);
                done();
            };
            model.save(id, function () { return; });
        });
    });
});