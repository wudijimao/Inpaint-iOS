//
//  Inpainting.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/13.
//

import UIKit
import CoreML
import CoreMLImage

open class Comp: NSObject {
    
}

protocol ImageInpenting {
    // 异步
    func inpent(image: UIImage, mask: UIImage, inpaintingRects:[CGRect], completion: @escaping (UIImage?, NSError?) -> Void)
}

class LaMaImageInpenting: ImageInpenting {

    let workQueue = DispatchQueue.init(label: "LaMaImageInpenting")
    
    var imageSize: Int = 512

    var commandManager: AsyncCommandManager = AsyncCommandManager()
    
    lazy var config: MLModelConfiguration = {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return config
    }()
    
    var lama: LaMaFP16?
    
    public init() {
        self.preload()
    }
    
    func inpent(image: UIImage, mask: UIImage, inpaintingRects:[CGRect], completion: @escaping (UIImage?, NSError?) -> Void) {
        
        let callComplete: (UIImage?, NSError?) -> Void  = { img, err in
            DispatchQueue.main.async {
                completion(img, err)
            }
        }
        
        workQueue.async {
            guard let lama = self.lama else { return }
        
            let rect = inpaintingRects.largestBoundingRect()
            let imgs = image.processForInpainting(mask: mask, cropFrame: rect, targetSize: .init(width: self.imageSize, height: self.imageSize))
            guard let imgBuffer = imgs.img.buffer(ofSize: self.imageSize) else {
                callComplete(nil, nil)
                return
            }
            guard let maskBuffer = imgs.mask.grayBuffer(ofSize: self.imageSize) else {
                callComplete(nil, nil)
                return
            }
            do {
                let result = try lama.prediction(image: imgBuffer, mask: maskBuffer)
                guard let outImage = result.output.uiImage else {
                    callComplete(nil, nil)
                    return
                }
                let finalImage = imgs.transpose.writeBack(to: image, subImg: outImage)
                callComplete(finalImage, nil)
            } catch(let e) {
                print(e)
                callComplete(nil, e as NSError)
            }
            
        }
    }

    func preload() {
        workQueue.async {
            do {
                self.lama = try LaMaFP16.init(modelName: "MIGAN_512", configuration: self.config)
            } catch(let e) {
                print(e)
            }
        }
    }
    
}


extension UIImage {
    func writeBack(image: UIImage, to position: CGPoint) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: self.size)
        let combinedImage = renderer.image { (context) in
            self.draw(at: CGPoint.zero)
            image.draw(in: CGRect(origin: position, size: image.size))
        }
        return combinedImage
    }
}


extension CGRect {

    static func /= (lhs: inout CGRect, rhs: CGFloat) {
        lhs = lhs / rhs
    }

    static func / (lhs: CGRect, rhs: CGFloat) -> CGRect {
        return CGRect(x: lhs.origin.x / rhs, y: lhs.origin.y / rhs, width: lhs.size.width / rhs, height: lhs.size.height / rhs)
    }

    static func *= (lhs: inout CGRect, rhs: CGFloat) {
        lhs = lhs * rhs
    }

    static func * (lhs: CGRect, rhs: CGFloat) -> CGRect {
        return CGRect(x: lhs.origin.x * rhs, y: lhs.origin.y * rhs, width: lhs.size.width * rhs, height: lhs.size.height * rhs)
    }
    
}

extension UIImage {
    
    struct TransposeInfo {
        let position: CGPoint // 再按原来的位置写回去
        let originalSize: CGSize // 反向操作时要先缩放
        
        // 把2 写回1
        func writeBack(to img: UIImage, subImg: UIImage) -> UIImage {
            // 如果涂抹区域过大，原始尺寸大于模型可处理尺寸时需要放大，这时候可能会导致模糊
            let originSubImg = subImg.scaleTo(size: originalSize)
            return img.writeBack(image: originSubImg, to: position)
        }
    }
    
