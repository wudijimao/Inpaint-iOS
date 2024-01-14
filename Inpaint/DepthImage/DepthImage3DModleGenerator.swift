//
//  DepthImage3DModleGenerator.swift
//  Inpaint
//
//  Created by wu miao on 2024/1/11.
//

import Foundation
import MetalKit
import SceneKit

struct MyPoint: Codable {
    let x: Float
    let y: Float
}

struct MyVector3: Codable {
    let x: Float
    let y: Float
    let z: Float
}

/// 我的模型
struct MagicModel {
    let data: MagicModelData
    let image: UIImage
    
    // 保存数据到指定的文件URL
    func saveTo(fileURL: URL) {
        data.saveTo(fileURL: fileURL.appendingPathComponent("data.mgobj"))
        try? image.pngData()?.write(to: fileURL.appendingPathComponent("texture.png"))
    }
    
    // 从指定的文件URL加载数据
    static func loadFrom(fileURL: URL) -> MagicModel? {
        guard let data = MagicModelData.loadFrom(fileURL: fileURL.appendingPathComponent("data.mgobj")) else {
            return nil
        }
        guard let image = UIImage(contentsOfFile: fileURL.appendingPathComponent("texture.png").path) else {
            return nil
        }
        return MagicModel(data: data, image: image)
    }
}

struct MagicModelData: Codable {
    let vertexList: [MyVector3]
    let texCoordList: [MyPoint]
    let indices: [UInt32]
    
    // 保存数据到指定的文件URL
    func saveTo(fileURL: URL) {
        // 将数据转换为JSON格式
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            print("Failed to encode data")
            return
        }
        // 将数据写入文件
        do {
            try data.write(to: fileURL)
            print("Data saved successfully")
        } catch {
            print("Failed to write data: \(error)")
        }
    }
    
    // 从指定的文件URL加载数据
    static func loadFrom(fileURL: URL) -> MagicModelData? {
        // 从文件读取数据
        guard let data = try? Data(contentsOf: fileURL) else {
            print("Failed to read data")
            return nil
        }
        // 将数据从JSON格式转换回结构体
        let decoder = JSONDecoder()
        guard let model = try? decoder.decode(MagicModelData.self, from: data) else {
            print("Failed to decode data")
            return nil
        }
        return model
    }
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
    
    private func _getIndices() -> [UInt32] {
        var indices = [UInt32]()
        let a = 255
        let b = 255
        for i in 0..<a {
            for j in 0..<b {
                let topLeft = i * (b + 1) + j
                let topRight = topLeft + 1
                let bottomLeft = (i + 1) * (b + 1) + j
                let bottomRight = bottomLeft + 1

                // 添加第一个三角形的索引
                indices.append(contentsOf: [UInt32(topLeft), UInt32(bottomLeft), UInt32(topRight)])

                // 添加第二个三角形的索引
                indices.append(contentsOf: [UInt32(bottomLeft), UInt32(bottomRight), UInt32(topRight)])
                
//                // 添加第一个三角形的索引（改为顺时针）
//                indices.append(contentsOf: [Int32(topLeft), Int32(topRight), Int32(bottomLeft)])
//
//                // 添加第二个三角形的索引（改为顺时针）
//                indices.append(contentsOf: [Int32(bottomLeft), Int32(topRight), Int32(bottomRight)])

            }
        }
        return indices
    }

    func process(depthData: [Float]) -> MagicModelData? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return nil
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
            return nil
        }
        

        // 设置计算管线状态和资源
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(texOutputBuffer, offset: 0, index: 1)

        // 调度计算任务
//#if os(visionOS)
        let groupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        computeEncoder.dispatchThreadgroups(groupSize, threadsPerThreadgroup: threadGroupSize)
//#else
//        let gridSize = MTLSize(width: 256, height: 256, depth: 1)
//        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
//        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
//#endif
        
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // 读取和处理结果
        let data = Data(bytesNoCopy: outputBuffer.contents(), count: dataSize * MemoryLayout<Float>.size, deallocator: .none)
        // 处理 data...
        var resultArray: [MyVector3] = []
        
        // 使用withUnsafeBytes来安全地访问Data中的字节
        data.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            // 获取指向Float的指针
            let floatPointer = bufferPointer.bindMemory(to: MyVector3.self)
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
        
        
        return MagicModelData.init(vertexList: resultArray, texCoordList: texCoordsArray, indices: _getIndices())
    }
}
