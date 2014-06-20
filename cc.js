var fs = require('fs');
var minimalCoverage = 90;

var cc = JSON.parse(fs.readFileSync('cc.json', "utf8"));
if (cc) {
    console.log('-> Code Coverage: ' + cc.coverage + '% <-');
    if (cc.coverage > minimalCoverage) {
        process.exit(0);
    } else {
        console.log('ERROR: Code Coverage below minimum of ' + minimalCoverage + '%!');
    }
}

process.exit(1);
