import Foundation

public enum HAURLs {
    public static func normalizedPath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public static func dashboard(base: URL, path: String) -> URL {
        join(base, normalizedPath(path))
    }

    public static func api(base: URL, _ path: String) -> URL {
        join(base, "api/" + normalizedPath(path))
    }

    private static func join(_ base: URL, _ path: String) -> URL {
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: root + "/" + path)!
    }
}
