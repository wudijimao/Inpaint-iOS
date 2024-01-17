//
//  UIView+Record.swift
//  Inpaint
//
//  Created by wudijimao on 2024/1/16.
//

import UIKit
import AVFoundation
import Photos

class ViewRecorder {
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var displayLink: CADisplayLink?
    private var isRecording = false
    private var startTime: CFTimeInterval?
    private var frameDuration: CMTime?
    private var lastFrameTime: CMTime = .zero
    var viewToRecord: UIView?
    var sizeToRecord: CGSize?
    

    func startRecording(view: UIView, outputURL: URL, size: CGSize, fps: Int32 = 30) {
        do {
            viewToRecord = view
            sizeToRecord = size
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height
            ]
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput!, sourcePixelBufferAttributes: nil)
            
            assetWriter?.add(assetWriterInput!)
            isRecording = true
            assetWriter?.startWriting()
            frameDuration = CMTime(value: 1, timescale: fps)
            startDisplayLink(size: size, fps: fps)
        } catch {
            print("Could not create AVAssetWriter: \(error)")
        }
    }
    
    

    private func startDisplayLink(size: CGSize, fps: Int32) {
            displayLink = CADisplayLink(target: self, selector: #selector(captureFrame))
            displayLink?.preferredFramesPerSecond = Int(fps)
            displayLink?.add(to: .main, forMode: .common)
            startTime = CACurrentMediaTime()
        }

    @objc private func captureFrame() {
        guard let assetWriter = assetWriter,
              let assetWriterInput = assetWriterInput,
              let pixelBufferAdaptor = pixelBufferAdaptor,
              let startTime = startTime,
              let frameDuration = frameDuration,
              let view = viewToRecord,
              let size = sizeToRecord,
              isRecording,
              assetWriterInput.isReadyForMoreMediaData else {
            return
        }

        let currentTime = CACurrentMediaTime() - startTime
        let presentationTime = CMTimeMakeWithSeconds(currentTime, preferredTimescale: frameDuration.timescale)
        if presentationTime <= lastFrameTime {
            return
        }
        lastFrameTime = presentationTime

        DispatchQueue.main.async {
            if let pixelBuffer = self.createPixelBuffer(from: view, size: size) {
                pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }
        }
    }
    
    private func createPixelBuffer(from view: UIView, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ]

        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, options as CFDictionary, &pixelBuffer)
        if status != kCVReturnSuccess {
            print("Error: could not create pixel buffer")
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }

        if let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
            context.draw(image.cgImage!, in: CGRect(origin: .zero, size: size))
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }


    func stopRecording() {
        isRecording = false
        displayLink?.invalidate()
        displayLink = nil
        
        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting {
            print("Recording finished")
            // Handle completion
            if let url = self.assetWriter?.outputURL {
                self.saveVideoToAlbum(url)
            }
        }
    }

    private func saveVideoToAlbum(_ videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { saved, error in
                    if saved {
                        print("Video saved to album")
                    } else {
                        print("Error saving video: \(String(describing: error))")
                    }
                }
            } else {
                print("Photos permission not granted.")
            }
        }
    }
}
