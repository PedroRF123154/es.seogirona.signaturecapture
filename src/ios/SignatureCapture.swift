import Foundation
import UIKit

@objc(SignatureCapture)
class SignatureCapture: CDVPlugin {

    var signatureView: UIView?
    var closeButton: UIButton?
    var saveButton: UIButton?

    var biometricData: [[String: Any]] = []
    var lastPoint: CGPoint = .zero
    var lastTimestamp: TimeInterval = 0

    var signatureCanvas: SignatureCanvasView?
    var callbackId: String?

    @objc(openSignatureScreen:)
    func openSignatureScreen(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId

        DispatchQueue.main.async {
            self.biometricData.removeAll()
            self.lastPoint = .zero
            self.lastTimestamp = 0

            // Vista contenedor
            let container = UIView(frame: UIScreen.main.bounds)
            container.backgroundColor = .white
            self.signatureView = container

            // Horizontal (ojo: esto es “hack”; más adelante te lo dejo fino si quieres)
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")

            // Canvas de firma
            let canvas = SignatureCanvasView(frame: container.bounds)
            self.signatureCanvas = canvas
            container.addSubview(canvas)

            canvas.onBegin = { [weak self] p, touch in
                guard let self else { return }
                self.lastPoint = p
                self.lastTimestamp = touch.timestamp
                self.appendBiometric(point: p, touch: touch)
            }

            canvas.onPoint = { [weak self] p, touch in
                guard let self else { return }
                self.appendBiometric(point: p, touch: touch)
                self.lastPoint = p
                self.lastTimestamp = touch.timestamp
            }

            // Botón cerrar
            let close = UIButton(type: .custom)
            close.frame = CGRect(x: container.bounds.width - 70, y: 30, width: 50, height: 50)
            close.backgroundColor = .red
            close.setTitle("X", for: .normal)
            close.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
            close.layer.cornerRadius = 25
            close.addTarget(self, action: #selector(self.closeSignatureScreen), for: .touchUpInside)
            self.closeButton = close
            container.addSubview(close)

            // Botón guardar
            let save = UIButton(type: .custom)
            save.frame = CGRect(x: 20, y: container.bounds.height - 70, width: 120, height: 50)
            save.backgroundColor = .blue
            save.setTitle("Guardar", for: .normal)
            save.layer.cornerRadius = 10
            save.addTarget(self, action: #selector(self.saveSignature), for: .touchUpInside)
            self.saveButton = save
            container.addSubview(save)

            self.viewController.view.addSubview(container)
        }
    }

    private func appendBiometric(point: CGPoint, touch: UITouch) {
        let ts = touch.timestamp

        let dt = (lastTimestamp > 0) ? (ts - lastTimestamp) : 0
        let dist = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
        let speed = (dt > 0) ? (Double(dist) / dt) : 0

        let pressure: Double
        if touch.maximumPossibleForce > 0 {
            pressure = Double(touch.force / touch.maximumPossibleForce)
        } else {
            pressure = 0
        }

        biometricData.append([
            "x": Double(point.x),
            "y": Double(point.y),
            "pressure": pressure,
            "timestamp": ts,
            "speed": speed
        ])
    }

    @objc func closeSignatureScreen() {
        DispatchQueue.main.async {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            self.signatureView?.removeFromSuperview()
            self.signatureView = nil
            self.signatureCanvas = nil
        }
    }

    @objc func saveSignature() {
        DispatchQueue.main.async {
            guard let callbackId = self.callbackId else { return }

            guard let img = self.signatureCanvas?.image, let data = img.pngData() else {
                let r = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No hay firma para guardar")
                self.commandDelegate.send(r, callbackId: callbackId)
                self.closeSignatureScreen()
                return
            }

            let filePath = NSTemporaryDirectory() + "firma_\(Int(Date().timeIntervalSince1970)).png"
            let url = URL(fileURLWithPath: filePath)

            do {
                try data.write(to: url)

                let jsonData = try JSONSerialization.data(withJSONObject: self.biometricData, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                let result: [String: Any] = [
                    "imagePath": filePath,
                    "biometricData": jsonString
                ]

                let r = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
                self.commandDelegate.send(r, callbackId: callbackId)
            } catch {
                let r = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Error al guardar la firma")
                self.commandDelegate.send(r, callbackId: callbackId)
            }

            self.closeSignatureScreen()
        }
    }
}
