import Testing

@testable import MusicTimely

struct HomeViewModelTests {
    @Test func appVersionCombinesVersionAndBuild() {
        let viewModel = HomeViewModel(infoDictionary: [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "45",
        ])

        #expect(viewModel.appVersion == "1.2.3 (45)")
    }

    @Test func appVersionFallsBackToZeroWhenKeysAreMissing() {
        #expect(HomeViewModel(infoDictionary: nil).appVersion == "0 (0)")
        #expect(HomeViewModel(infoDictionary: ["CFBundleShortVersionString": "2.0"]).appVersion == "2.0 (0)")
        #expect(HomeViewModel(infoDictionary: ["CFBundleVersion": "7"]).appVersion == "0 (7)")
    }
}
