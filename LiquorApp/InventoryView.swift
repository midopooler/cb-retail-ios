import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var searchText = ""
    @State private var liquorItems: [LiquorItem] = []
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
                    
                    // P2P sync indicator with CRDT counter info
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                            .opacity(0.7)
                        
                        Text("CRDT")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .opacity(0.8)
                    }
                    .help("P2P sync enabled with CRDT counters")
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
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
        }
    }
    
    private func loadLiquorItems() {
        liquorItems = databaseManager.getAllLiquorItems()
    }
}

#Preview {
    InventoryView()
} 