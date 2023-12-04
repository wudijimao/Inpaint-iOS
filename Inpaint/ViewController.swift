//
//  ViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2023/11/30.
//

import UIKit
import Vision
import SnapKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    lazy var selectImageBtn: UIButton = {
        let btn = UIButton.init()
        btn.setTitle("选择图片", for: .normal)
        btn.backgroundColor = .lightGray
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(onClick), for: .touchUpInside)
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
        setupScrollView()
        setupSelectImageButton()
    }

    private func setupScrollView() {
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(selectImageBtn.snp.top).offset(-20)
        }

        let images = [("1", "1b"), ("2", "2b"), ("3", "3b")]
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
        selectImageBtn.snp.makeConstraints { make in
            make.width.equalTo(100)
            make.height.equalTo(50)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-100)
        }
    }

    
    @objc func onClick() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker, animated: true, completion: nil)
    }

    // UIImagePickerControllerDelegate methods
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // You can handle the selected image here
        guard let image = info[.originalImage] as? UIImage else { return }
        picker.dismiss(animated: true, completion: {
            let vc = InpaintingViewController()
            vc.imageView.image = image
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true)
        })
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}


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
        
        view.addSubview(imageView)
        imageView.backgroundColor = .white
        imageView.frame = CGRect.init(x: 0, y: 200, width: self.view.frame.size.width, height: self.view.frame.size.width)
//        imageView.image = UIImage.init(named: "input")
        imageView.contentMode = .scaleAspectFill
        
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
        drawView.clean()
        inpenting.inpent(image: inputImage, mask: maskImage) { [weak self] outImage, err in
            self?.imageView.image = outImage
            self?.imageView.contentMode = .scaleAspectFill
        }
    }
}

protocol ImageInpenting {
    // 异步
    func inpent(image: UIImage, mask: UIImage, completion: @escaping (UIImage?, NSError?) -> Void)
}

class LaMaImageInpenting: ImageInpenting {

    let workQueue = DispatchQueue.init(label: "LaMaImageInpenting")
    
    lazy var config: MLModelConfiguration = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        return config
    }()
    
    lazy var lama = try! LaMaFP16_1024.init(configuration: config)
    

    func inpent(image: UIImage, mask: UIImage, completion: @escaping (UIImage?, NSError?) -> Void) {
        workQueue.async {
            let img = image.buffer!
            let mask = mask.grayBuffer!
            let outImage = try! self.lama.prediction(image: img, mask: mask)
            DispatchQueue.main.async {
                completion(outImage.output.uiImage, nil)
            }
        }
    }

    func preload() {
        workQueue.async {
            _ = self.lama
        }
    }
    
}

extension CVPixelBuffer {
    var uiImage: UIImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage
    }
}

let kImageSize = 1024

extension UIImage {
//    import VideoToolbox
    
    var buffer: CVPixelBuffer? {
        let feature = try! MLFeatureValue.init(cgImage: self.cgImage!, pixelsWide: kImageSize, pixelsHigh: kImageSize, pixelFormatType: kCVPixelFormatType_32ARGB)
        return feature.imageBufferValue
    }
    
    var grayBuffer: CVPixelBuffer? {
        let feature = try! MLFeatureValue.init(cgImage: self.cgImage!, pixelsWide: kImageSize, pixelsHigh: kImageSize, pixelFormatType: kCVPixelFormatType_OneComponent8)
        return feature.imageBufferValue
    }
}
