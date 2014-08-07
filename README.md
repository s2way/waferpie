# NRCM

NRCM is a Request Controller Model framework for NodeJS.

It is an ultra lightweight implementation of a RESTful API that acts as a content provider.

## Features

* MVC similar design: except for the View, which will be always JSONs;
* Couchbase model support;
* Multi-application: several different applications can run inside the same NodeJS HTTP server;
* Couchbase and MySQL data sources supported;
* Assynchronous logging using winston;
* Does **not read a single file from the disk** after startup;

## Setup & Run

1) Create your Node project and install the NRCM dependency locally: 
```bash
$ npm install nrcm
``` 

2) Create your server configuration file and name it config.json:
```json
{
    "urlFormat": "/$application/$controller"
}
```
3) Create a file named index.js:
```javascript
var NRCM = require('nrcm');
var instance = new NRCM();
// Your server configuration JSON file
instance.configure('config.json'); 
// The name of your application 
// If you are not going to use the multi-app feature, name it "app".
instance.setUp('app'); 
// Start your server
instance.start('127.0.0.1', 3333); 
```
4) Start your server by typing: `node index.js`

Your server should be running now. NRCM will automatically create the folder structure of your application.

## Folder Structure

The line `instance.setUp('app')` will create the application folder structure if it does not exist. Your project should look something like this:

```
├── config.json            --> Server configuration file
├── app/
│   ├── src/               --> Application source code folder
│   │   ├── Config/          --> Configuration folder
│   │   ├───├── core.json    --> Application configuration file
│   │   ├── Component/       --> Where your components should be placed
│   │   ├── Controller/      --> All application controllers must go here
│   │   ├── Model/           --> Your models that will access the data sources should go here
│   ├── test/              --> Application tests folder
│   │   ├── Component/       --> Component tests
│   │   ├── Controller/      --> Controller tests
│   │   ├── Model/           --> Model tests
│   ├── logs/              --> Server logs folder
│   │   ├── main.log         --> Main application logs
│   │   ├── exceptions.log   --> Exceptions logs
├── logs/                  --> Server logs
│   ├── main.log             --> Server logs
│   ├── exceptions.log       --> Server exception logs
├── index.js               --> Application entry point
```

If you're using a multi-application server, you can have call `instance.setUp()` several times providing different names. NRCM will load all JS files into memory when the server starts and will not check them anymore.

## Coding

### Server Configuration

The server configuration JSON file has the following properties:

### urlFormat

This is where you specify how your URLs will map to your applications and controllers. There are two placeholders available: $application and $controller. Let's say we have the following format:
`/$application/$controller`. 
The URL */app/my_controller* will map to the application **app** and to the **MyController.js** file that should be located inside *app/src/Controller/*. 

### Controllers

All controllers must be located inside the application's Controller folder. They must be declared as a constructor function and NRCM will try to instantiate them when a valid request is issued. 

```javascript
function MyController() {
    // Perform some initialization here
}

MyController.prototype.get = function (callback) {
    // Query string param
    var says = this.query.says;

    this.statusCode = 200; // Not required: defaults to 200
    // Call the callback function passing the response JSON
    callback({
        'hello_world' : 'NRCM says: ' + says
    });
};

// You MUST export the controller constructor
module.exports = MyController;
```
You can test this example with **curl**:
```bash
$ curl -X GET http://localhost:3333/app/my_controller?says=Hi
```
The following output is expected:
```json
{
    "hello_world" : "NRCM says: Hi"
}
```

The method `MyController.get()` is called because we are issuing a HTTP GET. You can implement the other methods as well:

```javascript
function AnotherController() {
    // Perform some initialization here
}

AnotherController.prototype.post = function (callback) {
    // Call the callback function passing the response JSON
    this.headers['X-NRCM'] = 'This is a custom header';
    // Use the function below for logging 
    this.logger.info("Logging cool information"); 
    callback({
        'my_payload_is' : this.payload, // Access the payload as a JSON
        'my_query_string_is' : this.query // Access the query string as a JSON
    });
};

// You MUST export the controller constructor
module.exports = AnotherController;
```
NRCM supports key application/x-www-form-urlencoded and application/json payloads. Both are treated internally as JSONs;

### Models

Models obey exactly the same rules for the controllers. You should create them inside the Models/ folder and they must export a constructor function.

```javascript
function CoolModel() {
    // Perform some initialization here
}

CoolModel.prototype.find = function (callback) {
    // Perform an assynchronous database operation and them call the callback passing the result
    ...
    callback(err, result);
};

// You MUST export the model constructor
module.exports = CoolModel;
```

### Data Sources

Depending on the data source you choose for your models, different methods will be available.

#### Data Source Configuration

All DataSource configuration is located within the **app/Config/core.json** file. It should look something like this:

```json
{
    "requestTimeout" : 10000,
    "dataSources" : {
        "default" : {
            "type" : "Couchbase",
            "host" : "0.0.0.0",
            "port" : "8091",
            "index" : "index"
        },
        "mysql" : {
            "type" : "MySQL",
            "host" : "0.0.0.0",
            "port" : "3306",
            "user" : "root",
            "password" : ""
        }
    }
}
```
All models will use the **default** DataSource by default.

#### MySQL

```javascript
function Order() {
    this.dataSource = 'mysql'; 
}

Order.prototype.findAll = function (callback) {

    $.use('my_database', function () {
        $.query('SELECT * FROM order', [], function (err, rows, result) {
            callback(err, rows);
        });
    });

};
```

#### Couchbase

### Components

## Testing

### Controllers

### Models

### Components

## Conventions & Restrictions

* All controllers, components, and models should be named in CamelCase;
* Plural names are prefered for controllers and singular ones for models;
* All URLs are assumed to be lowercase and underscored. For example: `/my_application/my_controller`;
* Extensions are not allowed at the end of URL. Something like `/my_application/my_controller.json` will be rejected by the server;
* If the URL does not match the *urlFormat* specified in the **config.json**, the server will reject the request;
