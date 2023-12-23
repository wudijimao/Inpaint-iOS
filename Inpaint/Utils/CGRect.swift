//
//  CGRect.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/23.
//

import Foundation


extension CGRect {
    func ceil() -> CGRect {
        return CGRect(x: Darwin.ceil(self.origin.x),
                      y: Darwin.ceil(self.origin.y),
                      width: Darwin.ceil(self.size.width),
                      height: Darwin.ceil(self.size.height))
    }
}
