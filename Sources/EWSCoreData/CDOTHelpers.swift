//
//  CDOTHelpers.swift
//  DailyFinances
//
//  Created by Eric Schramm on 5/18/22.
//  Copyright © 2022 eware. All rights reserved.
//

import CoreData

/*
 Usage:
 
 ** Don't forget to set "Uses Data Source" on the NSComboBox in the xib! **
 
 extension BudgetItemOT: OvertimeRecord { }
 
 class BudgetItemEditVC : NSViewController {
     
     ...
     let otDatesComboDataSource: OTDateComboBoxDataSourceAndDelegate<BudgetItemOT>
     
     @IBOutlet var startDateComboBox: NSComboBox!
     
     
     init?(budgetItem: BudgetItem, coder: NSCoder) {
         ...
         self.otDatesComboDataSource = OTDateComboBoxDataSourceAndDelegate(otRecords: budgetItem.otRecordsS)
         super.init(coder: coder)
     }
     
     override func viewDidLoad() {
         super.viewDidLoad()
         ...
         otDatesComboDataSource.comboBox = startDateComboBox
         otDatesComboDataSource.onComboBoxSelection = { selectedBudgetItemOT in
             self.budgetItemOT = selectedBudgetItemOT
             self.populateViewFromModel()
             //print("Loaded \(selectedBudgetItemOT)")
         }
     }
     
     func populateViewFromModel() {
         ...
         otDatesComboDataSource.setValue(of: startDateComboBox, for: budgetItemOT)
     }
     
     @IBAction func addOT(_ sender: AnyObject) {
         budgetItemOT = BudgetItemOT(context: budgetItemOT.managedObjectContext!, amount: budgetItemOT.amount, endDate: budgetItemOT.endDate, json: budgetItemOT.json, note: budgetItemOT.note, otStartDate: Date(), repeatingStyle: budgetItemOT.repeatingStyle, skipAddToGroup: budgetItemOT.skipAddToGroup, skipDates: budgetItemOT.skipDates, startDate: budgetItemOT.startDate, budgetItem: budgetItemOT.budgetItem, fromAccount: budgetItemOT.fromAccount, toAccount: budgetItemOT.toAccount)
         otDatesComboDataSource.rebuildDataSource(otRecords: budgetItemOT.baseRecord.otRecordsS)
         populateViewFromModel()
     }
     
     @IBAction func removeOT(_ sender: AnyObject) {
         let budgetItem = budgetItemOT.baseRecord
         if otDatesComboDataSource.removeOT(parentRecord: budgetItem) {
             budgetItemOT = budgetItem.latestOT()
             populateViewFromModel()
         }
     }
 }
 
 */

#if canImport(AppKit)
import AppKit

public class OTDateComboBoxDataSourceAndDelegate<T : OvertimeRecord> : NSObject, NSComboBoxDataSource, NSComboBoxDelegate {
    
    public unowned var comboBox: NSComboBox? {
        didSet {
            comboBox?.delegate = self
            comboBox?.dataSource = self
        }
    }
    unowned var currentOT: T?
    public var onComboBoxSelection: (T) -> () = { _ in }
    var map = [String : T]()
    var otDateStrings = [String]()
    
    let dateFormatter: DateFormatter = {
       let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
    
    public init(otRecords: Set<T>) {
        super.init()
        rebuildDataSource(otRecords: otRecords)
    }
    
    public func numberOfItems(in comboBox: NSComboBox) -> Int {
        return otDateStrings.count
    }
    
    public func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        for otDateString in otDateStrings {
            if otDateString.lowercased().hasPrefix(string.lowercased()) {
                return otDateString
            }
        }
        return nil
    }
    
