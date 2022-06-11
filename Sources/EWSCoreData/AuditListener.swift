//
//  AuditListener.swift
//  DailyFinances
//
//  Created by Eric Schramm on 5/24/22.
//  Copyright © 2022 eware. All rights reserved.
//

import Foundation
import CoreData

// because of https://stackoverflow.com/questions/11554138/unique-identifier-for-nsmanagedobject, cannot use the listener to easily capture inserts, must do this in the inits :(

fileprivate class AuditListenerSingleton {
    var auditListener: AuditListener?
    static let shared = AuditListenerSingleton()
}

public protocol CoreDataAuditable: NSManagedObject {
    //var uuid: UUID { get }
    func semanticName() -> String
}

public enum CoreDataAuditError: Error {
    case moreThanOneIdentityExistsWithUUID(UUID)
    case noRecordInEntityExistsWithUUID(String, UUID)
    case moreThanOneRecordInEntityExistsWithUUID(String, UUID)
    case failureSavingContext(String)
    case other(String)
}

enum AuditActionType: Int {
    case created
    case modified
    case deleted
    
    var title: String {
        switch self {
        case .created:
            return "created"
        case .modified:
            return "modified"
        case .deleted:
            return "deleted"
        }
    }
}

/// Purposefully not an actor because CoreData, but must run everything on the auditContext perform queue
/// This object should only be accessed via auditContext.perform action

fileprivate class AuditListenerCache {
    
    //let monitoredContext: NSManagedObjectContext
    let auditContext: NSManagedObjectContext
    private var tables: [String : EntityTable]
    private var fields: [String : EntityField]
    private var identities: [UUID : RecordIdentity]
    
    init(auditContext: NSManagedObjectContext) throws {
        self.auditContext = auditContext
        self.tables = [:]
        self.fields = [:]
        self.identities = [:]
        try auditContext.performAndWait {
            self.tables =
                try auditContext.fetch(EntityTable.fetchRequest(predicate: nil, sortDescriptors: [])).reduce([String : EntityTable]()) { (dict, entityTable) -> [String : EntityTable] in
                    var dict = dict
                    dict[entityTable.name] = entityTable
                    return dict
                }
            self.fields =
                try auditContext.fetch(EntityField.fetchRequest(predicate: nil, sortDescriptors: [])).reduce([String : EntityField]()) { (dict, entityField) -> [String : EntityField] in
                    var dict = dict
                    let key = "\(entityField.table.name)|\(entityField.name)"  // inlined here due to init self requirements
                    dict[key] = entityField
                    return dict
            }
            self.identities = [:]
        }
    }
    
    private func entityFieldKey(table: EntityTable, fieldName: String) -> String {
        return "\(table.name)|\(fieldName)"
    }
    
    func table(for tableName: String) -> EntityTable {
        if let table = tables[tableName] {
            return table
        } else {
            let table = auditContext.performAndWait {
                return EntityTable(context: self.auditContext, name: tableName)
            }
            tables[tableName] = table
            return table
        }
    }
    
    func field(for table: EntityTable, fieldName: String) -> EntityField? {
        guard !fieldName.isEmpty else { return nil }
        let key = entityFieldKey(table: table, fieldName: fieldName)
        if let field = fields[key] {
            return field
        } else {
            let field = auditContext.performAndWait {
                return EntityField(context: self.auditContext, name: fieldName, table: table)
            }
            fields[key] = field
            return field
        }
    }
    
    func identity(for objectUUID: UUID, semanticName: String) throws -> RecordIdentity {
        if let recordIdentity = identities[objectUUID] {
            if recordIdentity.semanticName != semanticName {
                recordIdentity.semanticName = semanticName
            }
            return recordIdentity
        } else {
            // this cache doesn't load all at start up so must search first
            let identity: RecordIdentity = try auditContext.performAndWait {
                let request = RecordIdentity.fetchRequest(predicate: NSPredicate(format: "objectUUID == %@", argumentArray: [objectUUID]), sortDescriptors: [])
                let founds = try! self.auditContext.fetch(request)
                switch founds.count {
                case 1:
                    return founds[0]
                case 0:
                    // need to create new record
                    let recordIdentity = RecordIdentity(context: self.auditContext, objectUUID: objectUUID, semanticName: semanticName)
                    return recordIdentity
                default:
                    throw CoreDataAuditError.moreThanOneIdentityExistsWithUUID(objectUUID)
                }
            }
            identities[objectUUID] = identity
            return identity
        }
    }
}

