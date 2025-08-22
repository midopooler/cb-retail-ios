import SwiftUI
import CouchbaseLiteSwift

struct InventoryView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var p2pSyncManagerWrapper: P2PSyncManagerWrapper
    @State private var searchText = ""
    @State private var liquorItems: [LiquorItem] = []
    @State private var showDebugInfo = false
    @StateObject private var debugInfo = P2PDebugInfo()
    @State private var refreshTimer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var filteredItems: [LiquorItem] {
        if searchText.isEmpty {
            return liquorItems
        } else {
            return databaseManager.searchLiquor(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar with sync indicator
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search liquor...", text: $searchText)
                    
                    // P2P sync indicator with documentation-compliant status (now clickable)
                    Button(action: {
                        showDebugInfo.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                                .opacity(0.8)
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("P2P")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                                
                                Text("DEBUG")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .opacity(0.7)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Tap to show P2P debug info - Real-time inventory sync between devices")
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // P2P Debug Section (collapsible)
                if showDebugInfo {
                    InventoryP2PDebugView(debugInfo: debugInfo)
                        .transition(.opacity.combined(with: .slide))
                }
                
                // Inventory grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredItems) { item in
                            LiquorItemCard(
                                item: item,
                                onQuantityChanged: { newQuantity in
                                    databaseManager.updateQuantity(for: item.id, newQuantity: newQuantity)
                                    loadLiquorItems()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Liquor Inventory")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadLiquorItems()
            // Initialize P2P debug info
            debugInfo.p2pSyncManager = p2pSyncManagerWrapper.manager
            debugInfo.refreshData()
            // Start refresh timer for real-time updates
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                debugInfo.refreshData()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    private func loadLiquorItems() {
        liquorItems = databaseManager.getAllLiquorItems()
    }
}

// MARK: - Inventory P2P Debug View (Compact Version)

struct InventoryP2PDebugView: View {
    @ObservedObject var debugInfo: P2PDebugInfo
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with current device info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("P2P Debug Info")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Current Device: \(getCurrentDeviceName())")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    StatusBadge(
                        title: "Server",
                        isActive: debugInfo.isPassivePeerRunning,
                        port: debugInfo.listenerPort
                    )
                    
                    StatusBadge(
                        title: "Client",
                        isActive: debugInfo.isActivePeerRunning,
                        port: nil
                    )
                }
            }
            
            // Network permission status
            HStack {
                Image(systemName: debugInfo.hasNetworkPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundColor(debugInfo.hasNetworkPermission ? .green : .orange)
                
                Text(debugInfo.networkPermissionDetails)
                    .font(.caption)
                    .foregroundColor(debugInfo.hasNetworkPermission ? .green : .orange)
                
                Spacer()
            }
            
            // Devices section
            if !debugInfo.discoveredDevices.isEmpty || !debugInfo.connectedDevices.isEmpty {
                VStack(spacing: 8) {
                    // Connected devices
                    if !debugInfo.connectedDevices.isEmpty {
                        ForEach(debugInfo.connectedDevices, id: \.deviceId) { device in
                            CompactDeviceRow(device: device, isConnected: true)
                        }
                    }
                    
                    // Discovered but not connected devices
                    ForEach(debugInfo.discoveredDevices.filter { device in
                        !debugInfo.connectedDevices.contains { $0.deviceId == device.deviceId }
                    }, id: \.deviceId) { device in
                        CompactDeviceRow(device: device, isConnected: false)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.gray)
                    Text("No devices discovered")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Auth credentials
            HStack {
                Text("Auth: \(debugInfo.username) • \(String(repeating: "•", count: debugInfo.password.count))")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .font(.monospaced(.caption2)())
                
                Spacer()
                
                Text(debugInfo.serviceType)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .font(.monospaced(.caption2)())
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.3), value: debugInfo.connectedDevices.count)
        .animation(.easeInOut(duration: 0.3), value: debugInfo.discoveredDevices.count)
    }
    
    private func getCurrentDeviceName() -> String {
        #if targetEnvironment(macCatalyst)
        return "\(ProcessInfo.processInfo.hostName) (Mac)"
        #else
        return "\(UIDevice.current.name) (iOS)"
        #endif
    }
}

struct StatusBadge: View {
    let title: String
    let isActive: Bool
    let port: Int?
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(isActive ? .green : .gray)
            
            if let port = port {
                Text(":\(port)")
                    .font(.caption2)
                    .foregroundColor(isActive ? .green : .gray)
                    .font(.monospaced(.caption2)())
            } else {
                Text(isActive ? "ON" : "OFF")
                    .font(.caption2)
                    .foregroundColor(isActive ? .green : .gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

struct CompactDeviceRow: View {
    let device: DebugDevice
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(isConnected ? Color.green : device.connectionStatus.color)
                .frame(width: 8, height: 8)
            
            // Device info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(device.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(device.connectionStatus.rawValue)
                        .font(.caption2)
                        .foregroundColor(device.connectionStatus.color)
                }
                
                if let endpoint = device.endpoint {
                    Text(endpoint)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .font(.monospaced(.caption2)())
                }
                
                if let error = device.errorMessage {
                    Text("Error: \(error)")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Time indicator
            if let lastSeen = device.lastSeen {
                Text(timeAgo(from: lastSeen))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isConnected ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval/60))m"
        } else {
            return "\(Int(interval/3600))h"
        }
    }
}

#Preview {
    InventoryView()
} 