    public func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return otDateStrings[index]
    }
    
    var otRecord: T? {
        guard let comboBox = comboBox else {
            return nil
        }

        if comboBox.indexOfSelectedItem == -1 {
            if let otRecord = map[comboBox.stringValue] {
                return otRecord
            } else {
                return nil
            }
        } else {
            return map[otDateStrings[comboBox.indexOfSelectedItem]]
        }
    }
    
    func formattedOTStartDate(otRecord: T, omitTime: Bool = false) -> String {
        if otRecord.otStartDate > Date.distantPast {
            return omitTime ? otRecord.otStartDate.formatted(date: .numeric, time: .omitted) : dateFormatter.string(from: otRecord.otStartDate)
        } else {
            return "first value"
        }
    }
    
    public func setValue(of comboBox: NSComboBox, for otRecord: T) {
        currentOT = otRecord
        comboBox.stringValue = formattedOTStartDate(otRecord: otRecord)
    }
    
    public func rebuildDataSource(otRecords: Set<T>) {
        let otRecordsSorted = otRecords.sorted(by: { $0.otStartDate < $1.otStartDate })
        otDateStrings = otRecordsSorted.map({ formattedOTStartDate(otRecord: $0) })
        map = otRecordsSorted.reduce([String: T]()) { (dict, otRecord) -> [String : T] in
            var dict = dict
            dict[formattedOTStartDate(otRecord: otRecord)] = otRecord
            return dict
        }
    }
    
    public func comboBoxSelectionIsChanging(_ notification: Notification) {
        processComboBoxChange(notification)
    }
    
    public func comboBoxWillDismiss(_ notification: Notification) {
        processComboBoxChange(notification)
    }
    
    public func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let comboBox = notification.object as? NSComboBox else { return }
        comboBox.delegate = nil
        processComboBoxChange(notification)
        comboBox.delegate = self
    }
    
    func processComboBoxChange(_ notification: Notification) {
        if let otRecord = otRecord {
            currentOT = otRecord
            onComboBoxSelection(otRecord)
        }
    }
    
    public func controlTextDidEndEditing(_ obj: Notification) {
        guard let comboBox = comboBox, let currentOT = currentOT else {
            return
        }

        if let textField = obj.object as? NSTextField {
            if textField.stringValue == comboBox.stringValue, comboBox.delegate != nil {
                if let updatedDate = dateFormatter.date(from: comboBox.stringValue), currentOT.otStartDate != updatedDate {
                    //print("Updating date of record to \(updatedDate)")
                    currentOT.otStartDate = updatedDate
                    rebuildDataSource(otRecords: Set(map.values))
                } else {
                    comboBox.stringValue = dateFormatter.string(from: currentOT.otStartDate)
                }
            }
        }
    }
    
    public func removeOT(parentRecord: T.BaseRecord) -> Bool {
        guard parentRecord.otRecordsS.count > 1 else {
            NSAlert.simpleAlert(title: "Cannot Delete Last Record", subtitle: "There is only one over-time record left for this BudgetItem. It cannot be deleted.").runModal()
            return false
        }
        guard let otToDelete = otRecord else {
            return false
        }
        guard let moc = otToDelete.managedObjectContext else {
            return false
        }
        
        let alert = NSAlert()
        alert.messageText = "Are you sure?"
        alert.informativeText = "This will delete this over-time record and cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        
        guard alert.runModal() == .alertSecondButtonReturn else {
            return false
        }
        
        moc.delete(otToDelete)
        do {
            try moc.save()
        } catch {
            NSAlert.esAlert(error: error).runModal()
            return false
        }
        
        guard let updatedRecords = parentRecord.otRecordsS as? Set<T> else {
            fatalError("should never happen")
        }
        rebuildDataSource(otRecords: updatedRecords)
        return true
    }
}
#endif

//https://stackoverflow.com/questions/64468530/make-a-swift-protocol-conform-to-hashable

/*
 Example for latestOT():
 
 func latestOT() -> BudgetItemOT {
     let sortedOTs = otRecordsS.sorted(by: { $0.otStartDate < $1.otStartDate })
     return sortedOTs.last ?? BudgetItemOT(context: managedObjectContext!, amount: 0, endDate: nil, json: RootJSON.empty, note: "", otStartDate: Date.distantPast, repeatingStyle: .yearly, skipDates: [], startDate: nil, baseRecord: self)
 }
 
 */

public enum OTError: Error {
    case allOTRecordsHaveStartDatesGreaterThanDate(date: Date)
}

public protocol OvertimedRecord: NSManagedObject {
    associatedtype OTRecord : OvertimeRecord
    var otRecordsS: Set<OTRecord> { get }
    func latestOT() -> OTRecord
}

