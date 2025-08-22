import Foundation
import CouchbaseLiteSwift
import UIKit

/// Manager for beer photo database operations and vector search
class BeerPhotoDatabaseManager: ObservableObject {
    static let shared = BeerPhotoDatabaseManager()
    
    private let database: Database?
    private let collectionName = "beer_photos"
    private let vectorIndexName = "beer_embeddings_index"
    
    private init() {
        // Enable the vector search extension (like PlantPal)
        do {
            try CouchbaseLiteSwift.Extension.enableVectorSearch()
            print("✅ Vector search extension enabled")
        } catch {
            print("❌ Failed to enable vector search extension: \(error.localizedDescription)")
        }
        
        // Create/open database
        do {
            self.database = try Database(name: "LiquorInventoryDB")
            print("✅ Beer photos database opened successfully")
        } catch {
            print("❌ Failed to open database: \(error.localizedDescription)")
            self.database = nil
        }
        setupBeerPhotoCollection()
    }
    
    /// Set up the beer photos collection and vector index
    private func setupBeerPhotoCollection() {
        guard let database = database else {
            print("❌ Database not available for beer photos setup")
            return
        }
        
        do {
            // Create or get the beer photos collection
            let collection = try database.createCollection(name: collectionName)
            
            // Create vector index for embeddings
            try createVectorIndex(collection: collection)
            
            print("✅ Beer photos collection and vector index set up successfully")
        } catch {
            print("❌ Failed to setup beer photos collection: \(error.localizedDescription)")
        }
    }
    
    /// Create real vector index for beer photo embeddings using Couchbase Vector Search
    private func createVectorIndex(collection: Collection) throws {
        // Check if index already exists
        let existingIndexes = try collection.indexes()
        if existingIndexes.contains(vectorIndexName) {
            print("📊 Vector index '\(vectorIndexName)' already exists")
            return
        }
        
        // Create a real vector index on the embedding field (2048 dimensions from Vision framework)
        var vectorIndexConfig = VectorIndexConfiguration(expression: "embedding", dimensions: 2048, centroids: 8)
        vectorIndexConfig.metric = .cosine // Use cosine similarity
        vectorIndexConfig.isLazy = true // Enable lazy indexing for better performance (like PlantPal)
        try collection.createIndex(withName: vectorIndexName, config: vectorIndexConfig)
        
        // Also create a value index on type field for fast filtering
        let typeIndexName = "beer_type_index"
        if !existingIndexes.contains(typeIndexName) {
            let valueIndexConfig = ValueIndexConfiguration(["type"])
            try collection.createIndex(withName: typeIndexName, config: valueIndexConfig)
        }
        
        print("✅ Created vector index '\(vectorIndexName)' with 2048 dimensions and cosine similarity")
        
        // Setup async indexing (like PlantPal)
        setupAsyncIndexing(for: collection)
    }
    
    // MARK: - Async Indexing (inspired by PlantPal)
    
    private let asyncIndexQueue = DispatchQueue(label: "BeerPhotoAsyncIndexUpdateQueue")
    
    private func setupAsyncIndexing(for collection: Collection) {
        // Immediately update the async indexes
        asyncIndexQueue.async { [weak self] in
            Task {
                do {
                    try await self?.updateAsyncIndexes(for: collection)
                } catch {
                    print("Error updating beer photo async indexes: \(error)")
                }
            }
        }
        
        // When the collection changes, update the async indexes
        collection.addChangeListener { [weak self] _ in
            self?.asyncIndexQueue.async {
                Task {
                    do {
                        try await self?.updateAsyncIndexes(for: collection)
                    } catch {
                        print("Error updating beer photo async indexes: \(error)")
                    }
                }
            }
        }
    }
    
    private func updateAsyncIndexes(for collection: Collection) async throws {
        var batchCount = 0
        
        // Check if beer photo vector index exists
        if let vectorIndex = try collection.index(withName: vectorIndexName) {
            // Update the beer photos vector index with smaller batches
            while (true) {
                guard let indexUpdater = try vectorIndex.beginUpdate(limit: 3) else {
                    break // Up to date
                }
                batchCount += 1
                
                print("🔄 Processing beer photo vector batch \(batchCount) (\(indexUpdater.count) items)...")
                
                // Generate the new embedding and set it in the index
                for i in 0..<indexUpdater.count {
                    if let data = indexUpdater.blob(at: i)?.content, let image = UIImage(data: data) {
                        if let embedding = await EmbeddingManager.shared.generateEmbedding(from: image) {
                            try indexUpdater.setVector(embedding, at: i)
                        } else {
                            print("Warning: Could not generate embedding for beer photo at position \(i)")
                        }
                    } else {
                        print("Warning: Could not process beer photo data for vector index at position \(i)")
                    }
                }
                try indexUpdater.finish()
                
                // Add a small delay between batches to prevent overwhelming the system
                Thread.sleep(forTimeInterval: 0.1)
            }
        } else {
            print("📊 Beer photo vector index not found")
        }
    }
    
