import ShieldGuardCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ShieldGuardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ShieldGuard")
                .font(.title2.weight(.semibold))

            Text("Checks whether each package manager enforces a 1-week minimum package age.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Check now") {
                    viewModel.checkNow()
                }

                Button("Fix all") {
                    viewModel.fixAll()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.results.isEmpty)
            }

            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            ScrollView {
                if viewModel.results.isEmpty {
                    Text("Install at least one of: npm, pnpm, uv, bun.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.results, id: \.manager) { result in
                            managerRow(result: result)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 460)
    }

    private func managerRow(result: ManagerCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.manager.displayName)
                    .font(.headline)

                Spacer()

                Label(
                    result.compliant ? "Present" : "Missing",
                    systemImage: result.compliant ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(result.compliant ? .green : .red)
                .font(.subheadline.weight(.medium))
            }

            Text("Required line: \(result.requiredValueDescription)")
                .font(.subheadline)

            HStack(spacing: 14) {
                Button(result.addButtonTitle) {
                    viewModel.addRequiredValue(for: result.manager)
                }

                Button {
                    viewModel.openInFinder(result.fileURL)
                } label: {
                    Text("Open in Finder: \(result.fileURL.path)")
                        .underline()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
