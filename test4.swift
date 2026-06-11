import FoundationModels

func test() {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        break
    case .unavailable(let reason):
        print(reason)
    @unknown default:
        break
    }
}
