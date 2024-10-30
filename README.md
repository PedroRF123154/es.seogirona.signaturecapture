# cordova-plugin-signature-capture
Signature and Biometric Data Capture

### Installation
```markdown
cordova plugin add https://github.com/PedroRF123154/es.seogirona.signaturecapture.git
```
### Example
```markdown
cordova.plugins.SignatureCapture.captureSignature(
    (result) => {        
        const imagePath = result.imagePath;
        const biometricData = result.biometricData;

        document.getElementById("signatureImage").src = imagePath;
        document.getElementById("signatureImage").style.display = "block";        
        document.getElementById("biometricData").innerText = JSON.stringify(biometricData, null, 2);
    },
    (error) => {
        console.error("Error al capturar firma:", error);
    }
);
```
### Supported Platforms
- Android
- iOS
