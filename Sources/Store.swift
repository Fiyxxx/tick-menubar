import Foundation

struct Todo: Codable {
    var id = UUID()
    var text = ""
    var done = false
}

@MainActor
final class Store {
    let url: URL
    private var pending: DispatchWorkItem?

    init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tick")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.url = dir.appendingPathComponent("todos.json")
        }
    }

    func load() -> [Todo] {
        guard let raw = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Todo].self, from: raw)) ?? []
    }

    // writes are batched so fast typing doesn't hit the disk on every key
    func save(_ items: [Todo]) {
        pending?.cancel()
        let kept = items.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let work = DispatchWorkItem { [url] in
            if let json = try? JSONEncoder().encode(kept) {
                try? json.write(to: url, options: .atomic)
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func flush() {
        guard let work = pending, !work.isCancelled else { return }
        work.perform()
        work.cancel()
        pending = nil
    }
}
