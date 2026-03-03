import UIKit

final class SignatureCanvasView: UIImageView {

    var path = UIBezierPath()
    var onPoint: ((CGPoint, UITouch) -> Void)?
    var onBegin: ((CGPoint, UITouch) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .white
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        path.move(to: p)
        onBegin?(p, t)
        drawPath()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        path.addLine(to: p)
        onPoint?(p, t)
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
