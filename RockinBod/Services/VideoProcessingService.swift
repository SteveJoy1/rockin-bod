import AVFoundation
import Foundation
import UIKit

// MARK: - Video Processing Errors

enum VideoProcessingError: LocalizedError {
    case invalidAsset
    case noVideoTrack
    case frameExtractionFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidAsset:
            return "The video file could not be loaded."
        case .noVideoTrack:
            return "The video does not contain a video track."
        case .frameExtractionFailed:
            return "Failed to extract frames from the video."
        case .encodingFailed:
            return "Failed to encode the video frame as JPEG."
        }
    }
}

// MARK: - Video Processing Service

enum VideoProcessingService {

    /// Extract evenly-spaced frames from a video file.
    ///
    /// If the video duration is shorter than `maxFrames` seconds, one frame per second
    /// is extracted instead. Each frame is returned as JPEG `Data` at 0.7 compression quality.
    static func extractFrames(from url: URL, maxFrames: Int = 8) async throws -> [Data] {
        let asset = AVURLAsset(url: url)

        // Verify the asset is playable and contains a video track
        guard try await asset.load(.isPlayable) else {
            throw VideoProcessingError.invalidAsset
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoProcessingError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw VideoProcessingError.invalidAsset
        }

        // Determine how many frames to extract and at which times
        let frameCount: Int
        if durationSeconds < Double(maxFrames) {
            frameCount = max(1, Int(durationSeconds))
        } else {
            frameCount = maxFrames
        }

        let interval = durationSeconds / Double(frameCount)
        let times: [NSValue] = (0..<frameCount).map { index in
            let seconds = interval * Double(index) + interval / 2.0
            let time = CMTime(seconds: min(seconds, durationSeconds), preferredTimescale: 600)
            return NSValue(time: time)
        }

        // Configure the image generator
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: 1280, height: 1280)

        // Extract frames
        var frames: [Data] = []

        for time in times {
            let cmTime = time.timeValue
            do {
                let (cgImage, _) = try await generator.image(at: cmTime)
                let uiImage = UIImage(cgImage: cgImage)
                guard let jpegData = uiImage.jpegData(compressionQuality: 0.7) else {
                    throw VideoProcessingError.encodingFailed
                }
                frames.append(jpegData)
            } catch let error as VideoProcessingError {
                throw error
            } catch {
                // Skip frames that fail to extract rather than aborting entirely
                continue
            }
        }

        guard !frames.isEmpty else {
            throw VideoProcessingError.frameExtractionFailed
        }

        return frames
    }

    /// Generate a single thumbnail image from the video at the 1-second mark.
    ///
    /// Returns the thumbnail as JPEG `Data`, or `nil` if the frame could not be generated.
    static func generateThumbnail(from url: URL) async throws -> Data? {
        let asset = AVURLAsset(url: url)

        guard try await asset.load(.isPlayable) else {
            throw VideoProcessingError.invalidAsset
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoProcessingError.noVideoTrack
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)

        let time = CMTime(seconds: 1.0, preferredTimescale: 600)

        let (cgImage, _) = try await generator.image(at: time)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    }

    /// Returns the duration of the video in seconds.
    static func videoDuration(from url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)

        guard try await asset.load(.isPlayable) else {
            throw VideoProcessingError.invalidAsset
        }

        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)

        guard seconds.isFinite, seconds > 0 else {
            throw VideoProcessingError.invalidAsset
        }

        return seconds
    }
}
