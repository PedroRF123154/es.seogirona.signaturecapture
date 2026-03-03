# cordova-plugin-signature-capture
Signature and Biometric Data Capture

### Installation Android
```markdown
cordova plugin add https://github.com/PedroRF123154/es.seogirona.signaturecapture.git
```
### Example Android
```markdown
cordova.plugins.SignatureCapture.captureSignature(
    (result) => {        
        const imagePath = result.imagePath;
        const fileName = result.fileName;
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
### Installation iOS
```markdown
cordova plugin add https://github.com/PedroRF123154/es.seogirona.signaturecapture.git --variable USESWIFTLANGUAGEVERSION=5.0
```

### Example iOS
```markdown
document.addEventListener("deviceready", function() {
  document.getElementById("captureSignature").addEventListener("click", function() {
    cordova.plugins.SignatureCapture.captureSignature(
      function(result) {
        // mostrar por Base64 (siempre visible)
        if (result.imageBase64) {
          document.getElementById("signatureImage").src = "data:image/png;base64," + result.imageBase64;
          document.getElementById("signatureImage").style.display = "block";
        } else {
          document.getElementById("biometricData").innerText = "No llegó imageBase64.\nRuta: " + result.imagePath;
          return;
        }

        // biometricData viene como string JSON
        let bio = result.biometricData;
        try { bio = JSON.parse(bio); } catch(e) {}

        document.getElementById("biometricData").innerText =
          "Ruta guardada: " + result.imagePath + "\n\n" + JSON.stringify(bio, null, 2);
      },
      function(error) {
        console.error("Error al capturar firma:", error);
        document.getElementById("biometricData").innerText = "Error: " + JSON.stringify(error);
      }
    );
  });
}, false);

En tu config.xml del proyecto Cordova añade:
<preference name="Orientation" value="all" />
```
### Supported Platforms
- Android
- iOS
