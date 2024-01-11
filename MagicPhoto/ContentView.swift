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

class MagicPhotoViewModel: ObservableObject {
    var modleGen = DepthImage3DModleGenerator()
    var deepPrediction = MiDaSImageDepthPrediction()
    
    @Published var modelData: MagicModelData? = nil
    @Published var model: ModelEntity?
    
    func process(_ image: UIImage) {
        deepPrediction.depthPrediction(image: image) { resultImage, depthData, err in
            if let depthData {
                let result = self.modleGen.process(depthData: depthData)
                self.modelData = result
                if let result {
                    var descr = MeshDescriptor(name: "tritri")
                    descr.positions = MeshBuffers.Positions(
                      [[-1, -1, 0], [1, -1, 0], [0, 1, 0]]
                    )
                    descr.primitives = .triangles([0, 1, 2])
                    
                    let generatedModel = ModelEntity(
                       mesh: try! .generate(from: [descr]),
                       materials: [SimpleMaterial(color: .orange, isMetallic: false)]
                    )
                    self.model = generatedModel
                }
            }
        }
    }
}

struct ContentView: View {

    @State var enlarge = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State var pickingImage = false
    
    @StateObject var vm = MagicPhotoViewModel()

    var body: some View {
        VStack {
            if !pickingImage {
                Group {
                    if let model = vm.model {
                        RealityView { content in
                            content.add(model)
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
                        
                    } label: {
                        Text("Pin to wall !!!")
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
