//
//  ViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2023/11/30.
//

import UIKit
import Vision
import SnapKit
import Toast_Swift
import Inpainting

let kLimitImageSize: CGFloat = 2048

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    lazy var selectImageBtn: UIButton = {
        let btn = UIButton.init()
        btn.setImage(UIImage(named: "cartoon_button_transparent_background"), for: .normal)
        btn.setTitle("选择图片", for: .normal)
        btn.backgroundColor = .clear
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(onClick), for: .touchUpInside)
        return btn
    }()
    
    lazy var photo3DGenBtn: UIButton = {
        let btn = UIButton.init()
        btn.setImage(UIImage(named: "3DPhotoButton"), for: .normal)
        btn.setTitle("3D照片生成", for: .normal)
        btn.backgroundColor = .clear
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(onClick3DPhotoGen), for: .touchUpInside)
        return btn
    }()
    
    lazy var settingBtn: UIButton = {
        let btn = UIButton.init()
        btn.setImage(UIImage(systemName: "gear"), for: .normal)
        btn.backgroundColor = .clear
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(onSetting), for: .touchUpInside)
        return btn
    }()

    
    
    // UIScrollView实例
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(scrollView)
        view.addSubview(selectImageBtn)
        view.addSubview(photo3DGenBtn)
        view.addSubview(settingBtn)
        setupScrollView()
        setupSelectImageButton()
    }

    private func setupScrollView() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(selectImageBtn.snp.top).offset(-20)
        }
        scrollView.layer.cornerRadius = 20.0
        scrollView.layer.cornerCurve = .continuous
        scrollView.layer.masksToBounds = true

//        let images = [("1", "1b"), ("2", "2b"), ("3", "3b")]
        let images = [("1", "1b")]
        var previousSplitImageView: SplitImageView?

        for imagePair in images {
            let splitImageView = SplitImageView(imageA: UIImage(named: imagePair.0),
                                                imageB: UIImage(named: imagePair.1))
            scrollView.addSubview(splitImageView)

            splitImageView.snp.makeConstraints { make in
                make.left.equalToSuperview()
                make.width.equalTo(scrollView.snp.width)
                make.height.equalTo(scrollView.snp.height)
                
                if let previous = previousSplitImageView {
                    make.top.equalTo(previous.snp.bottom)
                } else {
                    make.top.equalToSuperview()
                }
            }

            previousSplitImageView = splitImageView
        }

        if let lastImageView = previousSplitImageView {
            lastImageView.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
            }
        }
    }

    private func setupSelectImageButton() {
        settingBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.bottom.equalTo(scrollView.snp.top)
            make.size.equalTo(40)
        }
        selectImageBtn.snp.makeConstraints { make in
            make.width.equalTo(100)
            make.height.equalTo(100)
            make.centerX.equalToSuperview().offset(-50)
            make.bottom.equalToSuperview().offset(-50)
        }
        photo3DGenBtn.snp.makeConstraints { make in
            make.width.equalTo(60)
            make.height.equalTo(60)
            make.leading.equalTo(selectImageBtn.snp.trailing).offset(28)
            make.centerY.equalTo(selectImageBtn)
        }
        photo3DGenBtn.clipsToBounds = true
        photo3DGenBtn.layer.cornerRadius = 30
        photo3DGenBtn.layer.cornerCurve = .continuous
        UIView.animate(withDuration: 0.8, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction], animations: {
            // 放大到1.2倍
            self.photo3DGenBtn.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { finished in
            // 动画完成后恢复到原始大小
            self.photo3DGenBtn.transform = CGAffineTransform.identity
        })
        
        let label = UILabel()
        label.text = "new"
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)
        label.backgroundColor = UIColor.init(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        label.layer.cornerRadius = 4
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.isUserInteractionEnabled = false
        label.textAlignment = .center
        self.view.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(photo3DGenBtn).offset(-10)
            make.right.equalTo(photo3DGenBtn).offset(24)
            make.width.equalTo(40)
            make.height.equalTo(20)
        }
    }
    
    var is3DPhotoGen = false
    
    @objc func onClick3DPhotoGen() {
        MobClick.event("3dClick")
        let vc = DeepImagePreviewViewController.init()
        self.navigationController?.pushViewController(vc, animated: true)
    }

    @objc func onClick() {
        MobClick.event("inpaint")
        is3DPhotoGen = false
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func onSetting() {
        MobClick.event("setting")
        let vc = SettingViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // UIImagePickerControllerDelegate methods
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // You can handle the selected image here
        guard let image = info[.originalImage] as? UIImage else { return }
        let scaledImage = image.scaleToLimit(size: .init(width: kLimitImageSize, height: kLimitImageSize))
        picker.dismiss(animated: true, completion: {
            let vc: UIViewController
            if self.is3DPhotoGen {
                vc = DeepImageViewController(image: scaledImage)
            } else {
                let inpaintVC = InpaintingViewController(image: scaledImage)
                inpaintVC.sendEventBlock = { msg in
                    MobClick.event(msg)
                }
                vc = inpaintVC
            }
            self.navigationController?.pushViewController(vc, animated: true)
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}







