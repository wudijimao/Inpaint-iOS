//
//  MagicPhotoApp.swift
//  MagicPhoto
//
//  Created by wu miao on 2024/1/11.
//

import SwiftUI
import RealityKit
import RealityKitContent

//@main
//struct MagicPhotoApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }.windowStyle(.plain)
//        
//        WindowGroup(id: "photo") {
//            MagictPhoto()
//        }.windowStyle(.volumetric)
//        
//    }
//}

@MainActor
public func makeWorld() async -> Entity {
    let world = Entity()
    world.components[WorldComponent.self] = .init()
    let child = try! await Entity(named: "Scene", in: realityKitContentBundle)
    world.addChild(child)
    
    return world
}

public func makePortal(world: Entity) -> Entity {
    let portal = Entity()
    
    portal.components[ModelComponent.self] = .init(mesh: .generatePlane(width: 1,
                                                                        depth: 1,
                                                                        cornerRadius: 0.5),
                                                   materials: [PortalMaterial()])
    portal.components[PortalComponent.self] = .init(target: world)
    return portal
}

@main
struct MagicPhotoApp: App {

    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some SwiftUI.Scene {
        ImmersiveSpace {
            RealityView { content in
                let anchor = AnchorEntity(.plane(.vertical, classification: .wall,
                                                 minimumBounds: [1, 1]))
                content.add(anchor)
                let word = await makeWorld()
                let portal = makePortal(world: word)
                anchor.addChild(word)
                anchor.addChild(portal)
            }
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}
