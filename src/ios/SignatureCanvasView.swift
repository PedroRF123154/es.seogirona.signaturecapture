import UIKit

final class SignatureCanvasView: UIImageView {

    var path = UIBezierPath()
    var onPoint: ((CGPoint, UITouch, TimeInterval) -> Void)?
    var onBegin: ((CGPoint, UITouch, TimeInterval) -> Void)?
    var onEnd: ((CGPoint, UITouch, TimeInterval) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .white
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        let ts = touch.timestamp
        path.move(to: p)
        onBegin?(p, touch, ts)
        drawPath()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        let ts = touch.timestamp
        path.addLine(to: p)
        onPoint?(p, touch, ts)
        drawPath()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        let ts = touch.timestamp
        onEnd?(p, touch, ts)
        drawPath()
    }

    private func drawPath() {
        UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0)
        image?.draw(in: bounds)
        UIColor.black.setStroke()
        path.lineWidth = 2.0
        path.stroke()
        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
}
