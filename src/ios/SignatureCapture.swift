import Foundation
import UIKit

@objc(SignatureCapture)
class SignatureCapture: CDVPlugin {

    var signatureView: UIView?
    var closeButton: UIButton?
    var saveButton: UIButton?
    var signatureImageView: UIImageView?

    var biometricData: [[String: Any]] = []
    var lastPoint: CGPoint = .zero
    var lastTimestamp: TimeInterval = 0

    var callbackId: String?

    // Mantiene tu API JS: captureSignature
    @objc(captureSignature:)
    func captureSignature(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        self.openSignatureScreen(command: command)
    }

    // Alias opcional
    @objc(openSignatureScreen:)
    func openSignatureScreen(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId

        DispatchQueue.main.async {
            self.biometricData.removeAll()
            self.lastPoint = .zero
            self.lastTimestamp = 0

            // Contenedor full-screen y redimensionable
            let container = UIView(frame: self.viewController.view.bounds)
            container.backgroundColor = .white
            container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.signatureView = container

            // Canvas
            let imgView = UIImageView(frame: container.bounds)
            imgView.backgroundColor = .white
            imgView.isUserInteractionEnabled = true
            imgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imgView.contentMode = .scaleToFill
            self.signatureImageView = imgView
            container.addSubview(imgView)

            // Botón cerrar
            let close = UIButton(type: .custom)
            close.backgroundColor = .red
            close.setTitle("X", for: .normal)
            close.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
            close.layer.cornerRadius = 25
            close.addTarget(self, action: #selector(self.closeSignatureScreen), for: .touchUpInside)
            self.closeButton = close
            container.addSubview(close)

            // Botón guardar
            let save = UIButton(type: .custom)
            save.backgroundColor = .blue
            save.setTitle("Guardar", for: .normal)
            save.layer.cornerRadius = 10
            save.addTarget(self, action: #selector(self.saveSignature), for: .touchUpInside)
            self.saveButton = save
            container.addSubview(save)

            // Añadir overlay
            self.viewController.view.addSubview(container)

            // Layout inicial
            self.layoutSignatureUI()

            // Reajustar al rotar
            NotificationCenter.default.addObserver(self,
                                                  selector: #selector(self.onOrientationChanged),
                                                  name: UIDevice.orientationDidChangeNotification,
                                                  object: nil)

            // Pedir landscape (solo funcionará si la app permite landscape)
            self.requestOrientation(.landscape)

            // Gesture para dibujar (1 dedo)
            let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            imgView.addGestureRecognizer(pan)
        }
    }

    @objc private func onOrientationChanged() {
        DispatchQueue.main.async {
            self.layoutSignatureUI()
        }
    }

    private func layoutSignatureUI() {
        guard let container = self.signatureView,
              let close = self.closeButton,
              let save = self.saveButton,
              let canvas = self.signatureImageView else { return }

        container.frame = self.viewController.view.bounds
        canvas.frame = container.bounds

        close.frame = CGRect(x: container.bounds.width - 70, y: 30, width: 50, height: 50)
        save.frame = CGRect(x: 20, y: container.bounds.height - 70, width: 120, height: 50)
    }

    // Dibujo visible: segmento + fondo blanco
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let canvas = self.signatureImageView else { return }

        let p = gesture.location(in: canvas)
        let now = Date().timeIntervalSince1970

        if gesture.state == .began {
            lastPoint = p
            lastTimestamp = now
            return
        }

        if gesture.state == .changed {
            let dt = now - lastTimestamp
            let dist = hypot(p.x - lastPoint.x, p.y - lastPoint.y)
            let speed: Double = (dt > 0) ? (Double(dist) / dt) : 0

            biometricData.append([
                "x": Double(p.x),
                "y": Double(p.y),
                "pressure": 0.0, // PanGesture no da presión real
                "timestamp": now,
                "speed": speed
            ])

            UIGraphicsBeginImageContextWithOptions(canvas.bounds.size, true, 0)

            UIColor.white.setFill()
            UIRectFill(canvas.bounds)

            canvas.image?.draw(in: canvas.bounds)

            let seg = UIBezierPath()
            seg.move(to: lastPoint)
            seg.addLine(to: p)
            seg.lineWidth = 2.5
            seg.lineCapStyle = .round
            seg.lineJoinStyle = .round
            UIColor.black.setStroke()
            seg.stroke()

            canvas.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            lastPoint = p
            lastTimestamp = now
        }
    }

    // iOS16+ orientación correcta
    private func requestOrientation(_ mask: UIInterfaceOrientationMask) {
        DispatchQueue.main.async {
            guard let scene = self.viewController.view.window?.windowScene else { return }
            if #available(iOS 16.0, *) {
                let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
                scene.requestGeometryUpdate(prefs) { _ in }
            }
        }
    }

    @objc func closeSignatureScreen() {
        DispatchQueue.main.async {
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)

            self.requestOrientation(.portrait)

            self.signatureView?.removeFromSuperview()
            self.signatureView = nil
            self.closeButton = nil
            self.saveButton = nil
            self.signatureImageView = nil
        }
    }

    // ✅ Devuelve imageBase64 para que SIEMPRE se vea en HTML
    @objc func saveSignature() {
        DispatchQueue.main.async {
            guard let cb = self.callbackId else { return }

            guard let img = self.signatureImageView?.image,
                  let pngData = img.pngData() else {
                let r = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No hay firma para guardar")
                self.commandDelegate.send(r, callbackId: cb)
                self.closeSignatureScreen()
                return
            }

            let filePath = NSTemporaryDirectory() + "firma_\(Int(Date().timeIntervalSince1970)).png"
            let url = URL(fileURLWithPath: filePath)

            do {
                try pngData.write(to: url)

                let jsonData = try JSONSerialization.data(withJSONObject: self.biometricData, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                let base64 = pngData.base64EncodedString()

                let result: [String: Any] = [
                    "imagePath": filePath,
                    "imageBase64": base64,
                    "biometricData": jsonString
                ]

                let r = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
                self.commandDelegate.send(r, callbackId: cb)
            } catch {
                let r = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Error al guardar la firma")
                self.commandDelegate.send(r, callbackId: cb)
            }

            self.closeSignatureScreen()
        }
    }
}
