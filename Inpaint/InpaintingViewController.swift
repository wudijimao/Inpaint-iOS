//
//  InpaintingViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/13.
//

import UIKit
import SnapKit

class InpaintingViewController: UIViewController {
    var imageView = UIImageView()

    var inpenting = LaMaImageInpenting.init()

    lazy var drawView: SmudgeDrawingView = {
        let view = SmudgeDrawingView.init()
        return view
    }()

    lazy var confirmBtn: UIButton = {
        let btn = UIButton.init()
        btn.setTitle("确定", for: .normal)
        btn.backgroundColor = .lightGray
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(onConfirm), for: .touchUpInside)
        return btn
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

        view.addSubview(confirmBtn)
        confirmBtn.snp.makeConstraints { make in
            make.width.equalTo(100)
            make.height.equalTo(50)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-100)
        }
    }
    
    

    @objc func onConfirm() {
        guard let inputImage = imageView.image else { return }
        var maskImage = UIImage.init(named: "mask")!
        maskImage = drawView.exportAsGrayscaleImage()!
        self.imageView.image = maskImage
        inpenting.inpent(image: inputImage, mask: maskImage, inpaintingRects: drawView.drawBounds) { [weak self] outImage, err in
            self?.imageView.image = outImage
            self?.imageView.contentMode = .scaleAspectFit
        }
        drawView.clean()
    }
}
