import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "music.note")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Welcome to MusicTimely")
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier("home.welcome")
                Text("Version \(viewModel.appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
