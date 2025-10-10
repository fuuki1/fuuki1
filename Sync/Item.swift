//
//  Item.swift
//  Sync
//
//  Created by 高橋風樹 on 2025/10/10.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
