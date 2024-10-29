# cordova-plugin-signature-capture
Signature and Biometric Data Capture

### Installation
```markdown
cordova plugin add https://github.com/PedroRF123154/cordova-plugin-signature-capture.git
```
### Example
```markdown
cordova.plugins.SignatureCapture.captureSignature(
    (result) => {        
        const imagePath = result.imagePath;
        const biometricData = result.biometricData;

        
    },
    (error) => {
        console.error("Error al capturar firma:", error);
    }
);
```
### Supported Platforms
- Android
- iOS
