import SwiftUI

/// Search field, sort menu, loopback filter and manual refresh.
struct PortsToolbar: View {
    @Bindable var model: PortsViewModel

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter by port, name, or PID", text: $model.searchText)
                    .textFieldStyle(.plain)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

            Menu {
                Picker("Sort by", selection: $model.sortOrder) {
                    ForEach(PortSortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                Divider()
                Toggle("Loopback only", isOn: $model.showLoopbackOnly)
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                Task { await model.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                    .animation(
                        model.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: model.isRefreshing)
            }
            .buttonStyle(.plain)
            .help("Refresh now")
        }
    }
}
