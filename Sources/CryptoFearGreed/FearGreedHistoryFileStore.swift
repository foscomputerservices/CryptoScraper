// FearGreedHistoryFileStore.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``FearGreedHistoryStore`` in one plain file, so a retrieval runs with nothing behind it
///
/// JSON Lines: one ``FearGreedDay`` per line, in the order kept, through FOSFoundation's `toJSON()`, so a time is UTC
/// text to the millisecond. An append adds lines at the end and never rewrites one. A line that does not decode is an
/// error and never skipped.
///
/// One store per file per process: the store reads the file once and keeps it in memory after.
public actor FearGreedHistoryFileStore: FearGreedHistoryStore {
    /// The file the days are in, created on the first append
    public let file: URL

    private var loaded: [FearGreedDay]?

    public init(file: URL) {
        self.file = file
    }

    public func lastDay() async throws -> FearGreedDay? {
        try kept().last
    }

    public func append(_ days: [FearGreedDay]) async throws {
        let kept = try kept()
        var text = ""
        for day in days {
            text += try day.toJSON() + "\n"
        }

        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: file.path) {
            _ = FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))

        loaded = kept + days
    }

    public func history() async throws -> [FearGreedDay] {
        try kept()
    }

    // The file's days, read once and kept in memory after.
    private func kept() throws -> [FearGreedDay] {
        if let loaded {
            return loaded
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            return []
        }

        var days: [FearGreedDay] = []
        let text = try String(contentsOf: file, encoding: .utf8)
        // A line that does not decode, a torn last line among them, is an error and never skipped.
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let day: FearGreedDay = try String(line).fromJSON()
            days.append(day)
        }
        loaded = days
        return days
    }
}
