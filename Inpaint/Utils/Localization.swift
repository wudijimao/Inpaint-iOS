//
//  Localization.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/23.
//

import Foundation


prefix operator *

prefix func * (key: String) -> String {
    return NSLocalizedString(key, comment: "")
}
