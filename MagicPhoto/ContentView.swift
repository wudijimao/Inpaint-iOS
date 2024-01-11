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

struct ContentView: View {

    @State var enlarge = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    @State var pickingImage = false

    var body: some View {
        VStack {
            if !pickingImage {
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
            if let selectedImageData,
               let uiImage = UIImage(data: selectedImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
            }
        }
        .photosPicker(isPresented: $pickingImage,
                       selection: $selectedItem,
                       matching: .images)
         .onChange(of: selectedItem) { newItem in
             Task {
                 // Retrieve selected asset in the form of Data
                 if let data = try? await newItem?.loadTransferable(type: Data.self) {
                     selectedImageData = data
                 }
             }
         }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