    func processForInpainting(mask: UIImage, cropFrame: CGRect, targetSize: CGSize) -> (img: UIImage, mask: UIImage, transpose: TransposeInfo) {
        // 计算真正的cropFrame, cropFrame的坐标体系目前是按照mask的坐标体系来的
        var realCropFrame = cropFrame
        // 比较mask和图像的宽高比
        let widthScale = mask.size.width / self.size.width
        let heightScale = mask.size.height / self.size.height

        if widthScale > heightScale {
            realCropFrame.origin.x -= CGFloat(Int((mask.size.width - self.size.width * heightScale) / 2))
            realCropFrame /= heightScale
        } else {
            realCropFrame.origin.y -= CGFloat(Int((mask.size.height - self.size.height * widthScale) / 2))
            realCropFrame /= widthScale
        }
        realCropFrame = realCropFrame.ceil()
        
        
        var newCropFrame = realCropFrame

        // 检查cropFrame是否小于targetSize
        if cropFrame.width < targetSize.width && cropFrame.height < targetSize.height {
            newCropFrame.size.width = targetSize.width
            newCropFrame.size.height = targetSize.height
            newCropFrame.origin.x = realCropFrame.origin.x - CGFloat(Int((targetSize.width - realCropFrame.size.width) / 2))
            newCropFrame.origin.y = realCropFrame.origin.y - CGFloat(Int((targetSize.height - realCropFrame.size.height) / 2))
        } else {
            // 确保宽度和高度一致
            let maxSide = max(newCropFrame.width, newCropFrame.height)
            newCropFrame.size = CGSize(width: maxSide, height: maxSide)
        }

        
        // 保证在图片的范围中开始
        let imageSize = self.size // 图片的尺寸

        if newCropFrame.origin.x < 0 {
            newCropFrame.origin.x = 0
        } else if newCropFrame.maxX > imageSize.width {
            newCropFrame.origin.x = imageSize.width - newCropFrame.width
        }

        if newCropFrame.origin.y < 0 {
            newCropFrame.origin.y = 0
        } else if newCropFrame.maxY > imageSize.height {
            newCropFrame.origin.y = imageSize.height - newCropFrame.height
        }
        newCropFrame = newCropFrame.ceil()
        // 保证在图片的范围中结束
        
        // 裁剪图像
        let croppedImage = self.crop(to: newCropFrame)

        var maskCropFrame = newCropFrame
        if widthScale > heightScale {
            maskCropFrame *= heightScale
            maskCropFrame.origin.x += CGFloat(Int((mask.size.width - self.size.width * heightScale) / 2.0))
        } else {
            maskCropFrame *= widthScale
            maskCropFrame.origin.y += CGFloat(Int((mask.size.height - self.size.height * widthScale) / 2.0))
        }
        maskCropFrame = maskCropFrame.ceil()
        let croppedMaskImage = mask.crop(to: maskCropFrame)

        // 缩放图像
        let scaledcroppedMaskImage = croppedMaskImage.scaleTo(size: targetSize)
        
        // 创建TransposeInfo结构体实例
        let transposeInfo = TransposeInfo(position: newCropFrame.origin, originalSize: newCropFrame.size)

        // 将处理后的图像写回原图
        return (img: croppedImage, mask: scaledcroppedMaskImage, transposeInfo)
    }
}





extension Array where Element == CGRect {
    func largestBoundingRect() -> CGRect {
        guard !self.isEmpty else { return .zero }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0

        for rect in self {
            minX = CGFloat.minimum(minX, rect.minX)
            minY = CGFloat.minimum(minY, rect.minY)
            maxX = CGFloat.maximum(maxX, rect.maxX)
            maxY = CGFloat.maximum(maxY, rect.maxY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

struct InpaintingPartInfo {
    /// 从原图中裁剪出来的需要修复的图像(用于undo操作)
    var croppedImages: UIImage
    /// 修复后的图像
    var inpaintedImages: UIImage
    /// 修复后的图像在原图中的位置
    var transposeInfoInOriginalImage: UIImage.TransposeInfo
}

protocol InpaintingCurrentImageProvider: AnyObject {
    
}

class InpaintingCommand: AsyncCommand {
    
    weak var imageProvider: InpaintingCurrentImageProvider?
    
    let inpantingParts: [InpaintingPartInfo]

    init(_ inpantingParts: [InpaintingPartInfo]) {
        self.inpantingParts = inpantingParts
    }
    
    func execute() async {
        
    }
    
    func undo() async {
        
    }
    
    func redo() async {
        
    }
    
    
}


