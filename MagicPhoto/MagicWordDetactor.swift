//
//  MagicWordDetactor.swift
//  Inpaint
//
//  Created by wu miao on 2024/1/14.
//

import ARKit
import UIKit
import Spatial

class MagicWordDetactor: ObservableObject {
    
    let session = ARKitSession()
    
    
    func run() {
        
        
        let worldInfo = WorldTrackingProvider()
        let transform = AffineTransform3D(translation: .init(x: 1.362751, y: 0.0, z: -0.33877257))
        let matrix = simd_float4x4(transform)
        let anchor = WorldAnchor(originFromAnchorTransform: matrix)
        
        let planeData = PlaneDetectionProvider(alignments: [.vertical])
        
        guard WorldTrackingProvider.isSupported else {
            print("Not support")
            return
        }
//        guard PlaneDetectionProvider.isSupported else {
//            print("Not support")
//            return
//        }
        
        DispatchQueue.main.async {
            Task {
                let result = await self.session.requestAuthorization(for: [.worldSensing])
                
                
                try await worldInfo.addAnchor(anchor)
                try await self.session.run([worldInfo, planeData])
                
                for await update in worldInfo.anchorUpdates {
                    switch update.event {
                    case .added, .updated:
                        // Update the app's understanding of this world anchor.
                        print("Anchor position updated.")
                    case .removed:
                        // Remove content related to this anchor.
                        print("Anchor position now unknown.")
                    }
                }
            }
        }
        
    }
}
