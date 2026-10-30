import Foundation

public enum HAURLs {
    public static func normalizedPath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Whether `currentPath` shows `target`, allowing for HA redirecting a dashboard to one of its views.
    public static func isShowing(currentPath: String?, target: String) -> Bool {
        guard let current = currentPath.map(normalizedPath) else { return false }
        let target = normalizedPath(target)
        return current == target || current.hasPrefix(target + "/")
    }

    /// Whether `url` has the same scheme, host and port as `base`.
    public static func isSameOrigin(_ url: URL?, as base: URL) -> Bool {
        guard let url else { return false }
        return url.scheme == base.scheme && url.host == base.host && effectivePort(url) == effectivePort(base)
    }

    private static func effectivePort(_ url: URL) -> Int? {
        url.port ?? (url.scheme == "https" ? 443 : url.scheme == "http" ? 80 : nil)
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
