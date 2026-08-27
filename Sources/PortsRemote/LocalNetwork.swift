import Foundation

enum LocalNetwork {
    /// Non-loopback IPv4 addresses of active interfaces, for certificate SANs
    /// and for showing the user a reachable address.
    static func ipv4Addresses() -> [String] {
        var addresses: [String] = []
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacePointer) == 0, let first = interfacePointer else {
            return []
        }
        defer { freeifaddrs(interfacePointer) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            guard flags & (IFF_UP | IFF_RUNNING) == (IFF_UP | IFF_RUNNING),
                flags & IFF_LOOPBACK == 0,
                let addr = pointer.pointee.ifa_addr,
                addr.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr, socklen_t(addr.pointee.sa_len),
                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            if result == 0 {
                let address = String(cString: host)
                if !address.isEmpty, !addresses.contains(address) {
                    addresses.append(address)
                }
            }
        }
        return addresses
    }
}
