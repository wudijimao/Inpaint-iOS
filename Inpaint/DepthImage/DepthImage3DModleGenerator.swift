//
//  DepthImage3DModleGenerator.swift
//  Inpaint
//
//  Created by wu miao on 2024/1/11.
//

import Foundation
import MetalKit


struct MyPoint {
    let x: Float
    let y: Float
}

class DepthImage3DModleGenerator {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var computePipelineState: MTLComputePipelineState!
    var texture: MTLTexture!
    var outputBuffer: MTLBuffer!
    // 输出对应的纹理坐标
    var texOutputBuffer: MTLBuffer!

    init() {
        // 初始化Metal设备和命令队列
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device.makeCommandQueue()

        // 创建计算管线状态
        self.setupComputePipelineState()

        // 初始化计算资源
        self.setupBuffers()
    }

    func setupComputePipelineState() {
        let library = device.makeDefaultLibrary()
        let computeFunction = library?.makeFunction(name: "compute_shader_niubi")
        computePipelineState = try! device.makeComputePipelineState(function: computeFunction!)
    }
    
    let dataSize = 256 * 256 // 假设处理1024个元素

    func setupBuffers() {
        outputBuffer = device.makeBuffer(length: dataSize * MemoryLayout<SCNVector3>.size, options: [])
        texOutputBuffer = device.makeBuffer(length: dataSize * MemoryLayout<MyPoint>.size, options: [])
    }

    func process(depthData: [Float]) -> ([SCNVector3], [MyPoint]) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return ([], [])
        }
        let width = 256
        let height = 256
        // 创建纹理描述符
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        let texture = device.makeTexture(descriptor: textureDescriptor)!
        // 计算每行的字节数
        let bytesPerRow = width * MemoryLayout<Float>.size
        // 将数据直接复制到纹理
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: depthData, bytesPerRow: bytesPerRow)
        
                
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return ([], [])
        }
        

        // 设置计算管线状态和资源
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(texOutputBuffer, offset: 0, index: 1)

        // 调度计算任务
        let gridSize = MTLSize(width: 256, height: 256, depth: 1)
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // 读取和处理结果
        let data = Data(bytesNoCopy: outputBuffer.contents(), count: dataSize * MemoryLayout<Float>.size, deallocator: .none)
        // 处理 data...
        var resultArray: [SCNVector3] = []
        
        // 使用withUnsafeBytes来安全地访问Data中的字节
        data.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            // 获取指向Float的指针
            let floatPointer = bufferPointer.bindMemory(to: SCNVector3.self)
            if let baseAddress = floatPointer.baseAddress {
                // 创建一个Float数组
                let array = Array(UnsafeBufferPointer(start: baseAddress, count: dataSize))
                array.forEach { val in
                    resultArray.append(val)
                }
            }
        }
        
        // 假设你有一个名为texOutputBuffer的MTLBuffer，其中包含纹理坐标数据
        let texDataSize = dataSize/* 纹理坐标数据的数量 */

        // 读取和处理结果
        let texData = Data(bytesNoCopy: texOutputBuffer.contents(), count: texDataSize * MemoryLayout<MyPoint>.size, deallocator: .none)

        var texCoordsArray: [MyPoint] = []

        // 使用withUnsafeBytes来安全地访问Data中的字节
        texData.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            // 获取指向CGPoint的指针
            let pointPointer = bufferPointer.bindMemory(to: MyPoint.self)
            if let baseAddress = pointPointer.baseAddress {
                // 创建一个CGPoint数组
                let array = Array(UnsafeBufferPointer(start: baseAddress, count: texDataSize))
                array.forEach { point in
                    texCoordsArray.append(point)
                }
            }
        }
        
        
        return (resultArray, texCoordsArray)
    }
}