    /// Save a beer photo item to the database
    /// - Parameter beerPhoto: The beer photo item to save
    /// - Returns: Success status
    func saveBeerPhoto(_ beerPhoto: BeerPhotoItem) async -> Bool {
        guard let database = database else {
            print("❌ Database not available")
            return false
        }
        
        do {
            let collection = try database.createCollection(name: collectionName)
            let document = MutableDocument(id: beerPhoto.id, data: beerPhoto.toDictionary())
            try collection.save(document: document)
            
            print("✅ Saved beer photo: \(beerPhoto.name)")
            return true
        } catch {
            print("❌ Failed to save beer photo: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get all beer photos from the database
    /// - Returns: Array of beer photo items
    func getAllBeerPhotos() async -> [BeerPhotoItem] {
        print("🚨 NEW VERSION: getAllBeerPhotos called - if you see this, the new build is running")
        guard let database = database else {
            print("❌ Database not available")
            return []
        }
        
        do {
            let collection = try database.createCollection(name: collectionName)
            
            // First, let's check if there are any documents at all
            let countQuery = QueryBuilder
                .select(SelectResult.expression(Function.count(Expression.string("*"))))
                .from(DataSource.collection(collection))
            
            let countResults = try countQuery.execute()
            let totalDocs = countResults.next()?.int(at: 0) ?? 0
            print("🔍 Total documents in collection '\(collectionName)': \(totalDocs)")
            
            // Query all beer photo documents
            let query = QueryBuilder
                .select(SelectResult.all())
                .from(DataSource.collection(collection))
                .where(Expression.property("type").equalTo(Expression.string("beer_photo")))
            
            let results = try query.execute()
            var beerPhotos: [BeerPhotoItem] = []
            var resultCount = 0
            
            for result in results {
                resultCount += 1
                print("🔍 Processing result \(resultCount)")
                
                if let dictObj = result.dictionary(forKey: collectionName) {
                    print("✅ Got dictionary object with keys: \(dictObj.keys)")
                    
                    // Convert DictionaryObject to [String: Any]
                    var dict: [String: Any] = [:]
                    for key in dictObj.keys {
                        dict[key] = dictObj.value(forKey: key)
                    }
                    
                    print("📋 Converted dict keys: \(dict.keys)")
                    print("📋 Dict type field: \(dict["type"] as? String ?? "nil")")
                    
                    if let beerPhoto = BeerPhotoItem.fromDictionary(dict) {
                        beerPhotos.append(beerPhoto)
                        print("✅ Successfully created BeerPhotoItem: \(beerPhoto.name)")
                    } else {
                        print("❌ Failed to create BeerPhotoItem from dict: \(dict)")
                    }
                } else {
                    print("❌ No dictionary found for key '\(collectionName)' in result")
                }
            }
            
            print("📊 Retrieved \(beerPhotos.count) beer photos from database")
            return beerPhotos
        } catch {
            print("❌ Failed to retrieve beer photos: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Search for similar beer photos using Couchbase Vector Search with SQL++
    /// - Parameters:
    ///   - queryEmbedding: The embedding vector to search for
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of similar beer photos with similarity scores
    func searchSimilarBeerPhotos(queryEmbedding: [Float], limit: Int = 10) async -> [(BeerPhotoItem, Float)] {
        guard let database = database else {
            print("❌ Database not available for vector search")
            return []
        }
        
        do {
            let collection = try database.createCollection(name: collectionName)
            
            // SQL++ query with VECTOR_MATCH and VECTOR_DISTANCE for real vector search
            let sql = """
                SELECT META().id, filename, name, brand, packSize, embedding, dateAdded,
                       VECTOR_DISTANCE(\(vectorIndexName)) as distance
                FROM \(collectionName)
                WHERE type = "beer_photo"
                  AND VECTOR_MATCH(\(vectorIndexName), $queryVector, \(limit))
                ORDER BY VECTOR_DISTANCE(\(vectorIndexName))
                LIMIT \(limit)
            """
            
            // Create the query
            let query = try database.createQuery(sql)
            
            // Convert Float array to ArrayObject for Couchbase parameters
            let arrayObject = MutableArrayObject()
            for value in queryEmbedding {
                arrayObject.addFloat(value)
            }
            
            // Set query parameters
            query.parameters = Parameters().setArray(arrayObject, forName: "queryVector")
            
            print("🔍 Executing vector search query with SQL++...")
            print("📊 Query: \(sql)")
            print("🎯 Vector dimension: \(queryEmbedding.count)")
            
            // Execute the query
            let results = try query.execute()
            var searchResults: [(BeerPhotoItem, Float)] = []
            
            var resultCount = 0
            for result in results {
                resultCount += 1
                print("🔍 Processing vector search result \(resultCount)")
                
                // Extract data from result
                guard let id = result.string(forKey: "id"),
                      let filename = result.string(forKey: "filename"),
                      let name = result.string(forKey: "name"),
                      let brand = result.string(forKey: "brand"),
                      let packSize = result.string(forKey: "packSize"),
                      let dateString = result.string(forKey: "dateAdded"),
                      let dateAdded = ISO8601DateFormatter().date(from: dateString) else {
                    print("❌ Failed to extract basic data from vector search result")
                    continue
                }
                
                let distance = result.double(forKey: "distance") // This returns non-optional Double
                if distance == 0.0 && result.value(forKey: "distance") == nil {
                    print("❌ Failed to extract data from vector search result")
                    continue
                }
                
                // Extract embedding
                var embedding: [Float] = []
                if let embeddingArray = result.array(forKey: "embedding") {
                    for i in 0..<embeddingArray.count {
                        embedding.append(embeddingArray.float(at: i))
                    }
                } else {
                    print("❌ Failed to extract embedding from vector search result")
                    continue
                }
                
                // Create BeerPhotoItem using proper constructor
                let beerPhoto = BeerPhotoItem(
                    filename: filename,
                    name: name,
                    brand: brand,
                    packSize: packSize,
                    embedding: embedding
                )
                
                // Convert distance to similarity score (cosine distance -> similarity)
                let similarity = Float(1.0 - distance) // Convert distance to similarity
                
                searchResults.append((beerPhoto, similarity))
                print("✅ Vector search result: \(name) - distance: \(distance), similarity: \(similarity)")
            }
            
            print("🔍 Found \(searchResults.count) similar beer photos using Couchbase Vector Search")
            
            // Apply PlantPal-style filtering for better results
            return applyPlantPalFiltering(to: searchResults)
        } catch {
            print("❌ Failed to execute Couchbase Vector Search: \(error.localizedDescription)")
            print("🚫 No fallback - Couchbase Vector Search is required for reliable results")
            return []
        }
    }
    
    /// Apply enhanced filtering for better similarity results
    private func applyPlantPalFiltering(to results: [(BeerPhotoItem, Float)]) -> [(BeerPhotoItem, Float)] {
        guard !results.isEmpty else {
            print("🤷‍♂️ No similarity results to filter")
            return []
        }
        
        // 🔧 MUCH STRICTER: Only accept very high confidence matches (>= 0.85)
        let highConfidenceMatches = results.filter { $0.1 >= 0.85 }
        
        if highConfidenceMatches.isEmpty {
            print("🤷‍♂️ No high-confidence beer photo matches found (>= 85%)")
            return []
        }
        
        // Additional filtering: require significant gap between matches to avoid ambiguity
        let bestSimilarity = highConfidenceMatches.first?.1 ?? 0.0
        
        // 🔧 TIGHTER FILTERING: Only within 90% of best match (was 70%)
        let filteredResults = highConfidenceMatches.filter { $0.1 >= bestSimilarity * 0.9 }
        
        // 🔧 ADDITIONAL CHECK: If best match is < 90%, reject all results
        if bestSimilarity < 0.90 {
            print("🤷‍♂️ Best match (\(String(format: "%.1f", bestSimilarity * 100))%) below 90% threshold - rejecting all results")
            return []
        }
        
        print("✅ Applied enhanced filtering: \(results.count) → \(filteredResults.count) results (best: \(String(format: "%.1f", bestSimilarity * 100))%)")
        return Array(filteredResults.prefix(3)) // Limit to top 3 matches
    }
    

    
    /// Delete all beer photos (for testing/reset purposes)
    func deleteAllBeerPhotos() async -> Bool {
        guard let database = database else {
            print("❌ Database not available")
            return false
        }
        
        do {
            let collection = try database.createCollection(name: collectionName)
            
            // Query all beer photo documents
            let query = QueryBuilder
                .select(SelectResult.expression(Meta.id))
                .from(DataSource.collection(collection))
                .where(Expression.property("type").equalTo(Expression.string("beer_photo")))
            
            let results = try query.execute()
            
            for result in results {
                if let docId = result.string(forKey: "id") {
                    try collection.delete(document: collection.document(id: docId)!)
                }
            }
            
            print("🗑️ Deleted all beer photos from database")
            return true
        } catch {
            print("❌ Failed to delete beer photos: \(error.localizedDescription)")
            return false
        }
    }
}