//
//  Inpainting.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/13.
//

import UIKit
import CoreML


protocol ImageInpenting {
    // 异步
    func inpent(image: UIImage, mask: UIImage, inpaintingRects:[CGRect], completion: @escaping (UIImage?, NSError?) -> Void)
}

class LaMaImageInpenting: ImageInpenting {

    let workQueue = DispatchQueue.init(label: "LaMaImageInpenting")
    
    lazy var config: MLModelConfiguration = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        return config
    }()
    
    var lama: LaMaFP16_512?
    
    public init() {
        self.preload()
    }
    
    func inpent(image: UIImage, mask: UIImage, inpaintingRects:[CGRect], completion: @escaping (UIImage?, NSError?) -> Void) {
        workQueue.async {
            guard let lama = self.lama else { return }
            let rect = inpaintingRects.largestBoundingRect()
            let imgs = image.processForInpainting(mask: mask, cropFrame: rect, targetSize: .init(width: kImageSize, height: kImageSize))
            guard let imgBuffer = imgs.img.buffer else {
                completion(nil, nil)
                return
            }
            guard let maskBuffer = imgs.mask.grayBuffer else {
                completion(nil, nil)
                return
            }
            do {
                let result = try lama.prediction(image: imgBuffer, mask: maskBuffer)
                guard let outImage = result.output.uiImage else {
                    completion(nil, nil)
                    return
                }
                let finalImage = imgs.transpose.writeBack(to: image, subImg: outImage)
                DispatchQueue.main.async {
                    completion(finalImage, nil)
                }
            } catch(let e) {
                print(e)
                completion(nil, e as NSError)
            }
            
        }
    }

    func preload() {
        workQueue.async {
            do {
                self.lama = try LaMaFP16_512.init(configuration: self.config)
            } catch(let e) {
                print(e)
            }
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

let kImageSize = 512

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

extension UIImage {
    func crop(to rect: CGRect) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let croppedImage = renderer.image { (context) in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            
            let drawRect = CGRect(x: -rect.origin.x, y: -rect.origin.y, width: self.size.width, height: self.size.height)
            self.draw(in: drawRect)
        }
        return croppedImage
    }
}

extension UIImage {
    
    func scaleToLimit(size limitSize: CGSize) -> UIImage {
        let widthRatio  = limitSize.width  / self.size.width
        let heightRatio = limitSize.height / self.size.height
        let scaleFactor = min(widthRatio, heightRatio)
        guard scaleFactor < 1.0 else {
            return self
        }
        let scaledSize = CGSize(width: self.size.width * scaleFactor, height: self.size.height * scaleFactor)
        return scaleTo(size: scaledSize)
    }
    
    func scaleTo(size targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let newImage = renderer.image { (context) in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return newImage
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
        // 保证在图片的范围中结束

        // 裁剪图像
        let croppedImage = self.crop(to: newCropFrame)

        var maskCropFrame = newCropFrame
        if widthScale > heightScale {
            maskCropFrame *= heightScale
            maskCropFrame.origin.x += CGFloat(Int((mask.size.width - self.size.width * heightScale) / 2))
        } else {
            maskCropFrame *= widthScale
            maskCropFrame.origin.y += CGFloat(Int((mask.size.height - self.size.height * widthScale) / 2))
        }

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
