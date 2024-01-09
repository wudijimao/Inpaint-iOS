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

// 演示使用Vision库来做output是图像的模型运行
class VisionImageViewControllerExample: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // Core ML 模型
    var visionModel: VNCoreMLModel?
    
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
        let config = MLModelConfiguration.init()
        guard let model = try? MiDaSMobileSwin2Tiny256FP16(configuration: config),
            let visionModel = try? VNCoreMLModel(for: model.model) else {
            fatalError("加载模型失败")
        }
        self.visionModel = visionModel
    }

    func generateGrayScaleImage(_ image: UIImage) {
        guard let visionModel = visionModel else {
            print("模型未加载")
            return
        }

        guard let cgImage = image.cgImage else {
            print("无法获取CGImage")
            return
        }

        // 创建 Vision 请求
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            guard let results = request.results as? [VNPixelBufferObservation] else {
                print("无法获取结果")
                return
            }

            // 处理灰度图像结果
            if let topResult = results.first {
                let pixelBuffer = topResult.pixelBuffer
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let uiImage = UIImage(ciImage: ciImage)
                DispatchQueue.main.async {
                    // 在这里更新 UI，例如显示图像
                     self.imageView.image = uiImage
                }
            }
        }

        // 执行 Vision 请求
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            print("执行请求时出错: \(error)")
        }
    }
}
