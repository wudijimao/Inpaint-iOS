//
//  DepthImageSence.swift
//  Inpaint
//
//  Created by wudijimao on 2024/1/6.
//

import UIKit
import SceneKit
import MetalKit


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

struct MyPoint {
    let x: Float
    let y: Float
}

class DepthImageSenceViewController: UIViewController {
    
    let deepMapModelGenerator = DepthImage3DModleGenerator()
    
    let image: UIImage
    let depthData: [Float]
    
    init(image: UIImage, depthData: [Float]) {
        self.image = image
        self.depthData = depthData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let (vertices, texCoords) = deepMapModelGenerator.process(depthData: depthData)
        // 创建顶点源
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
        let vertexSource = SCNGeometrySource(data: vertexData,
                                             semantic: .vertex,
                                             vectorCount: vertices.count,
                                             usesFloatComponents: true,
                                             componentsPerVector: 3,
                                             bytesPerComponent: MemoryLayout<Float>.size,
                                             dataOffset: 0,
                                             dataStride: MemoryLayout<SCNVector3>.size)
        
        
        // 创建纹理坐标的数据源
        let texCoordData = Data(bytes: texCoords, count: texCoords.count * MemoryLayout<MyPoint>.size)
        let texCoordSource = SCNGeometrySource(data: texCoordData,
                                               semantic: .texcoord,
                                               vectorCount: texCoords.count,
                                               usesFloatComponents: true,
                                               componentsPerVector: 2,
                                               bytesPerComponent: MemoryLayout<Float>.size,
                                               dataOffset: 0,
                                               dataStride: MemoryLayout<MyPoint>.size)

        // 定义元素
        var indices = [Int32]()
        let a = 255
        let b = 255
        for i in 0..<a {
            for j in 0..<b {
                let topLeft = i * (b + 1) + j
                let topRight = topLeft + 1
                let bottomLeft = (i + 1) * (b + 1) + j
                let bottomRight = bottomLeft + 1

                // 添加第一个三角形的索引
                indices.append(contentsOf: [Int32(topLeft), Int32(bottomLeft), Int32(topRight)])

                // 添加第二个三角形的索引
                indices.append(contentsOf: [Int32(bottomLeft), Int32(bottomRight), Int32(topRight)])
                
//                // 添加第一个三角形的索引（改为顺时针）
//                indices.append(contentsOf: [Int32(topLeft), Int32(topRight), Int32(bottomLeft)])
//
//                // 添加第二个三角形的索引（改为顺时针）
//                indices.append(contentsOf: [Int32(bottomLeft), Int32(topRight), Int32(bottomRight)])

            }
        }
        // 定义元素
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: MemoryLayout<Int32>.size)


        // 创建SCNGeometry对象
        let geometry = SCNGeometry(sources: [vertexSource, texCoordSource], elements: [element])

        // 创建SceneKit视图
        let scnView = SCNView(frame: self.view.frame)
        self.view.addSubview(scnView)
        
        // 创建一个新的场景
        let scene = SCNScene()
        scnView.scene = scene
        
        // 启用默认光照
        scnView.autoenablesDefaultLighting = true
        
        // 添加一个立方体节点
        let boxGeometry = geometry
        
        // 添加贴图
        let material = SCNMaterial()
        material.diffuse.contents = self.image
//            let program = SCNProgram()
//            program.vertexFunctionName = "myVertex"
//            program.fragmentFunctionName = "myFragment"
//            material.program = program
        boxGeometry.materials = [material]

        let boxNode = SCNNode(geometry: boxGeometry)
        scene.rootNode.addChildNode(boxNode)

       

        // 添加相机节点
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
        scene.rootNode.addChildNode(cameraNode)
        
        // 允许用户控制相机
        scnView.allowsCameraControl = true

        // 显示统计数据
        scnView.showsStatistics = true

        // 设置背景色
        scnView.backgroundColor = UIColor.black
    }
}


import Metal

func createGeometryWithMetal() -> SCNGeometry {
    // 假设你已经有了一些通过Metal生成的顶点数据
    // 这里我们使用静态数据作为示例
    let vertexData: [Float] = [
        // 顶点数据: x, y, z
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0
    ]

    // 将顶点数据转换为 Data 对象
    let vertexDataSize = vertexData.count * MemoryLayout<Float>.size
    let vertexDataPointer = UnsafePointer(vertexData)
    let vertexDataAsData = Data(bytes: vertexDataPointer, count: vertexDataSize)

    // 创建 SCNGeometrySource
    let vertexSource = SCNGeometrySource(data: vertexDataAsData,
                                         semantic: .vertex,
                                         vectorCount: vertexData.count / 3,
                                         usesFloatComponents: true,
                                         componentsPerVector: 3,
                                         bytesPerComponent: MemoryLayout<Float>.size,
                                         dataOffset: 0,
                                         dataStride: MemoryLayout<Float>.stride * 3)

    // 创建 SCNGeometryElement
    let indices: [Int32] = [0, 1, 2] // 定义三角形的顶点索引
    let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
    let element = SCNGeometryElement(data: indexData,
                                     primitiveType: .triangles,
                                     primitiveCount: 1,
                                     bytesPerIndex: MemoryLayout<Int32>.size)

    // 创建 SCNGeometry
    let geometry = SCNGeometry(sources: [vertexSource], elements: [element])

    // 返回创建的几何体
    return geometry
}
