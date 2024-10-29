import Foundation
import UIKit

@objc(SignatureCapture) class SignatureCapture: CDVPlugin {
    
    var signatureView: UIView?
    var closeButton: UIButton?
    var saveButton: UIButton?
    var path = UIBezierPath()
    var biometricData: [[String: Any]] = []
    var lastPoint: CGPoint = .zero
    var lastTimestamp: TimeInterval = 0
    var signatureImageView: UIImageView?
    
    @objc(openSignatureScreen:)
    func openSignatureScreen(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            // Configurar vista de firma
            self.signatureView = UIView(frame: UIScreen.main.bounds)
            self.signatureView?.backgroundColor = .white
            
            // Bloquear orientación en horizontal
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
            
            // Configurar ImageView para la firma
            self.signatureImageView = UIImageView(frame: UIScreen.main.bounds)
            self.signatureImageView?.backgroundColor = .white
            self.signatureImageView?.isUserInteractionEnabled = true
            if let signatureImageView = self.signatureImageView {
                self.signatureView?.addSubview(signatureImageView)
            }
            
            // Configurar botón Cerrar
            self.closeButton = UIButton(type: .custom)
            self.closeButton?.frame = CGRect(x: UIScreen.main.bounds.width - 70, y: 30, width: 50, height: 50)
            self.closeButton?.backgroundColor = .red
            self.closeButton?.setTitle("X", for: .normal)
            self.closeButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
            self.closeButton?.layer.cornerRadius = 25
            self.closeButton?.addTarget(self, action: #selector(self.closeSignatureScreen), for: .touchUpInside)
            
            // Configurar botón Guardar
            self.saveButton = UIButton(type: .custom)
            self.saveButton?.frame = CGRect(x: 20, y: UIScreen.main.bounds.height - 70, width: 100, height: 50)
            self.saveButton?.backgroundColor = .blue
            self.saveButton?.setTitle("Guardar", for: .normal)
            self.saveButton?.layer.cornerRadius = 10
            self.saveButton?.addTarget(self, action: #selector(self.saveSignature), for: .touchUpInside)
            
            if let signatureView = self.signatureView, let closeButton = self.closeButton, let saveButton = self.saveButton {
                signatureView.addSubview(closeButton)
                signatureView.addSubview(saveButton)
                self.viewController.view.addSubview(signatureView)
            }
            
            // Inicializar el camino de dibujo
            self.path = UIBezierPath()
            self.path.lineWidth = 2.0
            self.lastTimestamp = Date().timeIntervalSince1970
            
            // Habilitar eventos de toque
            self.signatureImageView?.isUserInteractionEnabled = true
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
        let speed = distance / CGFloat(timeDifference) // velocidad en puntos por segundo
        
        // Guardar datos biométricos
        if let touch = gesture.touches(for: gesture)?.first {
            let pressure = touch.force / touch.maximumPossibleForce
            let dataPoint: [String: Any] = [
                "x": currentPoint.x,
                "y": currentPoint.y,
                "pressure": pressure,
                "timestamp": currentTimestamp,
                "speed": speed
            ]
            biometricData.append(dataPoint)
        }
        
        if gesture.state == .began {
            path.move(to: currentPoint)
        } else if gesture.state == .changed {
            path.addLine(to: currentPoint)
            lastPoint = currentPoint
            lastTimestamp = currentTimestamp
        }
        
        UIGraphicsBeginImageContext(signatureView.frame.size)
        signatureImageView?.image?.draw(in: signatureView.bounds)
        UIColor.black.setStroke()
        path.stroke()
        signatureImageView?.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    @objc func closeSignatureScreen() {
        DispatchQueue.main.async {
            // Cambiar orientación a vertical
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            
            // Remover vista de firma y botón Cerrar
            self.signatureView?.removeFromSuperview()
            self.closeButton?.removeFromSuperview()
            self.saveButton?.removeFromSuperview()
        }
    }
    
    @objc func saveSignature() {
        DispatchQueue.main.async {
            // Guardar la imagen de la firma en almacenamiento interno
            if let signatureImage = self.signatureImageView?.image {
                if let data = signatureImage.pngData() {
                    let filePath = NSTemporaryDirectory() + "firma_\(Int(Date().timeIntervalSince1970)).png"
                    let url = URL(fileURLWithPath: filePath)
                    do {
                        try data.write(to: url)
                        // Convertir datos biométricos a JSON y enviar junto con la ruta de la imagen
                        let jsonData = try JSONSerialization.data(withJSONObject: self.biometricData, options: [])
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                        
                        let result: [String: Any] = [
                            "imagePath": filePath,
                            "biometricData": jsonString
                        ]
                        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
                        self.commandDelegate.send(pluginResult, callbackId: self.command.callbackId)
                    } catch {
                        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Error al guardar la firma")
                        self.commandDelegate.send(pluginResult, callbackId: self.command.callbackId)
                    }
                }
            }
            // Cerrar pantalla de firma
            self.closeSignatureScreen()
        }
    }
}
