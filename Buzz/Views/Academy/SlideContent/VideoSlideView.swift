//
//  VideoSlideView.swift
//  Buzz
//
//  Video slide renderer with auto-completion on video end
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoSlideView: View {
    let url: String
    let name: String
    let onComplete: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasAutoCompleted = false
    @State private var playerObserver: NSObjectProtocol?
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading video...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Error Loading Video")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        setupPlayer()
                    }) {
                        Text("Retry")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
            } else if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func setupPlayer() {
        isLoading = true
        errorMessage = nil
        hasAutoCompleted = false
        
        // Clean up existing observer
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
        
        guard let videoUrl = URL(string: url) else {
            errorMessage = "Invalid video URL"
            isLoading = false
            return
        }
        
        print("🎥 Setting up video player for: \(name)")
        
        // Create player
        let playerItem = AVPlayerItem(url: videoUrl)
        let avPlayer = AVPlayer(playerItem: playerItem)
        
        // Observe playback end
        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            print("🎬 Video playback completed: \(name)")
            if !hasAutoCompleted {
                hasAutoCompleted = true
                onComplete()
            }
        }
        
        // Observe player status
        Task {
            // Wait for player to be ready
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                if avPlayer.status == .failed {
                    errorMessage = "Failed to load video"
                    isLoading = false
                    print("❌ Video load failed: \(avPlayer.error?.localizedDescription ?? "Unknown error")")
                } else {
                    self.player = avPlayer
                    self.isLoading = false
                    print("✅ Video player ready: \(name)")
                    
                    // Auto-play the video
                    avPlayer.play()
                }
            }
        }
    }
    
    private func cleanup() {
        print("🧹 Cleaning up video player: \(name)")
        
        // Remove observer
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
        
        // Stop and release player
        player?.pause()
        player = nil
    }
}
