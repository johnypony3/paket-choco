var push = require('nuget-push');
var glob = require("glob");
var fs = require('fs');

glob("./packages/**/*.nupkg", function(er, files) {
    files.forEach(function(file) {
        uploadPackage(file, function(file) {
            console.log(file);
        });
    })
})

function uploadPackage(file, cb) {
    push(file, 'https://chocolatey.org/', 'process.env.CHOCO_KEY', function(error, response) {
        if (error)
            throw error;
        if (response.statusCode === 201) {
            console.log("success");
            fs.unlinkSync(file);
        } else {
            console.warn(response.statusCode + ":" + response.statusMessage);
        }
    });

    cb(file);
}
