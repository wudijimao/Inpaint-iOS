//
//  UIImage.swift
//  Inpaint
//
//  Created by wu miao on 2024/1/11.
//

import UIKit
import CoreML


extension CVPixelBuffer {
    var uiImage: UIImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage
    }
}

extension UIImage {
//    import VideoToolbox
    
    func buffer(ofSize size: Int) -> CVPixelBuffer?  {
        let feature = try! MLFeatureValue.init(cgImage: self.cgImage!, pixelsWide: size, pixelsHigh: size, pixelFormatType: kCVPixelFormatType_32ARGB)
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
        guard self.size != targetSize else {
            // 尺寸一致的时候不放大
            return self
        }
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1  // 设置scale为1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let newImage = renderer.image { (context) in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return newImage
    }
}
