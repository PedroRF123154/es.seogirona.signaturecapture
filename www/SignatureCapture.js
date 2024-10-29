cordova.define("es.seogirona.signaturecapture.SignatureCapture", function(require, exports, module) {
var exec = require('cordova/exec');

exports.captureSignature = function(success, error) {
    exec(success, error, "SignatureCapture", "captureSignature", []);
};
});