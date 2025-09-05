//
//  LiquorAppApp.swift
//  LiquorApp
//
//  Created by Pulkit Midha on 23/07/25.
//

import SwiftUI
import CouchbaseLiteSwift
import Network

// Wrapper to make P2PSyncManager accessible as an environment object
class P2PSyncManagerWrapper: ObservableObject {
    @Published var manager: P2PSyncManager?
}

@main
struct LiquorAppApp: App {
    @StateObject private var databaseManager = DatabaseManager()
    @StateObject private var p2pSyncManagerWrapper = P2PSyncManagerWrapper()
    
    init() {
        print("[P2PSync] Initializing documentation-compliant P2P sync functionality")
        
        // 🚨 CRITICAL: Trigger network permission dialog immediately at app startup
        triggerNetworkPermissionDialog()
        
        // 🚀 Initialize PlantPal-style embedding optimization
        Task {
            BuildTimeBeerEmbeddingLoader.shared.processBeerData()
            BuildTimeBeerEmbeddingLoader.shared.printPerformanceMetrics()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseManager)
                .environmentObject(p2pSyncManagerWrapper)
                .onAppear {
                    // Initialize P2P sync when the app appears
                    initializeP2PSync()
                }
        }
    }
    
    private func initializeP2PSync() {
        DispatchQueue.main.async {
            // Get the database from DatabaseManager
            if let database = databaseManager.database {
                let newP2PSyncManager = P2PSyncManager(database: database)
                
                // Store in wrapper for environment access
                p2pSyncManagerWrapper.manager = newP2PSyncManager
                
                // Start as both passive and active peer for maximum compatibility
                // This allows the device to both accept connections and discover other devices
                newP2PSyncManager.startAsPassivePeer()
                newP2PSyncManager.startAsActivePeer()
                
                print("[P2PSync] Documentation-compliant P2P sync initialized")
                print("[P2PSync] Device can now sync inventory with other devices on the same network")
                print("[P2PSync] Credentials: username=\(newP2PSyncManager.getStatus().username)")
            }
        }
    }
    
    /// 🚨 AGGRESSIVE network permission trigger - forces iOS to show the permission dialog
    private func triggerNetworkPermissionDialog() {
        print("🚨 [NetworkPermission] Starting aggressive network permission trigger...")
        
        // Method 1: UDP Broadcast (most reliable)
        triggerWithUDPBroadcast()
        
        // Method 2: Bonjour service (backup after 1 second)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.triggerWithBonjourService()
        }
        
        // Method 3: mDNS multicast (backup after 2 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.triggerWithMDNSMulticast()
        }
    }
    
    /// Method 1: UDP Broadcast to local network (triggers permission immediately)
    private func triggerWithUDPBroadcast() {
        print("🔥 [NetworkPermission] Method 1: UDP Broadcast trigger")
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        // Try multiple broadcast addresses to increase chance of triggering permission
        let broadcastAddresses = [
            "255.255.255.255",  // General broadcast
            "192.168.1.255",    // Common home network
            "10.0.0.255",       // Common office network
            "172.16.255.255"    // Common corporate network
        ]
        
        for address in broadcastAddresses {
            let connection = NWConnection(host: NWEndpoint.Host(address), port: 9999, using: params)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ [NetworkPermission] UDP connection ready to \(address) - permission likely granted")
                    connection.send(content: "LiquorApp-Permission-Test".data(using: .utf8), completion: .contentProcessed({ _ in
                        connection.cancel()
                    }))
                case .failed(let error):
                    print("⚠️ [NetworkPermission] UDP connection failed to \(address): \(error)")
                    connection.cancel()
                default:
                    break
                }
            }
            
            connection.start(queue: .main)
            
            // Cancel after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                connection.cancel()
            }
        }
    }
    
    /// Method 2: Bonjour service advertising (backup method)
    private func triggerWithBonjourService() {
        print("🔥 [NetworkPermission] Method 2: Bonjour service trigger")
        
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: "LiquorApp-\(UUID().uuidString.prefix(8))", type: "_liquorapp._tcp")
            
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ [NetworkPermission] Bonjour service ready - permission granted")
                    listener.cancel()
                case .failed(let error):
                    print("⚠️ [NetworkPermission] Bonjour service failed: \(error)")
                    listener.cancel()
                default:
                    break
                }
            }
            
            listener.newConnectionHandler = { _ in } // Required to avoid POSIX error
            listener.start(queue: .main)
            
            // Cancel after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                listener.cancel()
            }
            
        } catch {
            print("❌ [NetworkPermission] Bonjour listener creation failed: \(error)")
        }
    }
    
    /// Method 3: mDNS multicast (final backup)
    private func triggerWithMDNSMulticast() {
        print("🔥 [NetworkPermission] Method 3: mDNS multicast trigger")
        
        let connection = NWConnection(host: "224.0.0.251", port: 5353, using: .udp) // mDNS multicast address
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ [NetworkPermission] mDNS connection ready - permission granted")
                connection.send(content: Data([0x00, 0x00, 0x01, 0x00, 0x00, 0x01]), completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            case .failed(let error):
                print("⚠️ [NetworkPermission] mDNS connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        
        connection.start(queue: .main)
        
        // Cancel after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            connection.cancel()
            print("🏁 [NetworkPermission] All network permission triggers completed")
        }
    }
}
