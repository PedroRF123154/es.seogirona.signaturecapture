# cordova-plugin-signature-capture
Signature and Biometric Data Capture

### Installation
```markdown
cordova plugin add https://github.com/PedroRF123154/cordova-plugin-signature-capture.git
```
### Example
```markdown
document.getElementById("captureSignature").addEventListener("click", function() {
            cordova.plugins.SignatureCapture.captureSignature(
                (result) => {
                    // Mostrar la imagen de la firma
                    const imagePath = result.imagePath;
                    const biometricData = result.biometricData;
            
                    document.getElementById("signatureImage").src = imagePath;
                    document.getElementById("signatureImage").style.display = "block";
            
                    // Mostrar los datos biométricos en el contenedor
                    document.getElementById("biometricData").innerText = JSON.stringify(biometricData, null, 2);
                },
                (error) => {
                    console.error("Error al capturar firma:", error);
                    document.getElementById("biometricData").innerText = "Error: " + error;
                }
            );
});
```
### Supported Platforms

    Android
    iOS
