//
//  LiquorAppApp.swift
//  LiquorApp
//
//  Created by Pulkit Midha on 23/07/25.
//

import SwiftUI
import CouchbaseLiteSwift

@main
struct LiquorAppApp: App {
    @StateObject private var databaseManager = DatabaseManager()
    @State private var syncApp: LiquorSyncApp?
    
    init() {
        // Note: Vector search will be enabled when dependency issues are resolved
        print("[LiquorSync] Initializing basic P2P sync functionality")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseManager)
                .onAppear {
                    // Initialize P2P sync when the app appears
                    initializeSync()
                }
        }
    }
    
    private func initializeSync() {
        // Initialize P2P sync with credentials (if available)
        LiquorSyncCredentials.async { identity, ca in
            DispatchQueue.main.async {
                // Get the database from DatabaseManager
                if let database = databaseManager.database {
                    let newSyncApp = LiquorSyncApp(database: database, identity: identity, ca: ca)
                    newSyncApp.start()
                    syncApp = newSyncApp
                    
                    if identity != nil && ca != nil {
                        print("[LiquorSync] P2P sync initialized with certificates")
                    } else {
                        print("[LiquorSync] Basic sync initialized (no certificates found)")
                    }
                }
            }
        }
    }
}
