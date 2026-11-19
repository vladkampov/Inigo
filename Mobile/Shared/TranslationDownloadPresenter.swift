import UIKit
import SwiftUI
import Translation

@MainActor
final class TranslationDownloadPresenter {
    private var continuation: CheckedContinuation<Void, Error>?
    private var controller: UIViewController?
    func prepare(from: Locale.Language, to: Locale.Language, on presenter: UIViewController) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                var configuration = TranslationSession.Configuration(source: from, target: to)
                if #available(iOS 26.4, *) { configuration.preferredStrategy = .lowLatency }
                let view = DownloadView(configuration: configuration) { [weak self] result in self?.finish(result) }
                let host = UIHostingController(rootView: view)
                host.isModalInPresentation = true
                self.controller = host
                presenter.present(host, animated: true)
            }
        } onCancel: { Task { @MainActor in self.finish(.failure(CancellationError())) } }
    }
    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        controller?.dismiss(animated: false); controller = nil
        continuation.resume(with: result)
    }
}
private struct DownloadView: View {
    let configuration: TranslationSession.Configuration
    let finish: @MainActor (Result<Void, Error>) -> Void
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text(M("Preparing offline translation")).font(.headline)
            Text(M("Allow Apple to download the language packs. Your text stays on this iPhone.")).multilineTextAlignment(.center)
            Button(M("Cancel")) { finish(.failure(CancellationError())) }
        }.padding(32)
        .translationTask(configuration) { session in
            do { try await session.prepareTranslation(); try Task.checkCancellation(); finish(.success(())) }
            catch { finish(.failure(error)) }
        }
    }
}
