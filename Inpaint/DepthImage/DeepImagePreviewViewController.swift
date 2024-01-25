//
//  DeepImagePreviewViewController.swift
//  Inpaint
//  用于演示效果，促进用户购买
//  Created by wudijimao on 2024/1/25.
//

import UIKit
import SnapKit
import Toast_Swift

// 图片生成深度图
class DeepImagePreviewViewController: UIViewController {

    var imageView = UIImageView()
    
    public init() {
        super.init(nibName: nil, bundle: nil)
//        imageView.image = image
//        imageView.backgroundColor = .red
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
    }

    func loadModel() {

    }
    
    func setupSaveButton() {
        let selectButton = UIBarButtonItem(title: *"try my photo", style: .plain, target: self, action: #selector(onTakePhoto))
        self.navigationItem.rightBarButtonItems = [selectButton]
    }
    
    @objc func onResetView() {
        self.senceVC?.resetPosition()
    }
    
    @objc func onTakePhoto() {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.senceVC?.save {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
        }
    }
    
    var senceVC: DepthImageSenceViewController?

    func generateGrayScaleImage(_ image: UIImage) {
        self.view.makeToastActivity(.center)
        
    }
}
