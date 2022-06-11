//
//  AuditCoreDataAutoGen.swift
//  DailyFinances
//
//  Created by Eric Schramm on 5/24/22.
//  Copyright © 2022 eware. All rights reserved.
//

import Foundation
import CoreData

@objc(AuditEntry)  // Auto-generated via LogParser-CoreDataClassGenerator at 2022-05-26 10:02:59
public class AuditEntry: NSManagedObject, EntityNameable {

    @NSManaged var oldValue: String
    @NSManaged var timeStamp: Date
    @NSManaged private var typeInt: Int
    var type: AuditActionType {
        get { return AuditActionType(rawValue: typeInt)! }
        set { typeInt = newValue.rawValue }
    }
    @NSManaged var updatedValue: String
    @NSManaged var field: EntityField?
    @NSManaged var identity: RecordIdentity
    @NSManaged var table: EntityTable

    convenience init(context: NSManagedObjectContext, oldValue: String, timeStamp: Date, type: AuditActionType, updatedValue: String, field: EntityField?, identity: RecordIdentity, table: EntityTable) {
        self.init(entity: AuditEntry.entity(), insertInto: context)
        self.oldValue = oldValue
        self.timeStamp = timeStamp
        self.type = type
        self.updatedValue = updatedValue
        self.field = field
        self.identity = identity
        self.table = table
    }

    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

    class func fetchRequest(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> NSFetchRequest<AuditEntry> {
        let request: NSFetchRequest<AuditEntry> = NSFetchRequest(entityName: "AuditEntry")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }
}

extension AuditEntry: DependencyCheckable {
    public func checkDependencies() -> String? {
        var dependencies = [String]()
        if field != nil {
            dependencies.append("Attached EntityField")
        }
        if dependencies.isEmpty {
            return nil
        } else {
            return "This AuditEntry has the following dependencies:\n" + dependencies.joined(separator: "\n")
        }
    }
}

@objc(EntityField)  // Auto-generated via LogParser-CoreDataClassGenerator at 2022-05-26 10:02:59
public class EntityField: NSManagedObject, EntityNameable {

    @NSManaged var name: String
    @NSManaged var auditEntries: NSSet
    var auditEntriesS: Set<AuditEntry> {
        return auditEntries as! Set<AuditEntry>
    }
    @NSManaged var table: EntityTable

    convenience init(context: NSManagedObjectContext, name: String, table: EntityTable) {
        self.init(entity: EntityField.entity(), insertInto: context)
        self.name = name
        self.auditEntries = auditEntries
        self.table = table
    }

    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

    class func fetchRequest(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> NSFetchRequest<EntityField> {
        let request: NSFetchRequest<EntityField> = NSFetchRequest(entityName: "EntityField")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }
}

extension EntityField: DependencyCheckable {
    public func checkDependencies() -> String? {
        var dependencies = [String]()
        if !auditEntries.isEmpty {
            dependencies.append("\(auditEntries.count) AuditEntrys")
        }
        if dependencies.isEmpty {
            return nil
        } else {
            return "This EntityField has the following dependencies:\n" + dependencies.joined(separator: "\n")
        }
    }
}

@objc(EntityTable)  // Auto-generated via LogParser-CoreDataClassGenerator at 2022-05-26 10:02:59
public class EntityTable: NSManagedObject, EntityNameable {

    @NSManaged var name: String
    @NSManaged var auditEntries: NSSet
    var auditEntriesS: Set<AuditEntry> {
        return auditEntries as! Set<AuditEntry>
    }
    @NSManaged var fields: NSSet
    var fieldsS: Set<EntityField> {
        return fields as! Set<EntityField>
    }

    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(entity: EntityTable.entity(), insertInto: context)
        self.name = name
        self.auditEntries = auditEntries
        self.fields = fields
    }

    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

    class func fetchRequest(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> NSFetchRequest<EntityTable> {
        let request: NSFetchRequest<EntityTable> = NSFetchRequest(entityName: "EntityTable")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }
}

extension EntityTable: DependencyCheckable {
    public func checkDependencies() -> String? {
        var dependencies = [String]()
        if !auditEntries.isEmpty {
            dependencies.append("\(auditEntries.count) AuditEntrys")
        }
        if !fields.isEmpty {
            dependencies.append("\(fields.count) EntityFields")
        }
        if dependencies.isEmpty {
            return nil
        } else {
            return "This EntityTable has the following dependencies:\n" + dependencies.joined(separator: "\n")
        }
    }
}

@objc(RecordIdentity)  // Auto-generated via LogParser-CoreDataClassGenerator at 2022-05-26 10:02:59
public class RecordIdentity: NSManagedObject, EntityNameable {

    @NSManaged var objectUUID: UUID
    @NSManaged var semanticName: String
    @NSManaged var auditEntries: NSSet
    var auditEntriesS: Set<AuditEntry> {
        return auditEntries as! Set<AuditEntry>
    }

    convenience init(context: NSManagedObjectContext, objectUUID: UUID, semanticName: String) {
        self.init(entity: RecordIdentity.entity(), insertInto: context)
        self.objectUUID = objectUUID
        self.semanticName = semanticName
        self.auditEntries = auditEntries
    }

    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

    class func fetchRequest(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> NSFetchRequest<RecordIdentity> {
        let request: NSFetchRequest<RecordIdentity> = NSFetchRequest(entityName: "RecordIdentity")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }
}

extension RecordIdentity: DependencyCheckable {
    public func checkDependencies() -> String? {
        var dependencies = [String]()
        if !auditEntries.isEmpty {
            dependencies.append("\(auditEntries.count) AuditEntrys")
        }
        if dependencies.isEmpty {
            return nil
        } else {
            return "This RecordIdentity has the following dependencies:\n" + dependencies.joined(separator: "\n")
        }
    }
}
