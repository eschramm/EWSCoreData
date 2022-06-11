//
//  File.swift
//  
//
//  Created by Eric Schramm on 6/10/22.
//

import CoreData

public protocol EntityNameable: NSManagedObject {
    static func entityName() -> String
}

public extension EntityNameable {
    static func entityName() -> String {
        return Self.entity().name!
    }
}

public protocol DependencyCheckable {
    func checkDependencies() -> String?
}

public enum ESCoreDataError : Error {
    case noRecordFoundForUUID(UUID)
    case moreThanOneRecordFoundWithUUID(UUID)
}

public extension NSSet {
    var isEmpty: Bool {
        return (count == 0)
    }
}
