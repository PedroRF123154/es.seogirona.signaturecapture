import Foundation
import UIKit

@objc(SignatureCapture)
class SignatureCapture: CDVPlugin {

    var signatureView: UIView?
    var closeButton: UIButton?
    var saveButton: UIButton?

    var path = UIBezierPath()
    var biometricData: [[String: Any]] = []
    var lastPoint: CGPoint = .zero
    var lastTimestamp: TimeInterval = 0

    var signatureImageView: UIImageView?

    // Para responder a Cordova
    var callbackId: String?

    // ✅ Acción que tu JS llama: "captureSignature"
    @objc(captureSignature:)
    func captureSignature(command: CDVInvokedUrlCommand) {
        // guardamos callbackId y reutilizamos la pantalla
        self.callbackId = command.callbackId
        self.openSignatureScreen(command: command)
    }

    // ✅ Alias opcional por si lo llamas como "openSignatureScreen"
    @objc(openSignatureScreen:)
    func openSignatureScreen(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId

        DispatchQueue.main.async {
            // Configurar vista de firma
            self.signatureView = UIView(frame: UIScreen.main.bounds)
            self.signatureView?.backgroundColor = .white

            // Bloquear orientación en horizontal (hack)
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")

            // Configurar ImageView para la firma
            self.signatureImageView = UIImageView(frame: UIScreen.main.bounds)
            self.signatureImageView?.backgroundColor = .white
            self.signatureImageView?.isUserInteractionEnabled = true

            if let signatureImageView = self.signatureImageView {
                self.signatureView?.addSubview(signatureImageView)
            }

            // Botón Cerrar
            self.closeButton = UIButton(type: .custom)
            self.closeButton?.frame = CGRect(x: UIScreen.main.bounds.width - 70, y: 30, width: 50, height: 50)
            self.closeButton?.backgroundColor = .red
            self.closeButton?.setTitle("X", for: .normal)
            self.closeButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
            self.closeButton?.layer.cornerRadius = 25
            self.closeButton?.addTarget(self, action: #selector(self.closeSignatureScreen), for: .touchUpInside)

            // Botón Guardar
            self.saveButton = UIButton(type: .custom)
            self.saveButton?.frame = CGRect(x: 20, y: UIScreen.main.bounds.height - 70, width: 120, height: 50)
            self.saveButton?.backgroundColor = .blue
            self.saveButton?.setTitle("Guardar", for: .normal)
            self.saveButton?.layer.cornerRadius = 10
            self.saveButton?.addTarget(self, action: #selector(self.saveSignature), for: .touchUpInside)

            if let signatureView = self.signatureView,
               let closeButton = self.closeButton,
               let saveButton = self.saveButton {
                signatureView.addSubview(closeButton)
                signatureView.addSubview(saveButton)
                self.viewController.view.addSubview(signatureView)
            }

            // Inicializar el camino de dibujo
            self.path = UIBezierPath()
            self.path.lineWidth = 2.0
            self.biometricData.removeAll()
            self.lastPoint = .zero
            self.lastTimestamp = Date().timeIntervalSince1970

            // Gesture (solo posición, NO presión real)
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture(_:)))
            self.signatureImageView?.addGestureRecognizer(panGesture)
        }
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let signatureView = self.signatureImageView else { return }

        let currentPoint = gesture.location(in: signatureView)
        let currentTimestamp = Date().timeIntervalSince1970

        let timeDifference = currentTimestamp - self.lastTimestamp
        let distance = hypot(currentPoint.x - self.lastPoint.x, currentPoint.y - self.lastPoint.y)
        let speed: Double = (timeDifference > 0) ? (Double(distance) / timeDifference) : 0

        // ✅ Con UIPanGestureRecognizer NO hay UITouch => presión real no disponible
        let dataPoint: [String: Any] = [
            "x": Double(currentPoint.x),
            "y": Double(currentPoint.y),
            "pressure": 0.0,
            "timestamp": currentTimestamp,
            "speed": speed
        ]
        biometricData.append(dataPoint)

        if gesture.state == .began {
            path.move(to: currentPoint)
            lastPoint = currentPoint
            lastTimestamp = currentTimestamp
        } else if gesture.state == .changed {
            path.addLine(to: currentPoint)
            lastPoint = currentPoint
            lastTimestamp = currentTimestamp
        }

        UIGraphicsBeginImageContextWithOptions(signatureView.bounds.size, true, 0)
        signatureImageView?.image?.draw(in: signatureView.bounds)
        UIColor.black.setStroke()
        path.stroke()
        signatureImageView?.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }

    @objc func closeSignatureScreen() {
        DispatchQueue.main.async {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")

            self.signatureView?.removeFromSuperview()
            self.signatureView = nil
            self.closeButton = nil
            self.saveButton = nil
            self.signatureImageView = nil
        }
    }

    @objc func saveSignature() {
        DispatchQueue.main.async {
            guard let cb = self.callbackId else { return }

            guard let signatureImage = self.signatureImageView?.image,
                  let data = signatureImage.pngData() else {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No hay firma para guardar")
                self.commandDelegate.send(pluginResult, callbackId: cb)
                self.closeSignatureScreen()
                return
            }

            let filePath = NSTemporaryDirectory() + "firma_\(Int(Date().timeIntervalSince1970)).png"
            let url = URL(fileURLWithPath: filePath)

            do {
                try data.write(to: url)

                // Enviamos biometricData como JSON string (como estabas haciendo)
                let jsonData = try JSONSerialization.data(withJSONObject: self.biometricData, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                let result: [String: Any] = [
                    "imagePath": filePath,
                    "biometricData": jsonString
                ]

                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
                self.commandDelegate.send(pluginResult, callbackId: cb)
            } catch {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Error al guardar la firma")
                self.commandDelegate.send(pluginResult, callbackId: cb)
            }

            self.closeSignatureScreen()
        }
    }
}
