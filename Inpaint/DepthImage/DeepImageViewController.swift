//
//  DeepImageViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/25.
//

import UIKit
import Vision
import CoreML
import SnapKit

// 图片生成深度图
class DeepImageViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // Core ML 模型
    lazy var prediction: MiDaSImageDepthPrediction = MiDaSImageDepthPrediction()
    
    let image: UIImage
    
    var imageView = UIImageView()
    
    public init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        imageView.image = image
        imageView.backgroundColor = .red
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(imageView)
        imageView.backgroundColor = .systemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        

        // 加载模型
        loadModel()
        
        // 对选择的图片进行处理
        generateGrayScaleImage(image)
    }
    
    var lama: LaMaFP16_512?

    func loadModel() {
        _ = prediction
    }

    func generateGrayScaleImage(_ image: UIImage) {
        prediction.depthPrediction(image: image) { [weak self] depthImage, depthData, err in
            guard let self = self else { return }
            //            self.imageView.image = depthImage
            guard let depthData = depthData else { return }
            let vc = DepthImageSenceViewController(image: image, depthData: depthData)
            self.addChild(vc)
            self.view.addSubview(vc.view)
            vc.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                vc.didMove(toParent: self)
            }
        }
    }
}
