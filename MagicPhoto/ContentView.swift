//
//  ContentView.swift
//  MagicPhoto
//
//  Created by wu miao on 2024/1/11.
//

import SwiftUI
import RealityKit
import RealityKitContent
import PhotosUI
import ARKit

extension Entity {
    
    // 先生成世界
    public func makeWorld() -> Entity {
        let world = Entity()
        world.components[WorldComponent.self] = .init()
//        world.components[CollisionComponent.self] = .init(shapes: [.generateBox(width: 1, height: 1, depth: 1)])
//        self.components[CollisionComponent.self] = .init(shapes: [.generateBox(width: 1, height: 1, depth: 1)])
        world.addChild(self)
        return world
    }

    // 再把世界加到传送门上，注意两个实体都需要加到界面上
    public func makePortal() -> Entity {
        let portal = Entity()
        portal.components[ModelComponent.self] = .init(mesh: .generatePlane(width: 1,
                                                                            depth: 1,
                                                                            cornerRadius: 0.05),
                                                       materials: [PortalMaterial()])
        portal.components[PortalComponent.self] = .init(target: self)
//        portal.components[CollisionComponent.self] = .init(shapes: [.generateBox(width: 1, height: 1, depth: 1)])
        return portal
    }
}

extension URL {
    static var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}


extension MagicModel {
    func createRealityModelEntity() -> ModelEntity {
        var descr = MeshDescriptor(name: "tritri")
        var maxZ = 0.0;
        descr.positions = MeshBuffers.Positions(self.data.vertexList.map({ vec in
            maxZ = max(maxZ, Double(vec.z))
            return SIMD3<Float>.init(x: vec.x, y: vec.y, z: vec.z)
        }))
        print(maxZ)
        descr.primitives = .triangles(self.data.indices)
        descr.textureCoordinates = MeshBuffer.init(self.data.texCoordList.map({ point in
            return SIMD2<Float>.init(x: point.x, y: point.y)
        }))
        
        let textRes = try! TextureResource.generate(from: image.cgImage!, options: .init(semantic: .color))
        
        var triMat = UnlitMaterial(color: .clear)
        triMat.color = .init(texture: .init(textRes))
        
        
        let generatedModel = ModelEntity(
            mesh: try! .generate(from: [descr]),
            materials: [triMat]
        )
        return generatedModel
    }
}

extension Entity {
    // 角度 ~360 - 360
    @discardableResult
    func rotationX(angle: Float) -> Entity {
        // 设置旋转角度（以弧度为单位）
        let rotationAngle: Float = (angle / 180.0) * .pi
        let rotationAxis = SIMD3<Float>(1, 0, 0) // 绕X轴旋转
        
        var transform = self.transform
        transform.rotation = simd_quatf(angle: rotationAngle, axis: rotationAxis)

        self.transform = transform
        return self
    }
    
    // 缩放因子 > 0
    @discardableResult
    func scale(factor: Float) -> Entity {
        // 设置缩放因子
        let scaleVector = SIMD3<Float>(factor, factor, factor) // 沿所有轴缩放
        
        return self.scale(scaleVector: scaleVector)
    }
    
    @discardableResult
    func scale(scaleVector: SIMD3<Float>) -> Entity {
        var transform = self.transform
        transform.scale *= scaleVector
        // 将缩放变换乘以Entity的transform属性
        self.transform = transform
        return self
    }
    
    @discardableResult
    func setScale(scaleVector: SIMD3<Float>) -> Entity {
        var transform = self.transform
        transform.scale = scaleVector
        // 将缩放变换乘以Entity的transform属性
        self.transform = transform
        return self
    }
    
    // 平移向量
    @discardableResult
    func translate(vector: SIMD3<Float>) -> Entity {
        var transform = self.transform
        transform.translation = vector
        // 将缩放变换乘以Entity的transform属性
        self.transform = transform
        return self
    }
}


class MagicPhotoViewModel: ObservableObject {
    var modleGen = DepthImage3DModleGenerator()
    var deepPrediction = MiDaSImageDepthPrediction()
    
    @Published var modelData: MagicModelData? = nil
    @Published var model: ModelEntity?
    
    @Published var world: Entity?
    @Published var protal: Entity?
    
    static var global: MagicPhotoViewModel?
    
    let disableProtalForTest: Bool
    
    init(disableProtalForTest: Bool = false) {
        self.disableProtalForTest = disableProtalForTest
        DispatchQueue.global().async {
            self.loadFromFile()
        }
    }
    
    func loadFromFile() {
        guard let model = MagicModel.loadFrom(fileURL: URL.documentsDirectory) else {
            return
        }
        DispatchQueue.main.async {
            self.fill(with: model)
        }
    }
    
    @MainActor
    public func fill(with model: MagicModel) {
        let generatedModel = model.createRealityModelEntity()
        self.model = generatedModel
        if disableProtalForTest {
            return
        }
        self.world = generatedModel.makeWorld()
        self.world?.rotationX(angle: 0).scale(factor: 0.25).translate(vector: .init(x: 0, y: 0, z: -0.12))
        self.protal = self.world?.makePortal()
        self.protal?.rotationX(angle: 90).scale(factor: 0.4).translate(vector: .init(x: 0, y: 0, z: 0))
        // 按原图比例拉伸
        let scale = SIMD3<Float>.init(x: Float(model.image.size.width / model.image.size.height), y: 1, z: 1)
        // 如果宽度比较宽
        self.world?.scale(scaleVector: scale)
        self.protal?.scale(scaleVector: scale)
    }
    