extension AuditEntry {
    class func entry(type: AuditActionType, tableName: String, objectUUID: UUID, semanticName: String, fieldName: String, oldValue: Any, updatedValue: Any, timeStamp: Date = Date(), context: NSManagedObjectContext?) {
        guard let listener = AuditListenerSingleton.shared.auditListener else { return }
        listener.auditContext.performAndWait {
            do {
                let context = context ?? listener.auditContext
                let cache = listener.cache
                let table = cache.table(for: tableName)
                let field = cache.field(for: table, fieldName: fieldName)
                let identity = try cache.identity(for: objectUUID, semanticName: semanticName)
                _ = AuditEntry(context: context, oldValue: "\(oldValue)", timeStamp: timeStamp, type: type, updatedValue: "\(updatedValue)", field: field, identity: identity, table: table)
            } catch {
                listener.errorHandler(error)
            }
        }
    }
}

public class AuditListener {
    
    struct PendingDeletion {
        let className: String
        let semanticName: String
        let objectUUID: UUID
    }
    
    enum ChangeKey {
        case wildCard(String)
        case exact(String)
        
        var output: String {
            switch self {
            case .wildCard(let key):
                return "*-\(key)"
            case .exact(let key):
                return key
            }
        }
    }
    
    let auditContext: NSManagedObjectContext
    private let providedErrorHandler: (Error) -> ()
    fileprivate let cache: AuditListenerCache
    
    var errorHandler: (Error) -> () = { _ in }
    
    struct ChangeRecord: Hashable {
        let entityName: String
        let uuid: UUID
    }
    
    var pendingChanges = [ChangeRecord : [String : String]]()
    //var pendingInserts = [NSManagedObjectID]()
    var pendingDeletions = [PendingDeletion]()
    
    /*let ignoreChangeKeys: Set<String> = ["Customer-cachedOrderCount",
                                         "Order-cachedProfit", "Order-cachedSale", "*-orders", "Order-orderProjects",
                                         "PriceType-projectPrices", "PriceType-projectSKUs",
                                         "Project-orderProjects", "Project-projectPrices", "Project-projectRawMaterials", "Project-projectSKUs",
                                         "RawMaterial-costQuantities", "RawMaterial-projectRawMaterials"]*/
    
    static var ignoreChangeKeys = Set<String>()
    
    init(auditContext: NSManagedObjectContext, errorHandler: @escaping (Error) -> ()) throws {
        self.auditContext = auditContext
        self.providedErrorHandler = errorHandler
        self.cache = try AuditListenerCache(auditContext: auditContext)
    }
    
    func register(entityName: String, ignoreKeys: [ChangeKey]) {
        auditContext.performAndWait {
            Self.ignoreChangeKeys = Self.ignoreChangeKeys.union(ignoreKeys.map({ "\(entityName)-\($0.output)" }))
        }
    }
    
