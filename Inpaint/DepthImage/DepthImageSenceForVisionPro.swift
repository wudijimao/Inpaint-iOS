//
//  DepthImageSenceForVisionPro.swift
//  Inpaint
//
//  Created by wu miao on 2024/1/11.
//

import SwiftUI
import RealityKit

struct DepthImageSenceForVisionPro: View {
    var body: some View {
#if os(visionOS)
        RealityView { content in
            let model = ModelEntity(
                mesh: .generateSphere(radius: 0.1),
                materials: [SimpleMaterial(color: .white, isMetallic: true)])
            content.add(model)
        }
#else
        Text("仅支持VisionPro")
#endif
    }
}

class DepthImageSenceForVisionProViewController: UIHostingController<DepthImageSenceForVisionPro> {
    
    let proccesser = DepthImage3DModleGenerator()
    
    public init() {
        super.init(rootView: DepthImageSenceForVisionPro())
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
