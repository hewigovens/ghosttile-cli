import GhostTileCore

enum HideAppOperationResult {
    case hidden
    case requiresSudo(command: String)
    case requiresWarningConfirmation([AppCompatibility.Warning])
}
