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
    var smudgeColor: UIColor = UIColor.blue.withAlphaComponent(0.5) // 默认为半透明的淡蓝色
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
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // 绘制背景
        exportBackgroundColor.setFill()
        context.fill(self.bounds)

        // 绘制涂抹轨迹
        exportLineColor.setStroke()
        path.lineWidth = brushSize
        path.stroke()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    public func clean() {
        path = UIBezierPath()
    }
}
