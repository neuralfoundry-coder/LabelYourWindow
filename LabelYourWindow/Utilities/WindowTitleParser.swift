import Foundation

struct WindowTitleParser {
    static func parse(title: String, appName: String, bundleID: String?) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return appName }

        if let id = bundleID {
            if let parsed = parseByBundleID(id, title: trimmed, appName: appName) {
                return parsed
            }
        }

        return parseGeneric(title: trimmed, appName: appName)
    }

    // MARK: - App-specific parsers

    private static func parseByBundleID(_ bundleID: String, title: String, appName: String) -> String? {
        switch bundleID {
        // Browsers
        case let id where id.contains("safari"), let id where id.contains("chrome"),
             let id where id.contains("firefox"), let id where id.contains("arc"),
             let id where id.contains("brave"), let id where id.contains("edge"):
            return parseBrowserTitle(title, appName: appName)

        // Code editors
        case let id where id.contains("vscode"), let id where id.contains("com.microsoft.VSCode"),
             let id where id.contains("cursor"):
            return parseEditorTitle(title)

        // Xcode
        case let id where id.contains("Xcode"):
            return parseEditorTitle(title)

        // Terminal
        case let id where id.contains("terminal"), let id where id.contains("iterm"),
             let id where id.contains("warp"), let id where id.contains("alacritty"):
            return parseTerminalTitle(title)

        // Finder
        case "com.apple.finder":
            return title

        default:
            return nil
        }
    }

    private static func parseBrowserTitle(_ title: String, appName: String) -> String {
        // "Page Title - Google Chrome" -> "Page Title"
        let suffixes = [" - Google Chrome", " - Safari", " - Firefox", " - Arc", " - Brave", " - Microsoft Edge", " — Mozilla Firefox"]
        var result = title
        for suffix in suffixes {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
                break
            }
        }
        return result.isEmpty ? appName : result
    }

    private static func parseEditorTitle(_ title: String) -> String {
        // "file.swift — ProjectName — Visual Studio Code" -> "file.swift (ProjectName)"
        // "file.swift - ProjectName" -> "file.swift (ProjectName)"
        let separators = [" — ", " - ", " – "]
        for sep in separators {
            let parts = title.components(separatedBy: sep)
            if parts.count >= 3 {
                let file = parts[0].trimmingCharacters(in: .whitespaces)
                let project = parts[1].trimmingCharacters(in: .whitespaces)
                return "\(file) (\(project))"
            } else if parts.count == 2 {
                let file = parts[0].trimmingCharacters(in: .whitespaces)
                let project = parts[1].trimmingCharacters(in: .whitespaces)
                // Check if second part is an app name
                let appNames = ["Visual Studio Code", "Cursor", "Xcode"]
                if appNames.contains(project) {
                    return file
                }
                return "\(file) (\(project))"
            }
        }
        return title
    }

    private static func parseTerminalTitle(_ title: String) -> String {
        // Often shows "user@host: ~/path" or just "~/path"
        // Extract the meaningful path part
        if let colonIndex = title.lastIndex(of: ":") {
            let path = title[title.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespaces)
            if !path.isEmpty { return path }
        }

        // If title contains path separators, try to get last component
        if title.contains("/") {
            let parts = title.components(separatedBy: "/")
            if let last = parts.last, !last.isEmpty {
                return last
            }
        }

        return title
    }

    // MARK: - Generic parser

    private static func parseGeneric(title: String, appName: String) -> String {
        // Strip app name from the end if present
        let separators = [" — ", " - ", " – "]
        for sep in separators {
            if title.hasSuffix("\(sep)\(appName)") {
                let result = String(title.dropLast(sep.count + appName.count))
                if !result.isEmpty { return result }
            }
        }

        // If title has separator, take the first meaningful part
        for sep in separators {
            let parts = title.components(separatedBy: sep)
            if parts.count >= 2 {
                let first = parts[0].trimmingCharacters(in: .whitespaces)
                if !first.isEmpty { return first }
            }
        }

        return title
    }
}
