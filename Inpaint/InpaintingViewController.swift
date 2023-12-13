//
//  InpaintingViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/13.
//

import UIKit
import SnapKit
import Toast_Swift

class InpaintingViewController: UIViewController {
    var imageView = UIImageView()

    var inpenting = LaMaImageInpenting.init()
    
    // 新增：加载指示器
    var loadngView = UIActivityIndicatorView(style: .large)

    lazy var drawView: SmudgeDrawingView = {
        let view = SmudgeDrawingView.init()
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        view.addSubview(imageView)
        imageView.backgroundColor = .systemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
        
        imageView.addSubview(drawView)
        imageView.isUserInteractionEnabled = true
        drawView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 创建消除和保存按钮
        let clearButton = UIBarButtonItem(title: "消除", style: .plain, target: self, action: #selector(onClear))
        let saveButton = UIBarButtonItem(title: "保存", style: .plain, target: self, action: #selector(onSave))
        
        // 将按钮添加到导航栏
        navigationItem.rightBarButtonItems = [saveButton, clearButton]
        
        loadngView.hidesWhenStopped = true
        view.addSubview(loadngView)
        loadngView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
    }
    

    @objc func onClear() {
        guard let inputImage = imageView.image else { return }
        var maskImage = UIImage.init(named: "mask")!
        maskImage = drawView.exportAsGrayscaleImage()!
        loadngView.startAnimating()
        inpenting.inpent(image: inputImage, mask: maskImage, inpaintingRects: drawView.drawBounds) { [weak self] outImage, err in
            guard let self = self else { return }
            self.imageView.image = outImage
            self.imageView.contentMode = .scaleAspectFit
            self.drawView.clean()
            self.loadngView.stopAnimating()
        }
        
    }
    
    @objc func onSave() {
        // 检查 imageView 是否有图像
        guard let imageToSave = imageView.image else {
            print("没有可保存的图像")
            return
        }

        // 保存图像到相册
        UIImageWriteToSavedPhotosAlbum(imageToSave, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    // UIImageWriteToSavedPhotosAlbum 的回调方法
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // 保存失败，显示Toast消息
            self.view.makeToast("保存失败: \(error.localizedDescription)", duration: 3.0, position: .bottom)
        } else {
            // 保存成功
            self.view.makeToast("图像成功保存到相册", duration: 3.0, position: .bottom)
        }
    }
    
}
