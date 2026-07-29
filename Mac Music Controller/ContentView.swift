//
//  ContentView.swift
//  Mac Controller
//
//  Created by Rishi Jansari on 29/07/2026.
//

import SwiftUI

enum PlaybackState {
    case playing, paused
}

enum VolumeMode: String {
    case system = "System Volume"
    case music = "Music App Volume"
}

struct TrackInfo: Codable {
    var status: String
    var title: String
    var artist: String
    var duration: Double
    var position: Double
    var isPlaying: Bool
    var isFavourite: Bool
    
    // This maps your Swift camelCase properties to Python's snake_case JSON keys
    enum CodingKeys: String, CodingKey {
        case status
        case title
        case artist
        case duration
        case position
        case isPlaying = "is_playing"
        case isFavourite = "is_favorite"
    }
}

struct ContentView: View {
    @State private var statusMessage = "Ready"
    @State private var playbackState: PlaybackState = .paused
    @State private var volumeMode: VolumeMode = .system
    @State private var volume: Double = 10.0
    @State private var currentTrack: TrackInfo?
    @State private var artworkID = UUID()
    @State private var artworkImage: UIImage? = nil
    @State private var extractedColors: [Color] = Array(repeating: .blue.opacity(0.5), count: 9)
    
    @State private var previousTrigger = 0
    @State private var nextTrigger = 0
    
