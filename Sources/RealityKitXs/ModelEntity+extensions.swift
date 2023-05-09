//
//  ModelEntity+extensions.swift
//  
//
//  Created by Volodymyr Boichentsov on 28/03/2023.
//

import RealityKit

extension RealityKit.Entity {
    public func generateCollisionConvex(recursive: Bool) {
        if let s = self as? ModelEntity, let model = s.model {
            s.collision = CollisionComponent(shapes: [ShapeResource.generateConvex(from: model.mesh)])
        }
        if (recursive) {
            for child in children {
                child.generateCollisionConvex(recursive: recursive)
            }
        }
    }
}

extension RealityKit.Entity {
    public func generateCollisionSphere(recursive: Bool) {
        if let s = self as? ModelEntity, let model = s.model {
            let radius = model.mesh.bounds.extents.x / 2.0
            s.collision = CollisionComponent(shapes: [ShapeResource.generateSphere(radius: radius)])
        }
        
        if (recursive) {
            for child in children {
                child.generateCollisionSphere(recursive: recursive)
            }
        }
    }
}
