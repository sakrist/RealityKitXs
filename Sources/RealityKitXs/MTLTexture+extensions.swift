//
//  File.swift
//  
//
//  Created by Volodymyr Boichentsov on 28/03/2023.
//

import Foundation
import Metal
import MetalKit


// MARK: - helpers for texture

fileprivate extension MTLPixelFormat {
    var isCompressed: Bool {
        switch self {
        case .rgba8Unorm, .rgba8Unorm_srgb, .bgra8Unorm, .bgra8Unorm_srgb:
            return false
        default:
            return true
        }
    }
}

fileprivate let convertCompressedTexture = """
#include <metal_stdlib>
using namespace metal;

// A compute shader that converts a compressed texture to an uncompressed RGBA texture
kernel void convertCompressedTexture(texture2d<half, access::read> inTexture [[texture(0)]],
                                     texture2d<half, access::write> outTexture [[texture(1)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    // Check if the thread is within the bounds of the output texture
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    // Read the pixel value from the input texture
    half4 pixel = inTexture.read(gid);
    
    // Write the pixel value to the output texture
    outTexture.write(pixel, gid);
}
"""

// A function that converts a MTLTexture to a CGImage
fileprivate func convertMTLTextureToCGImage(_ texture: MTLTexture) -> CGImage? {
    var texture = texture
    let device = texture.device
    // Get the device and command queue
    guard let commandQueue = device.makeCommandQueue() else {
        return nil
    }
    
    // If the texture is compressed, use a compute shader to convert it to uncompressed RGBA
    if texture.pixelFormat.isCompressed {
        
        // Create a temporary texture descriptor for the uncompressed RGBA texture
        let tempDescriptor = MTLTextureDescriptor()
        tempDescriptor.width = texture.width
        tempDescriptor.height = texture.height
        tempDescriptor.pixelFormat = .rgba8Unorm
        tempDescriptor.usage = [.shaderRead, .shaderWrite]
        
        // Create a temporary texture for the uncompressed RGBA texture
        guard let tempTexture = device.makeTexture(descriptor: tempDescriptor) else {
            return nil
        }
        
        // Create a library with the default device library
        guard let library = try? device.makeLibrary(source: convertCompressedTexture, options: nil) else {
            return nil
        }
        
        // Create a compute pipeline state with the convertCompressedTexture function
        guard let function = library.makeFunction(name: "convertCompressedTexture"),
              let pipelineState = try? device.makeComputePipelineState(function: function) else {
            return nil
        }
        
        // Create a command buffer and a compute command encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        // Set the compute pipeline state and the textures as arguments
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(texture, index: 0)
        commandEncoder.setTexture(tempTexture, index: 1)
        
        // Calculate the threadgroup size and count based on the output texture size
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(width: (tempTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                       height: (tempTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                       depth: 1)
        
        // Dispatch the compute shader with the threadgroup size and count
        commandEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        
        // End encoding and commit the command buffer
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
        // Wait for the command buffer to complete execution
        commandBuffer.waitUntilCompleted()
        
        texture = tempTexture
    }
    
    // Create a bitmap context with the output texture size and RGBA format
    guard let context = CGContext(data: nil,
                                  width: texture.width,
                                  height: texture.height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: texture.width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return nil
    }
    
    // Get the bitmap data from the context
    guard let bitmapData = context.data else {
        return nil
    }
    
    // Create a region that covers the entire output texture
    let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
    
    // Copy the output texture data to the bitmap data
    texture.getBytes(bitmapData,
                     bytesPerRow: texture.width * 4,
                     from: region,
                     mipmapLevel: 0)
    
    guard let cgImage = context.makeImage() else {
        return nil
    }
    
    return cgImage
}

extension MTLTexture {
    var cgImage: CGImage? {
        return convertMTLTextureToCGImage(self)
    }
}
