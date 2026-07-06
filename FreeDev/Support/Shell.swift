import Foundation
import os

/// Runs short-lived command-line tools (`du`, `xcrun`) with a hard timeout so a
/// hung command can never stall the app. Output is drained on background queues
/// (so a full pipe can't deadlock the child), and if the command overruns its
/// timeout it is killed and a timed-out result is returned.
enum Shell {
    private static let log = Logger(subsystem: "com.tekadept.FreeDev", category: "Shell")

    /// Sentinel status for a command that was killed after exceeding its timeout.
    static let timeoutStatus: Int32 = -999

    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
        var timedOut: Bool { status == Shell.timeoutStatus }
    }

    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval = 60) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: "\(error)")
        }

        // Drain both pipes concurrently: prevents a two-pipe deadlock and lets a
        // killed child still yield whatever it managed to write.
        var outData = Data()
        var errData = Data()
        let reads = DispatchGroup()
        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading
        reads.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outHandle.readDataToEndOfFile(); reads.leave()
        }
        reads.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errHandle.readDataToEndOfFile(); reads.leave()
        }

        if exited.wait(timeout: .now() + timeout) == .timedOut {
            // Hung command — never let it stall a scan. Kill it, hard if needed.
            log.error("Timed out after \(Int(timeout), privacy: .public)s, killing: \(launchPath, privacy: .public) \(arguments.joined(separator: " "), privacy: .public)")
            process.terminate()
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            _ = exited.wait(timeout: .now() + 3)   // let the pipes close
            reads.wait()
            return Result(status: timeoutStatus,
                          stdout: String(decoding: outData, as: UTF8.self),
                          stderr: "timed out after \(Int(timeout))s")
        }

        reads.wait()
        return Result(status: process.terminationStatus,
                      stdout: String(decoding: outData, as: UTF8.self),
                      stderr: String(decoding: errData, as: UTF8.self))
    }
}
