import Foundation
import MacStateCore

enum MacReadyCommand {
    static let help = """
    macready — read the current Mac state (no Capsomnia app required)

    Usage: macready [status] [--json]
           macready help | --help
           macready --version

    Reports power, battery temperature, thermal state, lid, external display and the
    global SleepDisabled setting. It does not change any system setting.
    Missing observations are null/unknown with reasons, never assumed safe.
    Each invocation reads a fresh snapshot; it does not run in the background.
    Exit codes: 0 snapshot/help/version, 2 invalid arguments, 1 output error.
    A successful snapshot can contain unavailable observations.
    """

    static func run(_ arguments: [String], read: () -> MacSnapshot = MacSnapshot.read) -> (Int32, String) {
        if arguments == ["--help"] || arguments == ["help"] || arguments == ["-h"] { return (0, help) }
        if arguments == ["--version"] || arguments == ["version"] { return (0, "macready 0.1.1") }
        let json = arguments.contains("--json")
        let commands = arguments.filter { $0 != "--json" }
        guard commands.isEmpty || commands == ["status"], arguments.filter({ $0 == "--json" }).count <= 1 else {
            let message = "Invalid arguments. Use macready --help."
            if json { return (2, "{\"error\":\"\(message)\",\"ok\":false}") }
            return (2, message)
        }
        let snapshot = read()
        do { return (0, try json ? snapshot.json() : snapshot.text) }
        catch { return (1, json ? "{\"error\":\"Could not encode snapshot.\",\"ok\":false}" : "Could not encode snapshot.") }
    }
}
