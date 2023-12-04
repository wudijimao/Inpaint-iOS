//
//  SplitImageView.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/3.
//

import Foundation
import UIKit

class SplitImageView: UIView {

    private let imageViewA = UIImageView()
    private let imageViewB = UIImageView()
    private let customMaskView = UIView()
    private let sliderView = UIView()

    // 便利初始化方法接受可选的UIImage
    convenience init(imageA: UIImage?, imageB: UIImage?) {
        self.init(frame: .zero)
        setImageA(imageA)
        setImageB(imageB)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        addPanGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        addPanGesture()
    }

    private func setupViews() {
        // 配置imageViewA和imageViewB
        imageViewA.contentMode = .scaleAspectFill
        imageViewB.contentMode = .scaleAspectFill

        imageViewA.clipsToBounds = true
        imageViewB.clipsToBounds = true

        // 添加视图到SplitImageView
        addSubview(imageViewA)
        addSubview(imageViewB)
        addSubview(sliderView)

        // 设置遮罩
        imageViewB.mask = customMaskView

        // 设置自动布局
        setupConstraints()
        
        // 初始化遮罩视图的frame
        customMaskView.backgroundColor = .clear
        updateMaskViewFrame()
    }

    private func setupConstraints() {
        imageViewA.translatesAutoresizingMaskIntoConstraints = false
        imageViewB.translatesAutoresizingMaskIntoConstraints = false
        sliderView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageViewA.topAnchor.constraint(equalTo: topAnchor),
            imageViewA.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageViewA.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageViewA.trailingAnchor.constraint(equalTo: trailingAnchor),

            imageViewB.topAnchor.constraint(equalTo: topAnchor),
            imageViewB.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageViewB.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageViewB.trailingAnchor.constraint(equalTo: trailingAnchor),

            sliderView.centerYAnchor.constraint(equalTo: centerYAnchor),
            sliderView.centerXAnchor.constraint(equalTo: centerXAnchor),
            sliderView.widthAnchor.constraint(equalToConstant: 2),
            sliderView.heightAnchor.constraint(equalTo: heightAnchor)
        ])

        sliderView.backgroundColor = .black
    }

    private func addPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sliderView.addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        sliderView.center.x += translation.x
        gesture.setTranslation(.zero, in: self)

        // 确保sliderView不会离开视图边界
        sliderView.center.x = max(min(sliderView.center.x, bounds.maxX), bounds.minX)

        updateMaskViewFrame()
    }

    private func updateMaskViewFrame() {
        // 更新遮罩视图的frame以匹配sliderView的位置
        customMaskView.frame = CGRect(x: 0, y: 0, width: sliderView.frame.minX, height: bounds.height)
    }

    // 允许外部设置图片A，接受UIImage?类型
    public func setImageA(_ image: UIImage?) {
        imageViewA.image = image
    }

    // 允许外部设置图片B，接受UIImage?类型
    public func setImageB(_ image: UIImage?) {
        imageViewB.image = image
    }
}
