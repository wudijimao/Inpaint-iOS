//
//  SmudgeDrawingView.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/1.
//

import Foundation
import UIKit

class SmudgeDrawingView: UIView {

    private var path: UIBezierPath = UIBezierPath()
    private var touchPoints: [CGPoint] = []
    var smudgeColor: UIColor = UIColor.lightGray.withAlphaComponent(0.5) // 默认为半透明的淡蓝色
    var exportLineColor: UIColor = .white // 涂抹部分导出时的颜色
    var exportBackgroundColor: UIColor = .black // 未涂抹部分导出时的颜色
    var brushSize: CGFloat = 10.0 // 默认笔刷大小


    init() {
        super.init(frame: .zero)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public var drawBounds: [CGRect] {
        get {
            if path.isEmpty {
                return []
            }
            var rect = path.bounds
            rect = CGRect(x: rect.origin.x * UIScreen.main.scale, y: rect.origin.y * UIScreen.main.scale, width: rect.size.width * UIScreen.main.scale, height: rect.size.height * UIScreen.main.scale)
            return [rect]
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchPoint = touch.location(in: self)
        path.move(to: touchPoint)
        touchPoints.append(touchPoint)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchPoint = touch.location(in: self)
        path.addLine(to: touchPoint)
        touchPoints.append(touchPoint)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        smudgeColor.setStroke()
        path.lineWidth = brushSize
        path.stroke()
    }

    func exportAsGrayscaleImage() -> UIImage? {
        let screenScale = UIScreen.main.scale

        // 放大后的尺寸
        let scaledSize = CGSize(width: self.bounds.size.width * screenScale, height: self.bounds.size.height * screenScale)

        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }


        // 绘制背景
        exportBackgroundColor.setFill()
        context.fill(CGRect(x: 0, y: 0, width: scaledSize.width, height: scaledSize.height))

        // 调整路径尺寸
        let scaledPath = UIBezierPath(cgPath: path.cgPath)
        scaledPath.apply(CGAffineTransform(scaleX: screenScale, y: screenScale))
        exportLineColor.setStroke()
        scaledPath.lineWidth = brushSize * screenScale // 调整线宽
        scaledPath.stroke()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    
    public func clean() {
        path = UIBezierPath()
        self.setNeedsDisplay()
    }
}
