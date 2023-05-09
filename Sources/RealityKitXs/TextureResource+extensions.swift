//
//  TextureResource+extension.swift
//
//  Created by Volodymyr Boichentsov on 24/03/2023.
//

import Foundation
import Metal
import MetalKit
import RealityKit
import RealityFoundation
import CoreGraphics
import SwiftUI

// MARK: - helpers for Color

fileprivate func convertToRGBAComponents(color: CGColor) -> [UInt8] {
    let numberOfComponents = 4
    var rgba: [CGFloat] = [0.0, 0.0, 0.0, 1.0]
    
    guard let colorComponents = color.components else { return [0, 0, 0, 0] }
    for i in 0..<numberOfComponents {
        rgba[i] = colorComponents[i]
    }
    
    let convertedComponents = rgba.map { UInt8($0 * 255.0) }
    return convertedComponents
}


fileprivate func convertToCGColor(_ color: Color) -> CGColor? {
#if os(macOS)
    let uiColor = NSColor(color)
#elseif os(iOS) || os(tvOS)
    let uiColor = UIColor(color)
#endif
    return uiColor.cgColor
}

fileprivate func createCGImage(_ pixelData: [UInt8]) throws -> CGImage  {
//    let pixelData: [UInt8] = convertToRGBAComponents(color:color) // RGBA format, black color
    let bitsPerComponent = 8
    let bitsPerPixel = 32
    let bytesPerRow = 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let provider = CGDataProvider(data: NSData(bytes: pixelData, length: pixelData.count * MemoryLayout<UInt8>.size)) else {
        throw ReplaceError(message: "Failed to create CGDataProvider")
    }
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let cgImage = CGImage(width: 1, height: 1,
                                bitsPerComponent: bitsPerComponent,
                                bitsPerPixel: bitsPerPixel,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo,
                                provider: provider,
                                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
        throw ReplaceError(message: "Failed to create CGimage from CGColor")
    }
    return cgImage
}

// MARK: - implementation

struct MetalTextureError: Error {
    var message: String
}

struct ReplaceError: Error {
    var message: String
}

public extension RealityFoundation.TextureResource {
    
    static func generate(from color: CGColor, withName resourceName: String? = nil, options: TextureResource.CreateOptions) throws -> TextureResource {
        let array = convertToRGBAComponents(color: color)
        let cgImage = try createCGImage(array)
        return try TextureResource.generate(from: cgImage, withName: resourceName, options: options)
    }
    
    static func black() throws -> TextureResource {
        let image = try createCGImage([0,0,0,0])
        return try TextureResource.generate(from: image, options: .init(semantic: .color))
    }
    
    func replace(withColor color: Color) throws {
        if let color = color.cgColor {
            try replace(withColor: color)
        } else {
            if let c = convertToCGColor(color) {
                try replace(withColor: c)
            }
        }
    }
    
    func replace(withColor color: CGColor, options: TextureResource.CreateOptions = .init(semantic: .color)) throws {
        let array = convertToRGBAComponents(color: color)
        let cgImage = try createCGImage(array)
        try self.replace(withImage: cgImage, options: options)
    }
    
    func replace(withTexture texture: MTLTexture, options: TextureResource.CreateOptions) throws {
        if let cgImage = texture.cgImage {
            try self.replace(withImage: cgImage, options: options)
        } else {
            throw MetalTextureError(message: "Failed to convert metal texture to CGImage")
        }
    }
    
    var texture: MTLTexture? {
        guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
             pixelFormat: .rgba8Unorm,
             width: self.width, // Must match
             height: self.height, // Must match
             mipmapped: false)
        descriptor.usage = .shaderWrite // Required for copy
        
        guard let texture = device.makeTexture(descriptor: descriptor)
        else { return nil }
        try? self.copy(to: texture)
        return texture
    }
}
