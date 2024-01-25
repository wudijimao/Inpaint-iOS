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
import Toast_Swift

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

    func loadModel() {
        _ = prediction
    }
    
    func setupSaveButton() {
        let saveButton = UIBarButtonItem(title: *"save_to_photo_lib", style: .plain, target: self, action: #selector(onSave))
        
        let resetViewButton = UIBarButtonItem(title: *"重置视角", style: .plain, target: self, action: #selector(onResetView))
        self.navigationItem.rightBarButtonItems = [saveButton, resetViewButton]
    }
    
    @objc func onResetView() {
        self.senceVC?.resetPosition()
    }
    
    @objc func onSave() {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.senceVC?.save {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
        }
    }
    
    var senceVC: DepthImageSenceViewController?

    func generateGrayScaleImage(_ image: UIImage) {
        self.view.makeToastActivity(.center)
        prediction.depthPrediction(image: image) { [weak self] depthImage, depthData, err in
            guard let self = self else { return }
            self.view.hideToastActivity()
            //            self.imageView.image = depthImage
            guard let depthData = depthData else { return }
            self.setupSaveButton()
            self.imageView.isHidden = true
            
            depthData.saveTo(fileURL: URL.documentsDirectory.appendingPathComponent("depth.data"))
            let vc = DepthImageSenceViewController(image: image, depthData: depthData)
            self.senceVC = vc
            self.addChild(vc)
            self.view.addSubview(vc.view)
            vc.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                vc.didMove(toParent: self)
            }
        }
    }
}
