import Foundation

struct GuestMachOLayout {
  struct Symbol {
    let name: String
    let virtualAddress: UInt64
    let fileOffset: Int
  }

  let sliceOffset: Int
  let sliceSize: Int
  let textFileOffset: Int
  let textSize: Int
  let symbols: [String: Symbol]

  var summary: String {
    let vm = symbols["_kDartVmSnapshotInstructions"]?.fileOffset ?? -1
    let isolate = symbols["_kDartIsolateSnapshotInstructions"]?.fileOffset ?? -1
    return "AOT text=\(textSize) bytes vm@\(vm) isolate@\(isolate)"
  }
}

enum GuestMachOError: LocalizedError {
  case truncated
  case unsupportedContainer
  case unsupportedArchitecture
  case invalidMachO
  case missingText
  case missingSymbol(String)

  var errorDescription: String? {
    switch self {
    case .truncated: return "App.framework Mach-O is truncated"
    case .unsupportedContainer: return "Unsupported Mach-O container"
    case .unsupportedArchitecture: return "IPA has no ARM64 App.framework slice"
    case .invalidMachO: return "Invalid ARM64 Mach-O header"
    case .missingText: return "Missing __TEXT,__text section"
    case .missingSymbol(let name): return "Missing Flutter AOT symbol \(name)"
    }
  }
}

struct GuestMachOParser {
  private struct Section {
    let address: UInt64
    let size: UInt64
    let offset: Int
    let segment: String
    let name: String
  }

  private let data: Data

  init(url: URL) throws {
    data = try Data(contentsOf: url, options: [.mappedIfSafe])
  }

  func parse() throws -> GuestMachOLayout {
    let slice = try arm64Slice()
    guard try u32LE(slice.offset) == 0xfeedfacf else {
      throw GuestMachOError.invalidMachO
    }

    let commandCount = Int(try u32LE(slice.offset + 16))
    var commandOffset = slice.offset + 32
    var sections: [Section] = []
    var symbolTable: (offset: Int, count: Int, strings: Int, stringSize: Int)?

    for _ in 0..<commandCount {
      let command = try u32LE(commandOffset)
      let commandSize = Int(try u32LE(commandOffset + 4))
      guard commandSize >= 8, commandOffset + commandSize <= slice.offset + slice.size else {
        throw GuestMachOError.truncated
      }

      if command == 0x19 {
        let segmentName = try fixedString(commandOffset + 8, length: 16)
        let sectionCount = Int(try u32LE(commandOffset + 64))
        var sectionOffset = commandOffset + 72
        for _ in 0..<sectionCount {
          let sectionName = try fixedString(sectionOffset, length: 16)
          let owningSegment = try fixedString(sectionOffset + 16, length: 16)
          sections.append(Section(
            address: try u64LE(sectionOffset + 32),
            size: try u64LE(sectionOffset + 40),
            offset: slice.offset + Int(try u32LE(sectionOffset + 48)),
            segment: owningSegment.isEmpty ? segmentName : owningSegment,
            name: sectionName
          ))
          sectionOffset += 80
        }
      } else if command == 0x2 {
        symbolTable = (
          slice.offset + Int(try u32LE(commandOffset + 8)),
          Int(try u32LE(commandOffset + 12)),
          slice.offset + Int(try u32LE(commandOffset + 16)),
          Int(try u32LE(commandOffset + 20))
        )
      }
      commandOffset += commandSize
    }

    guard let text = sections.first(where: { $0.segment == "__TEXT" && $0.name == "__text" }) else {
      throw GuestMachOError.missingText
    }
    guard let table = symbolTable else {
      throw GuestMachOError.invalidMachO
    }

    let required = [
      "_kDartVmSnapshotData",
      "_kDartVmSnapshotInstructions",
      "_kDartIsolateSnapshotData",
      "_kDartIsolateSnapshotInstructions",
    ]
    var symbols: [String: GuestMachOLayout.Symbol] = [:]
    for index in 0..<table.count {
      let entry = table.offset + index * 16
      let stringIndex = Int(try u32LE(entry))
      guard stringIndex > 0, stringIndex < table.stringSize else { continue }
      let name = try nullTerminatedString(table.strings + stringIndex, limit: table.strings + table.stringSize)
      guard required.contains(name) else { continue }
      let value = try u64LE(entry + 8)
      guard let section = sections.first(where: { value >= $0.address && value < $0.address + $0.size }) else {
        throw GuestMachOError.invalidMachO
      }
      let fileOffset = section.offset + Int(value - section.address)
      symbols[name] = GuestMachOLayout.Symbol(name: name, virtualAddress: value, fileOffset: fileOffset)
    }

    for name in required where symbols[name] == nil {
      throw GuestMachOError.missingSymbol(name)
    }

    return GuestMachOLayout(
      sliceOffset: slice.offset,
      sliceSize: slice.size,
      textFileOffset: text.offset,
      textSize: Int(text.size),
      symbols: symbols
    )
  }

  private func arm64Slice() throws -> (offset: Int, size: Int) {
    let magic = try u32BE(0)
    if magic == 0xcafebabe {
      let count = Int(try u32BE(4))
      for index in 0..<count {
        let arch = 8 + index * 20
        let cpuType = try u32BE(arch)
        if cpuType == 0x0100000c {
          return (Int(try u32BE(arch + 8)), Int(try u32BE(arch + 12)))
        }
      }
      throw GuestMachOError.unsupportedArchitecture
    }
    if try u32LE(0) == 0xfeedfacf {
      return (0, data.count)
    }
    throw GuestMachOError.unsupportedContainer
  }

  private func u32LE(_ offset: Int) throws -> UInt32 {
    guard offset >= 0, offset + 4 <= data.count else { throw GuestMachOError.truncated }
    return data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
  }

  private func u64LE(_ offset: Int) throws -> UInt64 {
    guard offset >= 0, offset + 8 <= data.count else { throw GuestMachOError.truncated }
    return data.withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self)) }
  }

  private func u32BE(_ offset: Int) throws -> UInt32 {
    guard offset >= 0, offset + 4 <= data.count else { throw GuestMachOError.truncated }
    return data.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
  }

  private func fixedString(_ offset: Int, length: Int) throws -> String {
    guard offset >= 0, offset + length <= data.count else { throw GuestMachOError.truncated }
    let bytes = data[offset..<(offset + length)].prefix { $0 != 0 }
    return String(decoding: bytes, as: UTF8.self)
  }

  private func nullTerminatedString(_ offset: Int, limit: Int) throws -> String {
    guard offset >= 0, offset < limit, limit <= data.count else { throw GuestMachOError.truncated }
    var end = offset
    while end < limit, data[end] != 0 { end += 1 }
    return String(decoding: data[offset..<end], as: UTF8.self)
  }
}

