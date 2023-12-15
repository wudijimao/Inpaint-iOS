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
        customMaskView.backgroundColor = .white
    }

    private func setupConstraints() {
        imageViewA.translatesAutoresizingMaskIntoConstraints = false
        imageViewB.translatesAutoresizingMaskIntoConstraints = false
        sliderView.translatesAutoresizingMaskIntoConstraints = false
        
        imageViewA.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        imageViewB.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        sliderView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.width.equalTo(2)
            make.centerX.equalToSuperview()
        }

        sliderView.backgroundColor = .black
    }
    
    var maskX: CGFloat = 0
    
    override func layoutSubviews() {
        super.layoutSubviews()
        customMaskView.frame = CGRect(x: 0, y: 0, width: maskX + self.frame.size.width / 2.0, height: bounds.height)
    }

    private func addPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        sliderView.snp.updateConstraints { make in
            make.centerX.equalToSuperview().offset(translation.x)
        }
        maskX = translation.x
        setNeedsLayout()
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
