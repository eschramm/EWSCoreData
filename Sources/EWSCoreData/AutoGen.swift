//
//  File.swift
//  
//
//  Created by Eric Schramm on 6/10/22.
//

import CoreData

protocol EntityNameable: NSManagedObject {
    static func entityName() -> String
}

extension EntityNameable {
    static func entityName() -> String {
        return Self.entity().name!
    }
}

protocol DependencyCheckable {
    func checkDependencies() -> String?
}

enum ESCoreDataError : Error {
    case noRecordFoundForUUID(UUID)
    case moreThanOneRecordFoundWithUUID(UUID)
}

extension NSSet {
    var isEmpty: Bool {
        return (count == 0)
    }
}