    func start() {
        errorHandler = providedErrorHandler
        AuditListenerSingleton.shared.auditListener = self
        subscribeToChangedNotification()
        NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: .main) { [weak self] notification in
            //print("MOC saved called")
            guard let self = self else { return }
            guard let moc = notification.object as? NSManagedObjectContext, moc != self.auditContext else { return }
            //print("Calling commit changes")
            self.commitChanges(context: moc)
        }
    }
    
    func subscribeToChangedNotification() {
        //print("starting listener")
        NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: nil, queue: .main) { [weak self] notification in
            //print("MOC changed called")
            guard let self = self else { return }
            guard let moc = notification.object as? NSManagedObjectContext, moc != self.auditContext else { return }
            // check updated objects
            //print("processing objects")
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
                for object in updatedObjects {
                    guard object is CoreDataAuditable else { continue }
                    let changes = object.changedValuesForCurrentEvent()
                    var parsedChanges = [String : String]()
                    let currentIgnoreChangeKeys = Self.ignoreChangeKeys
                    for (key, value) in changes {
                        guard !currentIgnoreChangeKeys.contains("\(object.className)-\(key)") else { continue }
                        guard !currentIgnoreChangeKeys.contains("\(object.className)-*") else { continue }
                        guard !currentIgnoreChangeKeys.contains("*-\(key)") else { continue }
                        let valueString: String
                        if let managedObject = value as? CoreDataAuditable {
                            valueString = managedObject.semanticName()
                        } else if let managedObjects = value as? NSSet {
                            // NOTE: if this is the result of an object deletion, the old object is already deleted so .uniqueID() on the old object could be on an empty fault - may crash, consider filtering those relatonships in ignoreChangeKeys
                            valueString = managedObjects.filter({ $0 is CoreDataAuditable }).map({ ($0 as! CoreDataAuditable).semanticName() }).joined(separator: ";")
                        } else if value is NSNull {
                            valueString = "<null>"
                        } else {
                            valueString = "\(value)"
                        }
                        parsedChanges[key] = valueString
                    }
                    if !parsedChanges.isEmpty {
                        guard let uuid = object.value(forKey: "uuid") as? UUID else { continue }
                        let changeRecord = ChangeRecord(entityName: object.entity.name!, uuid: uuid)
                        let immutableParsedChanges = parsedChanges
                        self.noteUpdateChanges(updatedRecord: changeRecord, filteredChanges: immutableParsedChanges)
                    }
                }
            }
            
            // check deleted objects
            if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> {
                let filteredDeletions = deletedObjects.filter({ $0 is CoreDataAuditable }).map({ PendingDeletion(className: $0.className, semanticName: ($0 as! CoreDataAuditable).semanticName(), objectUUID: $0.value(forKey: "uuid") as! UUID) })
                if !filteredDeletions.isEmpty {
                    self.appendDeletedObjects(filteredDeletions: filteredDeletions)
                }
            }
            
            /*
            // check new objects
            if let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                let filteredInsertedObjectIDs = insertedObjects.filter({ $0 is CoreDataAuditable }).map({ $0.objectID })
                if !filteredInsertedObjectIDs.isEmpty {
                    Task {
                        await self.appendInsertedObjects(filteredInsertedObjectIDs: filteredInsertedObjectIDs)
                    }
                }
            }*/
        }
    }
    
    func noteUpdateChanges(updatedRecord: ChangeRecord, filteredChanges: [String : String]) {
        let objectChanges = pendingChanges[updatedRecord] ?? [String : String]()
        let keepingCurrent = objectChanges.merging(filteredChanges) { (current, _) in current }
        //print("noting change")
        pendingChanges[updatedRecord] = keepingCurrent
    }
    
    func appendDeletedObjects(filteredDeletions: [PendingDeletion]) {
        pendingDeletions.append(contentsOf: filteredDeletions)
    }
    
    /*
    func appendInsertedObjects(filteredInsertedObjectIDs: [NSManagedObjectID]) {
        pendingInserts.append(contentsOf: filteredInsertedObjectIDs)
    }*/
    
    func commitChanges(context: NSManagedObjectContext) {
        //print("changesCount now: \(pendingChanges.count)")
        do {
            context.performAndWait {
                //print("Pending changes: \(self.pendingChanges.count) - \(context)")
                for (changeRecord, changesDict) in self.pendingChanges {
                    //let object = context.object(with: objectID)
                    let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: changeRecord.entityName)
                    request.predicate = NSPredicate(format: "uuid == %@", argumentArray: [changeRecord.uuid])
                    let object: NSManagedObject
                    do {
                        let objectResults = try context.fetch(request)
                        switch objectResults.count {
                        case 1:
                            object = objectResults[0]
                        case 0:
                            errorHandler(CoreDataAuditError.noRecordInEntityExistsWithUUID(changeRecord.entityName, changeRecord.uuid))
                            continue
                        default:
                            errorHandler(CoreDataAuditError.moreThanOneRecordInEntityExistsWithUUID(changeRecord.entityName, changeRecord.uuid))
                            continue
                        }
                    } catch {
                        errorHandler(CoreDataAuditError.other("Error fetching record from uuid - \(error)"))
                        continue
                    }
                    
                    guard let object = object as? CoreDataAuditable else { continue }
                    //print(changesDict)
                    for (key, oldValueString) in changesDict {
                        let updatedValue = object.value(forKey: key)
                        let updatedValueString: String
                        if let managedObject = updatedValue as? CoreDataAuditable {
                            updatedValueString = managedObject.semanticName()
                        } else if let managedObjects = updatedValue as? NSSet {
                            updatedValueString = managedObjects.filter({ $0 is CoreDataAuditable }).map({ ($0 as! CoreDataAuditable).semanticName() }).joined(separator: ";")
                        } else {
                            if let updatedValue = updatedValue {
                                updatedValueString = "\(updatedValue)"
                            } else {
                                updatedValueString = "<null>"
                            }
                        }
                        if oldValueString != updatedValueString {
                            //self.auditContext.perform {
                            let semanticName = object.semanticName()
                            auditContext.performAndWait {
                                //print("+ adding modification record")
                                AuditEntry.entry(type: .modified, tableName: object.className, objectUUID: changeRecord.uuid, semanticName: semanticName, fieldName: key, oldValue: oldValueString, updatedValue: updatedValueString, context: self.auditContext)
                            }
                        }
                        //}
                        //AuditEntry.entry(table: "\(object.className)", recordID: object.uniqueID(), field: key, oldValue: oldValueString, updatedValue: updatedValueString, context: self.managedObjectContext)
                    }
                }
            }
            self.pendingChanges.removeAll()
            
            for deletion in self.pendingDeletions {
                auditContext.performAndWait {
                    AuditEntry.entry(type: .deleted, tableName: deletion.className, objectUUID: deletion.objectUUID, semanticName: deletion.semanticName, fieldName: "", oldValue: "", updatedValue: "", context: self.auditContext)
                }
            }
            self.pendingDeletions.removeAll()
            
            /*
             for objectID in pendingInserts {
             guard let object = managedObjectContext.object(with: objectID) as? CoreDataAuditable else { continue }
             AuditEntry.entry(table: "\(object.className)", recordID: object.uniqueID(), field: EtsyModelInserted, context: self.managedObjectContext)
             }
             pendingInserts.removeAll()
             */
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                //print("checking audit context for save")
                guard self.auditContext.hasChanges else {
                    //print("No changes detected!!!")
                    return
                }
                do {
                    //print("saving audit context")
                    try self.auditContext.save()
                } catch {
                    self.errorHandler(CoreDataAuditError.failureSavingContext("\(error)"))
                }
            }
        }
    }

    func stop() {
        auditContext.performAndWait {
            NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextObjectsDidChange, object: nil)
            NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: nil)
            pendingChanges.removeAll()
            //pendingInserts.removeAll()
            pendingDeletions.removeAll()
            AuditListenerSingleton.shared.auditListener = nil
            errorHandler = { _ in }
        }
    }
}

class ALPersistentContainer: NSPersistentContainer {
    
    static var testing: Bool = false
    static var baseURL: URL = URL(fileURLWithPath: "/dev/null")  // URL(fileURLWithPath: "/Users/\(userName)/Sync/Apps/DailyFinances/")

    static func container(baseURL: URL, testing: Bool = false) -> ALPersistentContainer {
        Self.testing = testing
        Self.baseURL = baseURL
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        
        let container = ALPersistentContainer(name: "AuditModel")
        
        if testing {
            // in-memory store
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
                if let error = error {
                    fatalError("Unresolved error \(error)")
                }
            })
            return container
        }
        
        // prevent creation of empty container (need to remove this if every starting with a fresh store)
        //guard ALPersistentContainer.storeExists() else { return container }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }
    
    static override func defaultDirectoryURL() -> URL {
        return Self.baseURL
    }
    
    static func storeExists() -> Bool {
        return FileManager.default.fileExists(atPath: defaultDirectoryURL().appendingPathComponent("Audit.sqlite").path)
    }
}
