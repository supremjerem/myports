import Darwin
import Foundation

/// Extra process details resolved from the kernel rather than from `lsof`.
public struct ProcessDetails: Sendable, Equatable {
    public var executablePath: String?
    public var parentPID: Int32?
    public var startDate: Date?
    public var arguments: [String]

    public static let empty = ProcessDetails(
        executablePath: nil, parentPID: nil, startDate: nil, arguments: [])
}

/// Resolves executable path, parent pid, start time and arguments for a pid.
public protocol ProcessInspecting: Sendable {
    func inspect(pid: Int32) -> ProcessDetails
}

/// Uses `proc_pidpath`, `proc_pidinfo(PROC_PIDTBSDINFO)` and
/// `sysctl(KERN_PROCARGS2)`. Every field is best-effort: on failure it is left
/// `nil`/empty rather than throwing, because a partially-described process is
/// still useful to show.
public struct ProcessInspector: ProcessInspecting {
    public init() {}

    public func inspect(pid: Int32) -> ProcessDetails {
        ProcessDetails(
            executablePath: Self.executablePath(pid: pid),
            parentPID: Self.bsdInfo(pid: pid)?.parentPID,
            startDate: Self.bsdInfo(pid: pid)?.startDate,
            arguments: Self.arguments(pid: pid)
        )
    }

    static func executablePath(pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer[0..<Int(length)], as: UTF8.self)
    }

    static func bsdInfo(pid: Int32) -> (parentPID: Int32, startDate: Date)? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        let read = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard read == size else { return nil }
        let seconds = TimeInterval(info.pbi_start_tvsec)
        let micros = TimeInterval(info.pbi_start_tvusec) / 1_000_000
        return (Int32(bitPattern: info.pbi_ppid), Date(timeIntervalSince1970: seconds + micros))
    }

    /// Parses `KERN_PROCARGS2`, whose layout is:
    /// `[Int32 argc][exec path\0][padding \0…][argv[0]\0]…[argv[argc-1]\0][env…]`.
    static func arguments(pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
            return []
        }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc > 0 else { return [] }

        var index = MemoryLayout<Int32>.size

        // Skip the exec path.
        while index < size, buffer[index] != 0 { index += 1 }
        // Skip the run of NUL padding before argv[0].
        while index < size, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []
        var current: [UInt8] = []
        while index < size, arguments.count < Int(argc) {
            let byte = buffer[index]
            if byte == 0 {
                arguments.append(String(decoding: current, as: UTF8.self))
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(byte)
            }
            index += 1
        }
        return arguments
    }
}
