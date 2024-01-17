//
//  DepthImageSence.swift
//  Inpaint
//
//  Created by wudijimao on 2024/1/6.
//

import UIKit
import SceneKit
import CoreMotion
import SnapKit


//extension SCNQuaternion {
//    // 根据旋转轴和角度初始化四元数
//    init(axis: SCNVector3, angle: Float) {
//        let halfAngle = angle / 2
//        let sinHalfAngle = sin(halfAngle)
//        self.x = axis.x * sinHalfAngle
//        self.y = axis.y * sinHalfAngle
//        self.z = axis.z * sinHalfAngle
//        self.w = cos(halfAngle)
//    }
//}

func * (left: SCNQuaternion, right: SCNQuaternion) -> SCNQuaternion {
    return SCNQuaternion(
        x: left.w * right.x + left.x * right.w + left.y * right.z - left.z * right.y,
        y: left.w * right.y - left.x * right.z + left.y * right.w + left.z * right.x,
        z: left.w * right.z + left.x * right.y - left.y * right.x + left.z * right.w,
        w: left.w * right.w - left.x * right.x - left.y * right.y - left.z * right.z)
}

func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
}



class DepthImageSenceViewController: UIViewController {
    
    let deepMapModelGenerator = DepthImage3DModleGenerator()
    
    lazy var motionManager: CMMotionManager = CMMotionManager()
    lazy var cameraNode = SCNNode()
    
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
    
    func setupMotion() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak self] (motion, error) in
                guard let motion = motion, let self = self else { return }

                // 获取旋转角度
                let rotation = motion.attitude
                let roll = rotation.roll  // 横滚角
                let pitch = rotation.pitch // 俯仰角
                let yaw = rotation.yaw    // 偏航角

                // 在这里可以使用这些旋转角度
                self.updateCameraRotation(attitude: motion.attitude)
            }
        }
    }
    

        var lastPitch: Float?
        var lastRoll: Float?

        func updateCameraRotation(attitude: CMAttitude) {
            // 获取当前的俯仰和滚转角
            let currentPitch = Float(attitude.pitch)
            let currentRoll = Float(attitude.roll)

            // 如果是第一次调用，初始化lastPitch和lastRoll
            if lastPitch == nil || lastRoll == nil {
                lastPitch = currentPitch
                lastRoll = currentRoll
                return
            }

            // 计算角度变化
            let deltaPitch = currentPitch - lastPitch!
            let deltaRoll = currentRoll - lastRoll!

            // 更新上次的俯仰和滚转角
            lastPitch = currentPitch
            lastRoll = currentRoll

            // 根据角度变化更新摄像机的位置
            // 注意：这里的更新方式取决于您的具体需求
            // 例如，可以将角度变化映射到摄像机的位移上
            cameraNode.position.x += deltaRoll // 这里的映射规则可以根据需要调整
            cameraNode.position.y += deltaPitch
        }


    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scale = image.size.height / image.size.width
        // 检查是否是横屏
        let isLandscape = self.view.frame.width > self.view.frame.height
        // 根据屏幕方向计算缩放比例
        var scaleForLandscape: CGFloat = 1.0
        
        if isLandscape {
            if image.size.width > image.size.height {
                // 宽度变宽
                scaleForLandscape = self.view.frame.width / self.view.frame.height
            } else {
                // 高度变低
                scaleForLandscape = 1.0
            }
        }
        boxNode?.scale = SCNVector3(scaleForLandscape, scaleForLandscape * scale, 1.0)
        
        
    }
    
    var boxNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let saveButton = UIBarButtonItem(title: *"save_to_photo_lib", style: .plain, target: self, action: #selector(onSave))
        self.navigationItem.rightBarButtonItem = saveButton
        
        guard let result = deepMapModelGenerator.process(depthData: depthData) else { return }
        let (vertices, texCoords) = (result.vertexList, result.texCoordList)
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

        let scale = image.size.height / image.size.width
        // 创建SceneKit视图
        let scnView = SCNView(frame: self.view.frame)
        
        
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 20.0
        contentView.layer.cornerCurve = .continuous
        
        self.view.addSubview(contentView)
        contentView.addSubview(scnView)
        
        contentView.snp.makeConstraints { make in
            make.width.height.lessThanOrEqualToSuperview()
            make.center.equalToSuperview()
            make.width.equalTo(contentView.snp.height).dividedBy(scale)
            make.width.height.equalToSuperview().priority(.high)
        }
        scnView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(self.view)
        }
        
        // 创建一个新的场景
        let scene = SCNScene()
        scnView.scene = scene
        
        // 启用默认光照
        scnView.autoenablesDefaultLighting = false
        // 移除场景中的所有光源
        scene.rootNode.enumerateChildNodes { (node, _) in
            if node.light != nil {
                node.removeFromParentNode()
            }
        }
        
        // 添加一个立方体节点
        let boxGeometry = geometry
        
        // 添加贴图
        let material = SCNMaterial()
        material.diffuse.contents = self.image
        material.lightingModel = .constant // 关闭光照效果

        boxGeometry.materials = [material]

        let boxNode = SCNNode(geometry: boxGeometry)
        self.boxNode = boxNode
        
        viewDidLayoutSubviews()
        
        scene.rootNode.addChildNode(boxNode)

       
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 4)
        // 设置摄像机始终朝向(0,0,0)
        let constraint = SCNLookAtConstraint(target: boxNode)
        cameraNode.constraints = [constraint]
        
        scene.rootNode.addChildNode(cameraNode)
        
        // 允许用户控制相机
        scnView.allowsCameraControl = true

        #if DEBUG
        // 显示统计数据
        scnView.showsStatistics = true
        #endif

        // 设置背景色
        scnView.backgroundColor = UIColor.systemBackground
        
        setupMotion()
    }
    lazy var contentView = UIView()
    lazy var recoder = ViewRecorder()
    
    @objc func onSave() {
        let url = URL.documentsDirectory.appendingPathComponent("temp.mov")
        recoder.startRecording(view: contentView, outputURL: url, size: view.frame.size)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.recoder.stopRecording()
        }
    }
    
    
}
