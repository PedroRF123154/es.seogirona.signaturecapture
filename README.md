# cordova-plugin-signature-capture
Signature and Biometric Data Capture

This plugin provides access to some native dialog UI elements via a global navigator.notification object.

Although the object is attached to the global scoped navigator, it is not available until after the deviceready event.

document.addEventListener("deviceready", onDeviceReady, false);
function onDeviceReady() {
    console.log(navigator.notification);
}

Installation

cordova plugin add cordova-plugin-dialogs

Methods
