import Foundation
import os

/// Runs short-lived command-line tools (`du`, `xcrun`) with a hard timeout that
/// it ALWAYS honours — even if the child spawns its own children or gets stuck
/// in uninterruptible I/O. Output is captured to temp files (not pipes), so a
/// surviving grandchild can never hold a pipe open and hang us; and after a
/// timeout we wait only a short bounded grace before returning.
enum Shell {
    private static let log = Logger(subsystem: "com.tekadept.FreeDev", category: "Shell")

    /// Sentinel status for a command killed after exceeding its timeout.
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

        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        let outURL = tmp.appendingPathComponent("freedev-\(UUID().uuidString).out")
        let errURL = tmp.appendingPathComponent("freedev-\(UUID().uuidString).err")
        fm.createFile(atPath: outURL.path, contents: nil)
        fm.createFile(atPath: errURL.path, contents: nil)
        defer { try? fm.removeItem(at: outURL); try? fm.removeItem(at: errURL) }

        guard let outFH = try? FileHandle(forWritingTo: outURL),
              let errFH = try? FileHandle(forWritingTo: errURL) else {
            return Result(status: -1, stdout: "", stderr: "could not create output files")
        }
        process.standardOutput = outFH
        process.standardError = errFH

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            try? outFH.close(); try? errFH.close()
            return Result(status: -1, stdout: "", stderr: "\(error)")
        }

        var timedOut = false
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            log.error("Timed out after \(Int(timeout), privacy: .public)s, killing: \(launchPath, privacy: .public) \(arguments.joined(separator: " "), privacy: .public)")
            process.terminate()
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            _ = exited.wait(timeout: .now() + 2) // bounded — never wait forever
        }

        // Read from the files by path; we never block on the child's fds.
        try? outFH.close()
        try? errFH.close()
        let outData = (try? Data(contentsOf: outURL)) ?? Data()
        let errData = (try? Data(contentsOf: errURL)) ?? Data()

        return Result(
            status: timedOut ? timeoutStatus : process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: timedOut ? "timed out after \(Int(timeout))s" : String(decoding: errData, as: UTF8.self)
        )
    }
}
