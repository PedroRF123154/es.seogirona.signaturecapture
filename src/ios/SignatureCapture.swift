import UIKit
import Cordova

@objc(SignatureCapture) class SignatureCapture: CDVPlugin {
    @objc(captureSignature:)
    func captureSignature(command: CDVInvokedUrlCommand) {
        let width = 500
        let height = 500
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/firma.png"
        if let pngData = image?.pngData() {
            do {
                try pngData.write(to: URL(fileURLWithPath: path))
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Firma guardada en: \(path)")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            } catch {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Error al guardar la firma")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }
}