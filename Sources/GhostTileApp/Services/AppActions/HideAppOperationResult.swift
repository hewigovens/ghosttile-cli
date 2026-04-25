enum HideAppOperationResult {
    case hidden
    case requiresSudo(command: String)
}
