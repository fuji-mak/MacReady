import Foundation
import Darwin

@main
enum MacReadyCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let (status, output) = MacReadyCommand.run(arguments)
        let handle = status == 0 || arguments.contains("--json") ? FileHandle.standardOutput : .standardError
        handle.write(Data((output + "\n").utf8))
        exit(status)
    }
}
