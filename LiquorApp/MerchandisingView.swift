import SwiftUI
import AVFoundation

struct MerchandisingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var isProcessing = false
    @State private var similarityResults: [SimilarityResult] = []
    @State private var countingResults: [CountingResult] = []
    @State private var capturedImage: UIImage?
    @State private var analysisImage: UIImage? // Image with bounding boxes
    @State private var showCounting = false // Toggle between similarity and counting modes
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                        
                        Text("Merchandising Scanner")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Button("") {}
                            .opacity(0)
                            .padding()
                    }
                    .background(Color.black.opacity(0.7))
                    
                    // Camera preview
                    ZStack {
                        CameraPreviewView(session: cameraManager.session)
                            .ignoresSafeArea()
                        
                        // Viewfinder overlay
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 280, height: 200)
                            .overlay(
                                VStack {
                                    HStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                        Spacer()
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                    }
                                    Spacer()
                                    HStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                        Spacer()
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(8)
                            )
                        
                        // Instructions
                        VStack {
                            Spacer()
                            Text("Align planogram within the frame")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                .padding(.bottom, 120)
                        }
                    }
                    
                    // Bottom controls
                    VStack(spacing: 20) {
                        // Processing indicator with detailed feedback
                        if isProcessing {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Analyzing image...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Processing multiple objects may take a moment")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 60)
                        } else if !similarityResults.isEmpty || !countingResults.isEmpty {
                            // Results display with toggle
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Toggle buttons
                                    HStack {
                                        Button(action: { showCounting = false }) {
                                            Text("Similarity")
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(showCounting ? Color.gray.opacity(0.3) : Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                        
                                        Button(action: { showCounting = true }) {
                                            Text("Count Packs")
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(showCounting ? Color.blue : Color.gray.opacity(0.3))
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                    }
                                    
                                    if showCounting {
                                        // Counting results (always show when counting tab is selected)
                                        Text("Beer Pack Count:")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            if !countingResults.isEmpty {
                                                let totalPacks = countingResults.reduce(0) { $0 + $1.count }
                                                Text("Total: \(totalPacks) beer packs detected")
                                                    .font(.subheadline)
                                                    .foregroundColor(.green)
                                                    .padding(.bottom, 4)
                                                
                                                ForEach(countingResults) { result in
                                                    HStack {
                                                        VStack(alignment: .leading) {
                                                            Text(result.beerType)
                                                                .font(.subheadline)
                                                                .foregroundColor(.white)
                                                            Text("\(result.brand) • \(result.count) packs")
                                                                .font(.caption)
                                                                .foregroundColor(.gray)
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        VStack {
                                                            Text("\(result.count)")
                                                                .font(.title2)
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.blue)
                                                            
                                                            Text("\(Int(result.confidence))%")
                                                                .font(.caption)
                                                                .foregroundColor(.gray)
                                                        }
                                                    }
                                                    .padding(.vertical, 4)
                                                }
                                            } else {
                                                // Placeholder for empty counting results
                                                Text("Total: 0 beer packs detected")
                                                    .font(.subheadline)
                                                    .foregroundColor(.orange)
                                                    .padding(.bottom, 4)
                                                
                                                HStack {
                                                    VStack(alignment: .leading) {
                                                        Text("No beer packs detected")
                                                            .font(.subheadline)
                                                            .foregroundColor(.gray)
                                                        Text("Try better lighting or closer angle")
                                                            .font(.caption)
                                                            .foregroundColor(.gray.opacity(0.7))
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    VStack {
                                                        Text("0")
                                                            .font(.title2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.gray)
                                                        
                                                        Text("0%")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    } else if !showCounting && !similarityResults.isEmpty {
                                        // Similarity results
                                        Text("Detection Results:")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        ForEach(similarityResults) { result in
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(result.filename)
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                    Text("\(Int(result.confidence))% match")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                
                                                Spacer()
                                                
                                                if result.confidence > 80 {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                } else if result.confidence > 60 {
                                                    Image(systemName: "questionmark.circle.fill")
                                                        .foregroundColor(.yellow)
                                                } else {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(maxHeight: 150)
                        } else {
                            Spacer()
                                .frame(height: 40)
                        }
                        
                        // Capture button
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                capturePhoto()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 80, height: 80)
                                    
                                    Circle()
                                        .stroke(Color.black, lineWidth: 3)
                                        .frame(width: 70, height: 70)
                                    
                                    if isProcessing {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.title)
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            .disabled(isProcessing)
                            .scaleEffect(isProcessing ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isProcessing)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Ensure camera session starts when view appears
            print("🎬 MerchandisingView: View appeared, starting camera...")
            cameraManager.checkCameraPermissions()
            
            // Small delay to ensure session is set up before starting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if cameraManager.hasPermission && !cameraManager.isSessionRunning {
                    cameraManager.startSession()
                }
            }
        }
        .onDisappear {
            print("🛑 MerchandisingView: View disappeared, stopping camera...")
            cameraManager.stopSession()
        }
        .alert("Camera Access", isPresented: $cameraManager.showAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Camera access is required to use the merchandising scanner.")
        }
    }
    
    private func capturePhoto() {
        guard !isProcessing else { return }
        
        isProcessing = true
        similarityResults = []
        
        cameraManager.capturePhoto { image in
            DispatchQueue.main.async {
                self.capturedImage = image
                
                // Process image using real AI-powered recognition
                if let capturedImage = image {
                    Task {
                        await self.processImageWithAI(capturedImage)
                    }
                } else {
                    print("❌ Failed to capture image")
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// Process captured image with real AI-powered recognition
    private func processImageWithAI(_ image: UIImage) async {
        print("🧠 Starting AI processing of captured image...")
        
        // Ensure beer photos have been processed first
        await ensureBeerPhotosProcessed()
        
        // Run both similarity analysis and counting analysis in parallel
        async let similarityAnalysis = performSimilarityAnalysis(image)
        async let countingAnalysis = performCountingAnalysis(image)
        
        let (similarityResults, countingResults) = await (similarityAnalysis, countingAnalysis)
        
        await MainActor.run {
            self.similarityResults = similarityResults
            self.countingResults = countingResults
            self.isProcessing = false
            
            print("🎯 AI processing complete!")
            print("📊 Similarity matches: \(similarityResults.count)")
            print("🔢 Counting results: \(countingResults.count)")
            
            // Log results for debugging
            for result in similarityResults {
                print("📊 Match: \(result.filename) - \(String(format: "%.1f", result.confidence))%")
            }
            
            for result in countingResults {
                print("🔢 Count: \(result.beerType) - \(result.count) packs (\(String(format: "%.1f", result.confidence))%)")
            }
        }
    }
    
    /// Perform similarity analysis (existing functionality)
    private func performSimilarityAnalysis(_ image: UIImage) async -> [SimilarityResult] {
        // Generate embedding for the captured image
        guard let capturedEmbedding = await EmbeddingManager.shared.generateEmbedding(from: image) else {
            print("❌ Failed to generate embedding for captured image (likely rejected due to poor quality)")
            return []
        }
        
        print("✅ Generated embedding for captured image (\(capturedEmbedding.count) dimensions)")
        
        // Search for similar beer photos using Couchbase vector search
        let searchResults = await BeerPhotoDatabaseManager.shared.searchSimilarBeerPhotos(
            queryEmbedding: capturedEmbedding,
            limit: 5
        )
        
        // Convert results to UI format with percentage scores
        return searchResults.map { (beerPhoto, similarity) in
            let confidencePercentage = similarity * 100
            return SimilarityResult(
                id: beerPhoto.id,
                filename: beerPhoto.name, // Use the descriptive name instead of filename
                confidence: Double(confidencePercentage)
            )
        }
    }
    
    /// Perform counting analysis (new functionality)
    private func performCountingAnalysis(_ image: UIImage) async -> [CountingResult] {
        guard let planogramAnalysis = await BeerCountingManager.shared.analyzePlanogramWithCounting(image) else {
            print("❌ Failed to perform counting analysis")
            return []
        }
        
        // Store the analysis image for potential display
        await MainActor.run {
            self.analysisImage = planogramAnalysis.analysisImage
        }
        
        // Convert to UI format
        return planogramAnalysis.beerCounts.map { result in
            CountingResult(
                beerType: result.beerType,
                brand: result.brand,
                count: result.count,
                confidence: Double(result.confidence * 100)
            )
        }
    }
    
    /// Ensure beer photos have been processed and stored in the database
    private func ensureBeerPhotosProcessed() async {
        // Force reset and reprocess to ensure we're using the new beer photo names
        // (Black Horizon Ale, Aether Brew, etc. instead of Heineken, Budweiser, etc.)
        print("🔄 Forcing reset and reprocess to use updated beer photo names...")
        await BeerPhotoProcessor.shared.resetBeerPhotos()
        await BeerPhotoProcessor.shared.processAllBeerPhotos()
    }
    
    // Temporary simulation of results (kept for fallback)
    private func simulateResults() {
        similarityResults = [
            SimilarityResult(id: "1", filename: "Heineken 6-Pack", confidence: 92.5),
            SimilarityResult(id: "2", filename: "Budweiser 12-Pack", confidence: 78.3),
            SimilarityResult(id: "3", filename: "Corona Extra 6-Pack", confidence: 45.2)
        ]
    }
}

// Camera preview UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Store the preview layer as a property of the view for easy access
        view.layer.addSublayer(previewLayer)
        
        // Set initial frame (will be updated in updateUIView)
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        print("✅ CameraPreviewView: Created preview layer for session")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer frame whenever the view bounds change
        DispatchQueue.main.async {
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
                print("📐 CameraPreviewView: Updated preview layer frame to \(uiView.bounds)")
            }
        }
    }
}

// Data model for similarity results
struct SimilarityResult: Identifiable {
    let id: String
    let filename: String
    let confidence: Double
}

struct CountingResult: Identifiable {
    let id = UUID()
    let beerType: String
    let brand: String
    let count: Int
    let confidence: Double
}

#Preview {
    MerchandisingView()
}