    private let macURL = "####"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.blue.opacity(0.25)
//                FluidBackgroundView(colors: extractedColors)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Group {
                        if let artworkImage = artworkImage {
                            Image(uiImage: artworkImage)
                                .resizable()
                                .shadow(color: .black, radius: 20, x: 5, y: 5)
                        } else {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.5))
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 100))
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                        }
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    HStack(spacing: 30) {
                        VStack(alignment: .leading) {
                            AutoScrollingText(
                                text: currentTrack?.title ?? "Not Playing",
                                font: .title,
                                fontWeight: .semibold,
                                foregroundColor: .primary
                            )
                            
                            AutoScrollingText(
                                text: currentTrack?.artist ?? "Tap Refresh",
                                font: .title2,
                                fontWeight: .light,
                                foregroundColor: .secondary
                            )
                        }
                        
                        Button {
                            sendFavouriteRequest()
                        } label: {
                            let isFav = currentTrack?.isFavourite ?? false
                            Image(systemName: isFav ? "star.fill" : "star")
                                .font(.title)
                        }
                        .buttonStyle(.plain)
                        .contentTransition(.symbolEffect(.replace))
                        
                        Menu {
                            Button {
                                withAnimation {
                                    volumeMode = (volumeMode == .system) ? .music : .system
                                }
                                fetchCurrentVolume()
                            } label: {
                                Label(
                                    volumeMode == .system ? "Switch to Music Volume" : "Switch to System Volume",
                                    systemImage: volumeMode == .system ? "music.note" : "speaker.wave.2"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top)
                    
                    VStack {
                        ProgressView(value: currentTrack?.position ?? 0, total: currentTrack?.duration ?? 1)
                            .tint(.secondary.opacity(0.7))
                        
                        HStack {
                            Text(formatTime(currentTrack?.position ?? 0))
                                .font(.caption)
                            Spacer()
                            Text("-\(formatTime((currentTrack?.duration ?? 0) - (currentTrack?.position ?? 0)))")
                                .font(.caption)
                        }
                    }
                    
                    HStack(spacing: 60) {
                        Button {
                            previousTrigger += 1
                            sendRequest(endpoint: "/music/previous", method: "POST")
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 36))
                                .symbolEffect(.bounce, value: previousTrigger)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            if playbackState == .paused {
                                sendRequest(endpoint: "/music/play", method: "POST")
                                playbackState = .playing
                            } else {
                                sendRequest(endpoint: "/music/pause", method: "POST")
                                playbackState = .paused
                            }
                        } label: {
                            Image(systemName: playbackState == .paused ? "play.fill" : "pause.fill")
                                .font(.system(size: 50))
                        }
                        .buttonStyle(.plain)
                        .contentTransition(.symbolEffect(.replace))
                        
                        Button {
                            nextTrigger += 1
                            sendRequest(endpoint: "/music/next", method: "POST")
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 36))
                                .symbolEffect(.bounce, value: nextTrigger)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 20)
                    
                    HStack {
                        Image(systemName: volumeMode == .system ? "speaker.fill" : "music.note")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $volume, in: 0...100, step: 1.0) { isEditing in
                            if !isEditing {
                                sendVolumeRequest(val: Int(volume))
                            }
                        }
                        .tint(.secondary.opacity(0.7))
                        
                        Image(systemName: volumeMode == .system ? "speaker.wave.3.fill" : "music.quarternote.3")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Status: \(statusMessage)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical)
                }
                .padding(30)
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Mac Music Controller")
                        .font(.system(.title2, design: .serif, weight: .bold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        fetchStatus()
                    }
                }
            }
        }
        .onAppear {
            fetchStatus()
        }
    }
    
    private func formatTime(_ totalSeconds: Double) -> String {
        let roundedSeconds = Int(round(totalSeconds))
        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Fetches the artwork image and updates the master color palette
    private func fetchArtworkColors() {
        guard let url = URL(string: "\(macURL)/music/artwork?t=\(Date().timeIntervalSince1970)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            
            // Extract top 5 dominant colors from artwork
            let dominant = uiImage.extractDominantColors(count: 5)
            
            DispatchQueue.main.async {
                self.artworkImage = uiImage
                withAnimation(.easeInOut(duration: 2.0)) {
                    self.extractedColors = dominant
                }
            }
        }.resume()
    }
    
    // Function to handle generic POST requests
    private func sendRequest(endpoint: String, method: String) {
        guard let url = URL(string: "\(macURL)\(endpoint)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    statusMessage = "Error: \(error.localizedDescription)"
                } else {
                    statusMessage = "Success: \(endpoint)"
                }
            }
        }.resume()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fetchStatus() }
    }
    
    /// Sends volume changes to the corresponding endpoint based on current mode
    func sendVolumeRequest(val: Int) {
        let endpoint = (volumeMode == .system) ? "/system/volume" : "/music/volume"
        guard let url = URL(string: "\(macURL)\(endpoint)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["volume": val]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    statusMessage = "Volume Error: \(error.localizedDescription)"
                } else {
                    statusMessage = "\(volumeMode.rawValue) set to \(val)%"
                }
            }
        }.resume()
    }
    
    /// Fetches initial volume level when mode is switched
    func fetchCurrentVolume() {
        guard let url = URL(string: "\(macURL)/\((volumeMode == .system) ? "/system/volume" : "/music/volume")") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let vol = json["volume"] as? Double else { return }
            
            DispatchQueue.main.async {
                self.volume = vol
            }
        }.resume()
    }
    
    private func sendFavouriteRequest() {
        if let current = currentTrack {
            currentTrack?.isFavourite = !current.isFavourite
        }
        
        guard let url = URL(string: "\(macURL)/music/favorite") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let favStatus = json["is_favorite"] as? Bool {
                DispatchQueue.main.async {
                    self.currentTrack?.isFavourite = favStatus
                }
            }
        }.resume()
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { fetchStatus() }
    }
    
    private func fetchStatus() {
        guard let url = URL(string: "\(macURL)/music/status") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { statusMessage = "Error: \(error.localizedDescription)" }
                return
            }
            guard let data = data else { return }
            
            if let trackInfo = try? JSONDecoder().decode(TrackInfo.self, from: data) {
                DispatchQueue.main.async {
                    if trackInfo.status == "success" {
                        // Check if track title or artist changed
                        if self.currentTrack?.title != trackInfo.title || self.currentTrack?.artist != trackInfo.artist {
                            // Delay artwork fetch briefly so macOS finishes writing cache
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.fetchArtworkColors()
                            }
                        }
                        self.currentTrack = trackInfo
                        self.playbackState = trackInfo.isPlaying ? .playing : .paused
                        statusMessage = "Updated successfully"
                    } else {
                        statusMessage = "Mac: Music not playing/running"
                        self.currentTrack = nil
                        self.artworkImage = nil
                    }
                }
            } else {
                DispatchQueue.main.async {
                    statusMessage = "Failed to decode track info."
                }
            }
        }.resume()
    }
}

#Preview {
    ContentView()
}
