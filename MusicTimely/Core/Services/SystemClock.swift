import Darwin
import Foundation

/// 시계 포트 (명세서 §9.4). 테스트에서는 fake를 주입한다.
nonisolated protocol ClockPort: Sendable {
    func now() -> ClockReading
}

/// mach_continuous_time은 기기 sleep을 포함한다. boot 식별자로 재부팅을 감지한다.
nonisolated struct SystemClock: ClockPort {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static let bootID: String = {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buffer, &size, nil, 0) == 0 else { return "unknown" }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }()

    func now() -> ClockReading {
        let ticks = mach_continuous_time()
        let nanos = ticks * UInt64(Self.timebase.numer) / UInt64(Self.timebase.denom)
        return ClockReading(
            monoMs: Int64(nanos / 1_000_000),
            wallMs: Int64(Date().timeIntervalSince1970 * 1_000),
            bootID: Self.bootID
        )
    }
}
