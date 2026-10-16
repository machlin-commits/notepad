import Foundation

struct DecodedText {
    let text: String
    let encoding: TextEncoding
    let lineEnding: LineEnding
}

enum EncodingService {
    static func decode(_ data: Data) throws -> DecodedText {
        let candidates: [(TextEncoding, Data)] = [
            (.utf32BigEndian, Data([0x00, 0x00, 0xFE, 0xFF])),
            (.utf32LittleEndian, Data([0xFF, 0xFE, 0x00, 0x00])),
            (.utf8BOM, Data([0xEF, 0xBB, 0xBF])),
            (.utf16BigEndian, Data([0xFE, 0xFF])),
            (.utf16LittleEndian, Data([0xFF, 0xFE]))
        ]

        for (encoding, bom) in candidates where data.starts(with: bom) {
            let payload = data.dropFirst(bom.count)
            if let text = String(data: payload, encoding: encoding.stringEncoding) {
                return normalized(text, encoding: encoding)
            }
        }

        for encoding in [TextEncoding.utf8, .ascii, .windows1252, .macRoman] {
            if let text = String(data: data, encoding: encoding.stringEncoding) {
                return normalized(text, encoding: encoding)
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    static func encode(_ text: String, encoding: TextEncoding, lineEnding: LineEnding) throws -> Data {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: lineEnding.sequence)
        guard let payload = normalized.data(using: encoding.stringEncoding, allowLossyConversion: false) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return encoding.byteOrderMark + payload
    }

    private static func normalized(_ text: String, encoding: TextEncoding) -> DecodedText {
        let ending: LineEnding
        if text.contains("\r\n") {
            ending = .crlf
        } else if text.contains("\r") {
            ending = .cr
        } else {
            ending = .lf
        }
        let value = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return DecodedText(text: value, encoding: encoding, lineEnding: ending)
    }
}
