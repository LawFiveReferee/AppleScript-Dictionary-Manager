//
//  SDEFEncoding.swift
//  AppleScriptDictionaryManager
//
//  Created by Ed Stockly on 12/27/25.
//

import Foundation
import CoreFoundation

enum SDEFEncodingError: Error { case decodeFailed }

/// Decode XML data honoring BOM and `<?xml ... encoding="...">`.
func decodeXMLData(_ data: Data) throws -> String {
    // --- BOM checks ---
    if data.count >= 3 && data.prefix(3) == Data([0xEF, 0xBB, 0xBF]) {
        return String(decoding: data.dropFirst(3), as: UTF8.self)
    }
    if data.count >= 2 {
        let b0 = data[0], b1 = data[1]
        if b0 == 0xFE && b1 == 0xFF, let s = String(data: data, encoding: .utf16BigEndian) { return s }
        if b0 == 0xFF && b1 == 0xFE {
            if data.count >= 4, data[2] == 0x00, data[3] == 0x00,
               let s = String(data: data, encoding: .utf32LittleEndian) { return s }
            if let s = String(data: data, encoding: .utf16LittleEndian) { return s }
        }
        if data.count >= 4 {
            let b2 = data[2], b3 = data[3]
            if b0 == 0x00 && b1 == 0x00 && b2 == 0xFE && b3 == 0xFF,
               let s = String(data: data, encoding: .utf32BigEndian) { return s }
        }
    }
    
    // --- XML declaration encoding attr ---
    if let headerASCII = String(data: data.prefix(1024), encoding: .ascii)
        ?? String(data: data.prefix(1024), encoding: .utf8) {
        if let r = headerASCII.range(of: #"encoding\s*=\s*["']([^"']+)["']"#,
                                     options: .regularExpression) {
            let encName = String(headerASCII[r]).replacingOccurrences(
                of: #"^encoding\s*=\s*["']|["']$"#,
                with: "",
                options: .regularExpression
            )
            if let encoding = stringEncoding(fromIANA: encName),
               let s = String(data: data, encoding: encoding) {
                return s
            }
        }
    }
    
    // --- Foundation auto-detect ---
    var converted: NSString?
    let detected = NSString.stringEncoding(for: data,
                                           encodingOptions: nil,
                                           convertedString: &converted,
                                           usedLossyConversion: nil)
    if detected != 0, let converted { return converted as String }
    
    // --- Fallbacks ---
    let candidates: [String.Encoding] = [
        .utf8, .utf16, .utf16BigEndian, .utf16LittleEndian,
        .macOSRoman, .isoLatin1, .windowsCP1252
    ]
    for e in candidates {
        if let s = String(data: data, encoding: e) { return s }
    }
    throw SDEFEncodingError.decodeFailed
}

private func stringEncoding(fromIANA name: String) -> String.Encoding? {
    let lower = name.lowercased()
    switch lower {
    case "utf-8", "utf8": return .utf8
    case "utf-16", "utf16": return .utf16
    case "utf-16le", "utf16le": return .utf16LittleEndian
    case "utf-16be", "utf16be": return .utf16BigEndian
    case "utf-32", "utf32": return .utf32
    case "utf-32le", "utf32le": return .utf32LittleEndian
    case "utf-32be", "utf32be": return .utf32BigEndian
    case "macintosh", "mac-roman", "macosroman", "x-mac-roman": return .macOSRoman
    case "iso-8859-1", "latin1", "latin-1", "iso8859-1": return .isoLatin1
    case "windows-1252", "cp1252", "windows1252": return .windowsCP1252
    default:
        let cfEnc = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        if cfEnc != kCFStringEncodingInvalidId {
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
            return String.Encoding(rawValue: nsEnc)
        }
        return nil
    }
}
