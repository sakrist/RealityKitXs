import XCTest
import RealityKit
@testable import RealityKitXs

#if os(macOS)
extension NSImage {
    var cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif


func createDepthTexture() -> MTLTexture {
    // Create a depth texture with some dummy data
    let device = MTLCreateSystemDefaultDevice()!
    let descriptor = MTLTextureDescriptor()
    descriptor.pixelFormat = .depth32Float
    descriptor.width = 256
    descriptor.height = 256
    descriptor.usage = [.shaderRead, .shaderWrite]
    let depthTexture = device.makeTexture(descriptor: descriptor)!
    let bytesPerRow = 256 * 4
    let data = Data(repeating: 0xFF, count: bytesPerRow * 256)
    data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
        depthTexture.replace(region: MTLRegionMake2D(0, 0, 256, 256),
                             mipmapLevel: 0,
                             withBytes: bytes.baseAddress!,
                             bytesPerRow: bytesPerRow)
    }
    return depthTexture
}

func renderEntity(entity: ModelEntity, completion: @escaping (_ image: ARView.Image?) -> Void) {
    let arView = ARView(frame: .init(x: 0, y: 0, width: 100, height: 100))

    let originAnchor = AnchorEntity(world: .zero)
    originAnchor.addChild(entity)
    arView.scene.anchors.append(originAnchor)
        
    // Render offscreen and get the resulting image
    arView.snapshot(saveToHDR: false, completion: completion)
}

final class TextureResourceTests: XCTestCase {
    
    // this test is warm up test
    func testRenderNoMaterial() {
        // Create your scene and add it to the arView
        let entity = ModelEntity.init(mesh: .generateBox(size: SIMD3<Float>.init(repeating: 1)))

        let expectation = XCTestExpectation(description: "Snapshot taken")
        var cgImage:CGImage?
        
        // Render offscreen and get the resulting image
        renderEntity(entity: entity) { image in
            cgImage = image?.cgImage
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        
        let color = cgImage?.color(at: .init(x: 0, y: 0))
        XCTAssertTrue(color == CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        
        let component = 0.64313725490196083
        let color2Expected = CGColor(red: component, green: 0.0, blue: component, alpha: 1.0)
        let color2 = cgImage?.color(at: .init(x: 48, y: 48))
        XCTAssertTrue(color2 == color2Expected, "Expected default material on the cube when material is not set.")
    }
    
    func testDepthTextureConversion() {
             
        var material = PhysicallyBasedMaterial()
        
        guard let url = Bundle.module.url(forResource: "test.jpeg", withExtension: nil) else {
            XCTFail("Failed to load texture resource")
            return
        }
        if let textureResource = try? TextureResource.load(contentsOf: url) {
            let texture = PhysicallyBasedMaterial.Texture(textureResource)
            material.baseColor.texture = .init(texture)
        }
        
        let entity = ModelEntity.init(mesh: .generateBox(size: SIMD3<Float>.init(repeating: 1)),
                                      materials: [material])
        
        let expectation = XCTestExpectation(description: "Snapshot taken")
        var cgImage:CGImage?
        
        // Render offscreen and get the resulting image
        renderEntity(entity: entity) { image in
            cgImage = image?.cgImage
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        let color2Expected = CGColor(red: 0.50980392156862742, green: 0.082352941176470587, blue: 0.51372549019607838, alpha: 1.0)
        let color2 = cgImage?.color(at: .init(x: 48, y: 48))
        XCTAssertTrue(color2 == color2Expected, "test.jpeg texture failed to apply")
        
        let depthTexture = createDepthTexture()
        do {
            try material.baseColor.texture?.resource.replace(withTexture: depthTexture, options: .init(semantic: .color))
        } catch {
            XCTAssertTrue(false, "Faield to replace texture in TextureResource")
        }
        
        let expectation2 = XCTestExpectation(description: "Snapshot taken 2")
        
        let entity2 = ModelEntity.init(mesh: .generateBox(size: SIMD3<Float>.init(repeating: 1)),
                                      materials: [material])
        
        // Render offscreen and get the resulting image
        renderEntity(entity: entity2) { image in
            cgImage = image?.cgImage
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5.0)
        
        let component = 0.082352941176470587
        let colorExpected = CGColor(red: component, green: component, blue: component, alpha: 1.0)
        let color = cgImage?.color(at: .init(x: 48, y: 48))
        XCTAssertTrue(color == colorExpected, "Depth texture failed to apply")
    }
    
    
    func testGetTexture() {
        
        let colorRed = CGColor.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        guard let resource = try? TextureResource.generate(from: colorRed, options: .init(semantic: .color)) else {
            XCTFail("Failed to generate texture resource from color")
            return
        }
        
        var cgImage:CGImage?
        if let texture =  resource.texture,
           let image = texture.cgImage {
            cgImage = image
        }
        
        XCTAssertTrue(cgImage?.color(at: .zero) == colorRed, "Failed compare, color must be red")
        
        var material = PhysicallyBasedMaterial()
        material.baseColor.texture = .init(resource)
        let depthTexture = createDepthTexture()
        do {
            try material.baseColor.texture?.resource.replace(withTexture: depthTexture, options: .init(semantic: .color))
        } catch {
            XCTAssertTrue(false, "Faield to replace texture in TextureResource")
        }
        
        if let texture =  resource.texture,
           let image = texture.cgImage {
            cgImage = image
        }
        
        let colorx = cgImage?.color(at: .zero)
        let black = CGColor.init(red: 0, green: 0, blue: 0, alpha: 1)
        XCTAssertTrue(colorx == black, "Failed compare, color must be black")
        
    }
}
