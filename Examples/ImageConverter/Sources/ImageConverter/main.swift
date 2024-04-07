///
/// A simple backpressure managed HEIC -> JPG converter using Async Channels.
/// A worker is spawned for each avalible CPU. A stream of image paths will
/// fan-out to each worker to perform the conversion, and fan-in the converted
/// images to be written to disk. The CPU should be saturated and images will
/// only be processed as fast as they can be converted.
///
///       /-> worker -\
/// files --> worker --> disk
///       \-> worker -/


import Foundation
import AsyncChannels
import AppKit

// MARK: Helper functions

func convertHEICToJPG(heicImage: NSImage, compressionFactor: CGFloat = 1.0) -> Data? {
    guard let tiffRepresentation = heicImage.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
    return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
}

func getFiles(matchingExtension fileExtension: String, inDirectory directoryPath: String) -> [String] {
    return try! FileManager.default.contentsOfDirectory(atPath: directoryPath)
        .filter { $0.hasSuffix(".\(fileExtension)") }
        .map { "\(directoryPath)/\($0)" }
}

// Constants

let directoryPath = "<PATH TO IMAGES>" // Change me!
let files = getFiles(matchingExtension: "HEIC", inDirectory: directoryPath)

// A queue of file paths
let input = Channel<String>(capacity: 100)

// A queue of converted images and their names
let output = Channel<(Data, String)>(capacity: 100)

// keep track of how many workers are active
let waitGroup = WaitGroup()

// Keep track of when we are done writing images to disk
let done = Channel<Bool>()

// Create a worker for each avalible CPU
for i in 0..<ProcessInfo.processInfo.activeProcessorCount {
    await waitGroup.add(1)
    Task.detached {
        for await path in input {
            print("Process \(path) on task \(i)")
            guard let heicImage = NSImage(contentsOfFile: path) else {
                print("failed to open image \(path)")
                continue
            }
        
            guard let jpgImage = convertHEICToJPG(heicImage: heicImage) else {
                print("Failed to convert image \(path)")
                continue
            }
            
            let name = String(path.split(separator: "/").last!.split(separator: ".").first!)
            print("Converted \(name) to jpg")
            
            await output <- (jpgImage, name)
        }
        await waitGroup.done()
    }
}

// Receive the converted images on one task and write to disk
Task {
    try! FileManager.default.createDirectory(at: URL(fileURLWithPath: "\(directoryPath)/converted/"), withIntermediateDirectories: true, attributes: nil)

    for await (image, name) in output {
        print("Write \(name).jpg")
        try! image.write(to: URL(fileURLWithPath: "\(directoryPath)/converted/\(name).jpg"))
    }
    await done <- true
}

for file in files {
    await input <- file
}

// Close the input when done writing paths
input.close()

// Wait for all workers to finish
await waitGroup.wait()

// Close the output
output.close()

// Wait for all files to be flushed to disk
await <-done