public protocol OvertimeRecord: NSManagedObject {
    associatedtype BaseRecord: OvertimedRecord
    var baseRecord: BaseRecord { get }
    var otStartDate: Date { get set }
}

public extension OvertimedRecord {
    func ot(for date: Date) throws -> OTRecord {
        switch otRecordsS.count {
        case 0:
            return latestOT()
        case 1:
            // NOTE: no date check in this case for efficiency
            return otRecordsS.randomElement()!
        default:
            let sortedOTs = otRecordsS.sorted(by: { $0.otStartDate < $1.otStartDate })
            let sortedStartDates = sortedOTs.map({ $0.otStartDate })
            let nextIndex = date.nextIndex(for: sortedStartDates)
            if nextIndex == sortedStartDates.count {
                // interval is after last OT date
                return sortedOTs.last!
            } else if nextIndex == 0 {
                throw OTError.allOTRecordsHaveStartDatesGreaterThanDate(date: date)
            } else {
                return sortedOTs[nextIndex - 1]
            }
        }
    }
    
    func ots(for interval: DateInterval) throws -> [OTRecord] {
        switch otRecordsS.count {
        case 0:
            return [latestOT()]
        case 1:
            // NOTE: no date check in this case for efficiency
            return [otRecordsS.randomElement()!]
        default:
            let sortedOTs = otRecordsS.sorted(by: { $0.otStartDate < $1.otStartDate })
            let sortedStartDates = sortedOTs.map({ $0.otStartDate })
            let nextIndex = interval.start.nextIndex(for: sortedStartDates)
            if nextIndex == sortedStartDates.count {
                // interval is after last OT date
                return [sortedOTs.last!]
            } else if nextIndex == 0 {
                throw OTError.allOTRecordsHaveStartDatesGreaterThanDate(date: interval.start)
            } else {
                // simple check to see if interval.end is also before nextIndex
                if interval.end < sortedStartDates[nextIndex] {
                    return [sortedOTs[nextIndex - 1]]
                } else {
                    // spans intervals
                    let endNextIndex = interval.end.nextIndex(for: sortedStartDates)
                    if endNextIndex == sortedStartDates.count {
                        // interval is after last OT date
                        return Array(sortedOTs[(nextIndex - 1)...])
                    } else {
                        return Array(sortedOTs[(nextIndex - 1)..<endNextIndex])
                    }
                }
            }
        }
    }
}

public extension OvertimeRecord {
    var interval: DateInterval {
        switch baseRecord.otRecordsS.count {
        case 0:
            fatalError("should never happen")
        case 1:
            return DateInterval(start: otStartDate, end: Date.distantFuture)
        default:
            let sortedOTs = baseRecord.otRecordsS.sorted(by: { $0.otStartDate < $1.otStartDate })
            let sortedStartDates = sortedOTs.map({ $0.otStartDate })
            let nextIndex = otStartDate.nextIndex(for: sortedStartDates)
            if nextIndex == sortedStartDates.count {
                // interval is after last OT date
                return DateInterval(start: otStartDate, end: Date.distantFuture)
            } else if nextIndex == 0 {
                fatalError("should never happen")
            } else {
                return DateInterval(start: otStartDate, end: sortedOTs[nextIndex].otStartDate)
            }
        }
    }
}

extension Date {
    func nextIndex(for sortedDates: [Date]) -> Int {
        //binary search
        var left = 0
        var right = sortedDates.count - 1
        var middle = -1
        var foundIndex = -1
        
        while left <= right {
            middle = (left + right) / 2
            if sortedDates[middle] < self {
                left = middle + 1
            } else if sortedDates[middle] > self {
                right = middle - 1
            } else {
                foundIndex = middle
                break
            }
        }
        
        if foundIndex == -1 {  // not found, right should be just last index before nextDate
            foundIndex = right
        }
        return foundIndex + 1
    }
}

extension NSAlert {
    static func esAlert(error: Error) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = error.localizedDescription
        alert.informativeText = "\(error)"
        return alert
    }
    
    static func simpleAlert(title: String, subtitle: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = subtitle
        return alert
    }
}
