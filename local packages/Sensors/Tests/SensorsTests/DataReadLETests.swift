//
//  DataReadLETests.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Testing

import Sensors

struct DataReadLETests {
    @Test func readUInt16LENormalOffset() {
        let data = d(0x34, 0x12) // LE 0x1234
        #expect(data.readUInt16LE(byteOffset: 0) == 0x1234)
    }

    @Test func readUInt16LEWithOffset() {
        let data = d(0x00, 0x00, 0x78, 0x56)
        #expect(data.readUInt16LE(byteOffset: 2) == 0x5678)
    }

    @Test func readUInt16LEOutOfBounds() {
        let data = Data([0x00])
        #expect(data.readUInt16LE(byteOffset: 0) == nil)
        #expect(data.readUInt16LE(byteOffset: 1) == nil)
    }

    @Test func readUInt16LENegativeOffsetReturnsNil() {
        let data = d(0x01, 0x00)
        #expect(data.readUInt16LE(byteOffset: -1) == nil)
    }

    @Test func readUInt32LE() {
        let data = d(0x78, 0x56, 0x34, 0x12)
        #expect(data.readUInt32LE(byteOffset: 0) == 0x12345678)
    }

    @Test func readUInt32LEOutOfBounds() {
        let data = d(0x01, 0x02, 0x03)
        #expect(data.readUInt32LE(byteOffset: 0) == nil)
        #expect(data.readUInt32LE(byteOffset: 1) == nil)
    }

    @Test func readUInt24LE() {
        let data = d(0xFA, 0x00, 0x00) // 250
        #expect(data.readUInt24LE(byteOffset: 0) == 250)
    }

    @Test func readUInt24LEWithOffsetAndBounds() {
        let data = d(0x00, 0x10, 0x20, 0x30)
        #expect(data.readUInt24LE(byteOffset: 1) == 0x302010)
        #expect(data.readUInt24LE(byteOffset: 2) == nil)
        #expect(data.readUInt24LE(byteOffset: -1) == nil)
    }

    private func d(_ bytes: UInt8...) -> Data {
        Data(bytes)
    }
}
