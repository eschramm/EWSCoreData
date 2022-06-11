//
//  AuditViewer.swift
//  DailyFinances
//
//  Created by Eric Schramm on 5/25/22.
//  Copyright © 2022 eware. All rights reserved.
//

import SwiftUI

extension AuditEntry : Identifiable {
    
}

struct AuditViewer: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: AuditEntry.entity(), sortDescriptors: [NSSortDescriptor(key: "timeStamp", ascending: false)])
    var modifications: FetchedResults<AuditEntry>
    
    var body: some View {
        Table(modifications) {
            TableColumn("Date") { modification in
                Text(modification.timeStamp.formatted(date: .numeric, time: .standard))
            }
            TableColumn("Action") { modification in
                Text(modification.type.title)
            }
            TableColumn("Table", value: \.table.name)
            TableColumn("Field") { modification in
                Text(modification.field?.name ?? "--")
            }
            TableColumn("Record", value: \.identity.semanticName)
            TableColumn("From", value: \.oldValue)
            TableColumn("To", value: \.updatedValue)
        }
    }
}

struct AuditViewer_Previews: PreviewProvider {
    static let context = ALPersistentContainer.container(baseURL: URL(fileURLWithPath: "/Users/ericschramm/Sync/Apps/DailyFinances/")).viewContext
    
    static var previews: some View {
        AuditViewer().environment(\.managedObjectContext, Self.context)
    }
}
