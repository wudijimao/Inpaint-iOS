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

extension Entity {
    
    // 先生成世界
    public func makeWorld() -> Entity {
        let world = Entity()
        world.components[WorldComponent.self] = .init()
        world.addChild(self)
        return world
    }

    // 再把世界加到传送门上，注意两个实体都需要加到界面上
    public func makePortal() -> Entity {
        let portal = Entity()
        portal.components[ModelComponent.self] = .init(mesh: .generatePlane(width: 1,
                                                                            depth: 1,
                                                                            cornerRadius: 0.5),
                                                       materials: [PortalMaterial()])
        portal.components[PortalComponent.self] = .init(target: self)
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

class MagicPhotoViewModel: ObservableObject {
    var modleGen = DepthImage3DModleGenerator()
    var deepPrediction = MiDaSImageDepthPrediction()
    
    @Published var modelData: MagicModelData? = nil
    @Published var model: ModelEntity?
    
    @Published var world: Entity?
    @Published var protal: Entity?
    
    init() {
        DispatchQueue.global().async {
            self.loadFromFile()
        }
    }
    
    func loadFromFile() {
        guard let model = MagicModel.loadFrom(fileURL: URL.documentsDirectory) else {
            return
        }
        DispatchQueue.main.async {
            let generatedModel = model.createRealityModelEntity()
            self.model = generatedModel
            self.world = generatedModel.makeWorld()
            self.protal = self.world?.makePortal()
        }
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
                
                let generatedModel = model.createRealityModelEntity()
                self.model = generatedModel
                self.world = generatedModel.makeWorld()
                self.protal = self.world?.makePortal()
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

struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(.plane(.vertical, classification: .wall,
                                             minimumBounds: [1, 1]))
            
            guard let scene = try? await Entity(named: "ImmersiveScene", in: realityKitContentBundle) else {
                return
            }
            content.add(anchor)
//            content.add(scene)
            // 设置旋转角度（以弧度为单位）
            let rotationAngle: Float = .pi / -2 // 45度
            let rotationAxis = SIMD3<Float>(1, 0, 0) // 绕Y轴旋转

            // 创建一个旋转变换
            let rotationTransform = Transform(rotation: simd_quatf(angle: rotationAngle, axis: rotationAxis))

            // 将旋转变换应用于Entity的transform属性
            scene.transform = rotationTransform
            anchor.addChild(scene)
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}


struct ContentView: View {

    @State var enlarge = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State var pickingImage = false
    
    @StateObject var vm = MagicPhotoViewModel()
    
    @Environment(\.openWindow) private var openWindow
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace


    var body: some View {
        VStack {
            if !pickingImage {
                Group {
                    if let world = vm.world, let protal = vm.protal {
                        RealityView { content in
                            // 设置旋转角度（以弧度为单位）
                            let rotationAngle: Float = .pi / 2 // 45度
                            let rotationAxis = SIMD3<Float>(1, 0, 0) // 绕Y轴旋转

                            // 创建一个旋转变换
                            let rotationTransform = Transform(rotation: simd_quatf(angle: rotationAngle, axis: rotationAxis))

                            // 将旋转变换应用于Entity的transform属性
                            protal.transform = rotationTransform
                            content.add(world)
                            content.add(protal)
                        }
                    } else {
                        RealityView { content in
                            // Add the initial RealityKit content
                            if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                                content.add(scene)
                            }
                        } update: { content in
                            // Update the RealityKit content when SwiftUI state changes
                            if let scene = content.entities.first {
                                let uniformScale: Float = enlarge ? 1.4 : 1.0
                                scene.transform.scale = [uniformScale, uniformScale, uniformScale]
                            }
                        }
                    }
                }
                .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in
                    enlarge.toggle()
                    pickingImage.toggle()
                })
                
                HStack {
                    Button {
                        pickingImage = true
                    } label: {
                        Text("Pick your photo !!!")
                    }
                    Button {
                        Task {
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
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
            }
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
