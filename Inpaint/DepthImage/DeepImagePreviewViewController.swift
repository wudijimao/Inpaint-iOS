//
//  DeepImagePreviewViewController.swift
//  Inpaint
//  用于演示效果，促进用户购买
//  Created by wudijimao on 2024/1/25.
//

import UIKit
import SnapKit
import Toast_Swift

// 深度图预览
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
        setupButton()
    }

    func loadModel() {
        guard let image = UIImage(named: "3DExample") else { return }
        guard let depthData = [Float].loadFrom(fileURL: Bundle.main.url(forResource: "depth", withExtension: "data")!) else { return }
        let vc = DepthImageSenceViewController(image: image, depthData: depthData)
        self.senceVC = vc
        self.addChild(vc)
        self.view.addSubview(vc.view)
        vc.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            vc.didMove(toParent: self)
        }
    }
    
    lazy var photo3DGenBtn: UIButton = {
        let btn = UIButton.init()
        btn.setImage(UIImage(named: "3DPhotoButton"), for: .normal)
        btn.setTitle("3D照片生成", for: .normal)
        btn.backgroundColor = .clear
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(onTakePhoto), for: .touchUpInside)
        return btn
    }()
    
    func setupButton() {
        let selectButton = UIBarButtonItem(title: *"Try Your Photo", style: .plain, target: self, action: #selector(onTakePhoto))
        self.navigationItem.rightBarButtonItems = [selectButton]
        
        view.addSubview(photo3DGenBtn)
        photo3DGenBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-10)
            make.size.equalTo(100)
        }
        photo3DGenBtn.layer.cornerRadius = 50
        photo3DGenBtn.clipsToBounds = true
    }
    
    @objc func onResetView() {
        self.senceVC?.resetPosition()
    }
    
    @objc func onTakePhoto() {
        MobClick.event("3dTakePhoto")
        Task { @MainActor in
            self.view.makeToastActivity(.center)
            if await PurchaseManager.shared.purchases() {
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary
                self.present(imagePicker, animated: true, completion: nil)
            } else {
                UIApplication.shared.keyWindow?.makeToast(*"pay_failed")
            }
            self.view.hideToastActivity()
        }
    }
    
    var senceVC: DepthImageSenceViewController?

    func generateGrayScaleImage(_ image: UIImage) {
        self.view.makeToastActivity(.center)
        
    }
}

extension DeepImagePreviewViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // UIImagePickerControllerDelegate methods
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // You can handle the selected image here
        guard let image = info[.originalImage] as? UIImage else { return }
        let scaledImage = image.scaleToLimit(size: .init(width: kLimitImageSize, height: kLimitImageSize))
        picker.dismiss(animated: true, completion: {
            let vc = DeepImageViewController(image: scaledImage)
            self.navigationController?.pushViewController(vc, animated: true)
        })
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
