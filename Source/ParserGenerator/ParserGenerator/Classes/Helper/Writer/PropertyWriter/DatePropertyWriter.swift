// 
// DatePropertyWriter.swift
// AppCode
// 
// Created by Egor Taflanidi on 05.07.16.
// Copyright © 2016 RedMadRobot LLC. All rights reserved.
//

import Foundation

class DatePropertyWriter: PropertyWriter {

    override func parseStatements() throws -> [String]
    {
        if let parser: String = self.property.parser() {
            return [
                optTab + tab + tab + "let \(self.property.name): \(self.property.type)\(optMark) = (nil != data[\"\(self.property.jsonKey()!)\"]) ? \(parser)().parse(data[\"\(self.property.jsonKey()!)\"]!.raw()).first : nil"
            ]
        }
        
        return [
            optTab + tab + tab + "let \(self.property.name): NSDate\(optMark) = (nil != data[\"\(self.property.jsonKey()!)\"]?.\(self.property.type.getSwiftyJsonSuffix())) ? NSDate(timeIntervalSince1970: data[\"\(self.property.jsonKey()!)\"]!.\(self.property.type.getSwiftyJsonSuffix())) : nil"
        ]
    }

}
