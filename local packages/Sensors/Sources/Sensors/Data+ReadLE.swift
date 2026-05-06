//
//  Data+ReadLE.swift
//  Sensors
//
//  Little-endian helpers for BLE GATT payloads using `UnsafeRawBufferPointer.loadUnaligned`
//  and `FixedWidthInteger.init(littleEndian:)`.
//

import Foundation

package extension Data {
    func readLE<T: FixedWidthInteger>(at byteOffset: Int, as type: T.Type) -> T? {
        let size = MemoryLayout<T>.size
        guard byteOffset >= 0, byteOffset + size <= count else { return nil }
        let raw: T = withUnsafeBytes { buf in
            buf.loadUnaligned(fromByteOffset: byteOffset, as: T.self)
        }
        return T(littleEndian: raw)
    }

    func readUInt16LE(byteOffset: Int) -> UInt16? {
        readLE(at: byteOffset, as: UInt16.self)
    }

    func readUInt24LE(byteOffset: Int) -> UInt32? {
        guard byteOffset >= 0, byteOffset + 3 <= count else { return nil }
        let i = startIndex + byteOffset
        return UInt32(self[i])
            | (UInt32(self[i + 1]) << 8)
            | (UInt32(self[i + 2]) << 16)
    }

    func readUInt32LE(byteOffset: Int) -> UInt32? {
        readLE(at: byteOffset, as: UInt32.self)
    }
}
