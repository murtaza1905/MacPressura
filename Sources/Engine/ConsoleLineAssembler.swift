// Sources/Engine/ConsoleLineAssembler.swift
import Foundation

/// Turns the raw byte stream of a console program into logical lines.
///
/// 7-Zip redraws its progress indicator in place using backspace (`\b`) and
/// carriage-return (`\r`) characters instead of printing a new line for every update.
/// This assembler emulates a terminal cursor so that the text a user would actually
/// see on screen is what gets reported: completed lines (terminated by `\n`) and the
/// current, still-unterminated line (where the percentage lives).
struct ConsoleLineAssembler {
    private var pendingBytes: [UInt8] = []
    private var buffer: [Character] = []
    private var cursor: Int = 0

    /// Feeds raw bytes. Returns the lines completed by this chunk and the current partial line.
    mutating func feed(_ data: Data) -> (completed: [String], current: String) {
        pendingBytes.append(contentsOf: data)
        let usable = Self.completeUTF8PrefixLength(pendingBytes)
        let text = String(decoding: pendingBytes[0..<usable], as: UTF8.self)
        pendingBytes.removeFirst(usable)

        var completed: [String] = []
        for character in text {
            switch character {
            case "\n":
                completed.append(trimmedLine())
                buffer.removeAll(keepingCapacity: true)
                cursor = 0
            case "\r":
                cursor = 0
            case "\u{08}":
                if cursor > 0 { cursor -= 1 }
            default:
                if cursor < buffer.count {
                    buffer[cursor] = character
                } else {
                    buffer.append(character)
                }
                cursor += 1
            }
        }
        return (completed, currentLine)
    }

    /// Flushes whatever is left (used when the stream ends without a trailing newline).
    mutating func flush() -> String? {
        if !pendingBytes.isEmpty {
            let text = String(decoding: pendingBytes, as: UTF8.self)
            pendingBytes.removeAll()
            for character in text where character != "\r" && character != "\u{08}" {
                if character == "\n" { continue }
                buffer.append(character)
            }
        }
        let line = trimmedLine()
        buffer.removeAll()
        cursor = 0
        return line.isEmpty ? nil : line
    }

    var currentLine: String {
        String(buffer).trimmingCharacters(in: .whitespaces)
    }

    private func trimmedLine() -> String {
        var line = String(buffer)
        while let last = line.last, last == " " || last == "\t" { line.removeLast() }
        return line
    }

    /// Length of the longest prefix that does not end in the middle of a multi-byte UTF-8 sequence.
    static func completeUTF8PrefixLength(_ bytes: [UInt8]) -> Int {
        let count = bytes.count
        guard count > 0 else { return 0 }
        var index = count - 1
        var scanned = 0
        while index >= 0 && scanned < 4 {
            let byte = bytes[index]
            if byte & 0b1100_0000 != 0b1000_0000 {
                let expected: Int
                if byte & 0b1000_0000 == 0 { expected = 1 }
                else if byte & 0b1110_0000 == 0b1100_0000 { expected = 2 }
                else if byte & 0b1111_0000 == 0b1110_0000 { expected = 3 }
                else if byte & 0b1111_1000 == 0b1111_0000 { expected = 4 }
                else { return count }
                return (count - index) < expected ? index : count
            }
            index -= 1
            scanned += 1
        }
        return count
    }
}

/// Parses the in-place progress line 7-Zip draws: `" 37% 12 + path"`, `"100% 4"`, `"  0%"`.
enum ProgressLineParser {
    private static let regex = try! NSRegularExpression(pattern: #"^\s*(\d{1,3})%(?:\s+(\d+))?(?:\s+([+\-TU=])\s(.*))?$"#)

    static func parse(_ line: String) -> ProgressUpdate? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }
        var update = ProgressUpdate()
        if let r = Range(match.range(at: 1), in: line), let value = Int(line[r]) {
            update.percent = min(max(value, 0), 100)
        }
        if match.range(at: 2).location != NSNotFound, let r = Range(match.range(at: 2), in: line), let value = Int(line[r]) {
            update.processedCount = value
        }
        if match.range(at: 4).location != NSNotFound, let r = Range(match.range(at: 4), in: line) {
            let item = String(line[r]).trimmingCharacters(in: .whitespaces)
            if !item.isEmpty { update.currentItem = item }
        }
        return update
    }

    /// Lines 7-Zip prints per processed item with `-bb1`: `"+ path"` (add), `"- path"` (extract), `"T path"` (test), `"U path"` (update).
    static func itemName(fromCompletedLine line: String) -> String? {
        guard line.count > 2 else { return nil }
        let first = line[line.startIndex]
        let second = line[line.index(after: line.startIndex)]
        guard second == " ", "+-TU=".contains(first) else { return nil }
        let name = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
