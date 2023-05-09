//
//  
//
//  Created by Volodymyr Boichentsov on 28/03/2023.
//

import Foundation
import CoreGraphics

extension CGImage {
    func color(at point: CGPoint) -> CGColor {
        guard let pixelData = self.dataProvider?.data else {
            fatalError("Could not retrieve pixel data")
        }
        
        let data = CFDataGetBytePtr(pixelData)!
        let bytesPerPixel = self.bitsPerPixel / 8
        let pixelInfo = ((Int(self.width) * Int(point.y)) + Int(point.x)) * bytesPerPixel
        
        let r = CGFloat(data[pixelInfo]) / 255.0
        let g = CGFloat(data[pixelInfo+1]) / 255.0
        let b = CGFloat(data[pixelInfo+2]) / 255.0
        let a = CGFloat(data[pixelInfo+3]) / 255.0
        
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }
}
