import FoundationModels

func test() {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        break
    case .unavailable(let reason):
        if reason == .appleIntelligenceNotEnabled {
            print("Not enabled")
        }
    @unknown default:
        break
    }
}