    func process(_ image: UIImage) {
        deepPrediction.depthPrediction(image: image) { resultImage, depthData, err in
            if let depthData {
                guard let result = self.modleGen.process(depthData: depthData) else {
                    return
                }
                self.modelData = result
                let url = URL.documentsDirectory
                print("XXX:\(url)")
                let model = MagicModel.init(data: result, image: image)
                model.saveTo(fileURL: url)
                
                DispatchQueue.main.async {
                    self.fill(with: model)
                }
            }
        }
    }
}

struct MagictPhoto: View {
    var body: some View {
        RealityView { content in
            let word = await makeWorld()
            let portal = makePortal(world: word)
            content.add(word)
            content.add(portal)
        }
    }
}



struct ManipulationState {
    var isActive = false
    var scale: Float = 1.0
}

struct ImmersiveView: View {
    
    @StateObject var detector = MagicWordDetactor()
    
    @StateObject var vm = MagicPhotoViewModel()
    
    @GestureState var manipulationState = ManipulationState()
    
    var body: some View {
        if let world = vm.world, let protal = vm.protal {
            RealityView(make: { content in
                let anchor = AnchorEntity(.plane(.vertical, classification: .wall,
                                                 minimumBounds: [1, 1]), trackingMode: .continuous)
                anchor.components.set(CollisionComponent.init(shapes: [.generateBox(width: 1, height: 1, depth: 1)]))
                anchor.components.set(InputTargetComponent())
                
                
                content.add(anchor)
                world.rotationX(angle: -90)
                protal.rotationX(angle: -1)
                world.translate(vector: .init(x: 0, y: -0.12, z: 0))
                protal.translate(vector: .init(x: 0, y: 0, z: 0))
                anchor.addChild(world)
                anchor.addChild(protal)
            }, update: { content in
                content.entities.first?.setScale(scaleVector: .init(repeating: manipulationState.scale))
                print("Position: \(String(describing: content.entities.first?.position))")
            })
            .opacity(manipulationState.isActive ? 0.2 : 1.0)
            .gesture(manipulationGesture.updating($manipulationState, body: { transform, state, transaction in
                state.isActive = true
                print("XXXXX:\(transform.scale)")
                state.scale = Float(transform.scale.width)
            }))
        } else {
            Text("No")
        }
        Text("No").onAppear(perform: {
            detector.run()
        })
    }
    
    var manipulationGesture: some Gesture<AffineTransform3D> {
        DragGesture()
            .simultaneously(with: MagnifyGesture())
            .map { gesture in
                var translation = gesture.first?.translation3D ?? .zero
                translation.z = 0.0
                let scale = gesture.second?.magnification ?? 1.0
                return AffineTransform3D(scale: .init(width: scale, height: scale, depth: scale), translation: translation)
            }
    }
//        RealityView { content in
//            
//            
//            guard let scene = try? await Entity(named: "ImmersiveScene", in: realityKitContentBundle) else {
//                return
//            }
//            content.add(anchor)
////            content.add(scene)
//            // 设置旋转角度（以弧度为单位）
//            let rotationAngle: Float = .pi / -2 // 45度
//            let rotationAxis = SIMD3<Float>(1, 0, 0) // 绕Y轴旋转
//
//            // 创建一个旋转变换
//            let rotationTransform = Transform(rotation: simd_quatf(angle: rotationAngle, axis: rotationAxis))
//
//            // 将旋转变换应用于Entity的transform属性
//            scene.transform = rotationTransform
//            anchor.addChild(scene)
//        }
}

#Preview(windowStyle: .volumetric) {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}


struct ContentView: View {

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State var pickingImage = false
    
    @StateObject var vm = MagicPhotoViewModel()
    
    @Environment(\.openWindow) private var openWindow
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace


    var body: some View {
        VStack {
            if !pickingImage {
                if let world = vm.world, let protal = vm.protal {
                    RealityView (make: { content in
                        
                    }, update: { content in
                        content.entities.removeAll()
                        world.translate(vector: .init(x: 0, y: 0, z: -0.31))
                        protal.translate(vector: .init(x: 0, y: 0, z: -0.2))
                        content.add(world)
                        content.add(protal)
                    })
                    .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in
                        pickingImage.toggle()
                    })
                }
                
                HStack {
                    Button {
                        pickingImage = true
                    } label: {
                        Text("Pick your photo !!!")
                    }
                    Button {
                        Task {
                            MagicPhotoViewModel.global = self.vm
                            await openImmersiveSpace(id: "immersive")
                        }
                    } label: {
                        Text("Pin to wall !!!")
                    }
                    Button {
                        openWindow(id: "photo")
                    } label: {
                        Text("打开新window")
                    }
                }
            }
//            if let selectedImage {
//                Image(uiImage: selectedImage)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 250, height: 250)
//            }
        }
        .photosPicker(isPresented: $pickingImage,
                       selection: $selectedItem,
                       matching: .images)
        .onChange(of: selectedItem, { oldValue, newValue in
            Task {
                // Retrieve selected asset in the form of Data
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                    let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    vm.process(uiImage)
                }
            }
        })
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
