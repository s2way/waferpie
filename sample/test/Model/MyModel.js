var assert = require('assert');
var path = require('path');
var Testing = require('../../../src/NRCM').Testing;

describe('MyModel', function () {

    var testing = new Testing(path.join(__dirname, '../../../sample'), {
        'default' : {
            'type' : 'Mock',
            'host' : '0.0.0.0',
            'port' : '8091',
            'index' : 'index'
        }
    });

    testing.loadComponent('MyComponent');
    testing.loadModel('MyModel');

    describe('find', function () {

        var model;
        beforeEach(function () {
            model = testing.createModel('MyModel');
        });

        it('should call MyComponent', function (done) {
            model.find(function (result) {
                done();
            });
        });

    });

});
