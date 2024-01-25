//
//  ImageDepthPrediction.swift
//  Inpaint
//
//  Created by wu miao on 2024/1/11.
//
import UIKit
import Vision
import CoreML

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
    #if os(visionOS)
        config.computeUnits = .cpuAndNeuralEngine
    #else
        config.computeUnits = .cpuAndGPU
    #endif
        return config
    }()
    
    var model: MiDaSMobileSwin2Tiny256FP16?
    
    public init() {
        self.preload()
    }
    
    func depthPrediction(image: UIImage, completion: @escaping (UIImage?, [Float]?, NSError?) -> Void) {
        workQueue.async {
            guard let model = self.model else { return }
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
