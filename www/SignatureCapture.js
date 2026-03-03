cordova.define("es.seogirona.signaturecapture.SignatureCapture", function(require, exports, module) {
  var exec = require('cordova/exec');

  exports.openSignatureScreen = function (success, error) {
    exec(success, error, "SignatureCapture", "openSignatureScreen", []);
  };

  exports.captureSignature = function (success, error) {
    exec(success, error, "SignatureCapture", "openSignatureScreen", []);
  };
});
