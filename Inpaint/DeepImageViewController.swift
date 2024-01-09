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

// 图像深度预测
protocol ImageDepthPrediction {
    // 异步
    func depthPrediction(image: UIImage, completion: @escaping (UIImage?, [Float]?, NSError?) -> Void)
}

extension MLShapedArray {
    var array: [Scalar] {
        var ret = [Scalar]()
        self.withUnsafeShapedBufferPointer { ptr, shape, strides in
            ret = Array(ptr)
        }
        return ret
    }
}

class MiDaSImageDepthPrediction: ImageDepthPrediction {
   

    let workQueue = DispatchQueue.init(label: "MiDaSImageDepthPrediction")
    
    lazy var config: MLModelConfiguration = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        return config
    }()
    
    var model: MiDaSMobileSwin2Tiny256FP16?
    
    public init() {
        self.preload()
    }
    
    func depthPrediction(image: UIImage, completion: @escaping (UIImage?, [Float]?, NSError?) -> Void) {
        workQueue.async {
            guard let model = self.model else { return }
//            let scaledImage = image.scaleTo(size: .init(width: 256, height: 256))
            guard let imgBuffer = image.buffer(ofSize: 256) else {
                completion(nil, nil, nil)
                return
            }
            
            do {
                let input = MiDaSMobileSwin2Tiny256FP16Input(input: imgBuffer)
                let result = try model.prediction(input: input)
                guard let outImage = result.depth_image.uiImage else {
                    completion(nil, nil, nil)
                    return
                }
                let depthArray = result.depthShapedArray.array
                DispatchQueue.main.async {
                    completion(outImage, depthArray, nil)
                }
            } catch(let e) {
                print(e)
                completion(nil, nil, e as NSError)
            }
        }
    }

    func preload() {
        workQueue.async {
            do {
                self.model = try MiDaSMobileSwin2Tiny256FP16.init(configuration: self.config)
            } catch(let e) {
                print(e)
            }
        }
    }
    
}



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
        prediction.depthPrediction(image: image) { depthImage, depthData, err in
            self.imageView.image = depthImage
            guard let depthData = depthData else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let vc = DepthImageSenceViewController(image: image, depthData: depthData)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
