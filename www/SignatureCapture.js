var exec = require('cordova/exec');

// Mantengo TU nombre: captureSignature
exports.captureSignature = function(success, error) {
  exec(success, error, "SignatureCapture", "captureSignature", []);
};

// Alias opcional (por si lo usas en otra parte)
exports.openSignatureScreen = function(success, error) {
  exec(success, error, "SignatureCapture", "openSignatureScreen", []);
};
