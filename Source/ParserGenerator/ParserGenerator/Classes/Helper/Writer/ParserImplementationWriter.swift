//
//  ParserImplementationWriter.swift
//  ParserGenerator
//
//  Created by Egor Taflanidi on 09/11/15.
//  Copyright © 2015 Egor Taflanidi. All rights reserved.
//

import Foundation


let tab = "    "

/**
 Генератор реализации парсера.
 */
class ParserImplementationWriter {

    // MARK: - Публичные методы
    
    /**
     Сгенерировать реализацию (.swift).
     */
    internal func writeImplementation(
        klass: Klass,
        klasses: [Klass],
        projectName: String
    ) throws -> String
    {
        let properties =
            (klass.properties + self.getInheritedProperties(forKlass: klass, availableKlasses: klasses)).filter { return nil != $0.jsonKey() }

        let constructor: Method = try self.chooseConstructor(fromKlass: klass, forProperties: properties)

        let head: String = ""
            .addLine("//")
            .addLine("//  \(klass.name)Parser.swift")
            .addLine("//  \(projectName)")
            .addLine("//")
            .addLine("//  Created by Code Generator")
            .addLine("//  Copyright (c) 2015 RedMadRobot LLC. All rights reserved.")
            .addLine("//")
            .addBlankLine()
        
        let headImports: String = head
            .addLine("import Foundation")
            .addLine("import CoreParser")
            .addBlankLine()
            .addBlankLine()
        
        let headImportsParseObject: String = headImports
            .addLine("class \(klass.name)Parser: JSONParser<\(klass.name)>")
            .addLine("{")
            .addBlankLine()
            .addLine("    override init(fulfiller: Fulfiller<\(klass.name)>?)")
            .addLine("    {")
            .addLine("        super.init(fulfiller: fulfiller)")
            .addLine("    }")
            .addBlankLine()
            .addLine(tab + "override func parseObject(data: [String : JSON]) -> \(klass.name)?")
            .addLine(tab + "{")

        var guardStatements:      [String] = []
        var optionalStatements:   [String] = []
        var fillObjectStatements: [String] = []

        for property in properties {
            if property.constant {
                if property.hasDefaultValue() {
                    throw CompilerMessage(
                        filename: property.declaration.filename,
                        lineNumber: property.declaration.lineNumber,
                        message: "[ParserGenerator] Initialized constant property cannot be filled from JSON"
                    )
                }
            }

            let propertyWriter: PropertyWriter =
                PropertyWriterFactory().createWriter(
                    forProperty: property,
                    currentKlass: klass,
                    availableKlasses: klasses
                )

            if property.mandatory {
                try guardStatements += propertyWriter.parseStatements()
            } else {
                try optionalStatements += propertyWriter.parseStatements()
                
                if !constructor.arguments.contains(argument: property.name) {
                    fillObjectStatements += [ tab + tab + "object.\(property.name) = \(property.name)" ]
                }
            }
        }
        
        let allGuard: String = headImportsParseObject
            .append(guardStatements.count > 0 ? tab + tab + "guard\n" : "")
            .append(guardStatements.joinWithSeparator(",\n"))
            .append(guardStatements.count > 0 ? "\n" : "")
            .append(guardStatements.count > 0 ? tab + tab + "else { return nil }\n" : "")
            .append(guardStatements.count > 0 ? "\n" : "")

        let allOptional: String = allGuard
            .append(optionalStatements.joinWithSeparator("\n"))
            .append(optionalStatements.count > 0 ? "\n" : "")
            .append(optionalStatements.count > 0 ? "\n" : "")

        let constructorArgumentsLine: String
            = try self.writeArguments(forConstructor: constructor, usingProperties: properties)

        let fillObject: String = allOptional
            .append(tab + tab + "let object = \(klass.name)(")
            .append(constructorArgumentsLine.isEmpty ? "" : "\n")
            .append(constructorArgumentsLine)
            .append(constructorArgumentsLine.isEmpty ? ")" : "\n" + tab + tab + ")")
            .append(fillObjectStatements.count > 0 ? "\n" : "")
            .append(fillObjectStatements.joinWithSeparator("\n"))
            .append(fillObjectStatements.count > 0 ? "\n" : "")
            .addBlankLine()
            .addLine(tab + tab + "return object")
            .addLine(tab + "}")
            .addBlankLine()
            .addLine("}")
        
        return fillObject
    }
}

private extension ParserImplementationWriter {
    
    func getInheritedProperties(forKlass klass: Klass, availableKlasses: [Klass]) -> [Property]
    {
        if let parent: String = klass.parent {
            if let parentKlass = availableKlasses[parent] {
                return parentKlass.properties + self.getInheritedProperties(forKlass: parentKlass, availableKlasses: availableKlasses)
            } else if parent.containsString(".") {
                // do nothing; parent class belongs to some framework
                print(
                    CompilerMessage(
                        filename: klass.declaration.filename,
                        lineNumber: klass.declaration.lineNumber,
                        message: "[ParserGenerator] Parent class is not available in generator's scope",
                        type: .Note
                    )
                )
                return []
            } else {
                print(
                    CompilerMessage(
                        filename: klass.declaration.filename,
                        lineNumber: klass.declaration.lineNumber,
                        message: "[ParserGenerator] Parent class is not available in generator's scope",
                        type: .Warning
                    )
                )
                return []
            }
        } else {
            return []
        }
    }
    
    func chooseConstructor(
        fromKlass klass: Klass,
        forProperties properties: [Property]
    ) throws -> Method
    {
        let constructors: [Method] = klass.methods.filter { return $0.name == "init" }
        
        for constructor in constructors {
            var initsAllProperties: Bool = true
            for property in properties {
                if !constructor.arguments.contains(argument: property.name) {
                    if property.constant {
                        initsAllProperties = false
                        break
                    }
                    if property.mandatory {
                        initsAllProperties = false
                        break
                    }
                }
            }
            
            for argument in constructor.arguments {
                if !properties.contains(property: argument.name) {
                    if argument.mandatory && !argument.declaration.line.truncateFromWord("//").containsString("=") {
                        initsAllProperties = false
                    }
                }
            }
            
            if initsAllProperties {
                return constructor
            }
        }
        
        throw CompilerMessage(
            filename: klass.declaration.filename,
            lineNumber: klass.declaration.lineNumber,
            message: "[ParserGenerator] Parser could not pick an initializer method: "
                   + "don't know how to associate init arguments with class properties"
        )
    }
    
    func writeArguments(
        forConstructor constructor: Method,
        usingProperties properties: [Property]
    ) throws -> String
    {
        return try constructor.arguments.reduce("") { (initial: String, argument: Argument) -> String in
            let prefix: String
                = initial.isEmpty ? tab + tab + tab : initial + ",\n" + tab + tab + tab
    
            if properties.contains(property: argument.name) {
                return prefix + "\(argument.name): \(argument.name)"
            } else if !argument.mandatory {
                return prefix + "\(argument.name): nil"
            } else if argument.declaration.line.truncateFromWord("//").containsString("=") {
                return initial
            } else {
                throw CompilerMessage(
                    filename: argument.declaration.filename,
                    lineNumber: argument.declaration.lineNumber,
                    message: "[ParserGenerator] Parser could not use an initializer method: "
                           + "don't know how to fill \(argument.name) argument"
                )
            }
        }
    }
    
}
