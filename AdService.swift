import Foundation
import Combine
import UIKit

import GoogleMobileAds

// MARK: - AdService

/// Fetches native ads from Google AdMob and provides them to the UI.
/// Optimized for maximum revenue by using real-time bidding via AdMob.
class AdService: NSObject, ObservableObject {
    enum AdLoadState {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    static let shared = AdService()

    @Published var nativeAds: [String: NativeAd] = [:]
    @Published private(set) var adStates: [String: AdLoadState] = [:]
    
    private var adLoaders: [String: AdLoader] = [:]
    private var isSDKStarted = false
    
    // Test Ad Unit ID for Native Advanced
    private let testAdUnitID = "ca-app-pub-3940256099942544/3986624511"
    
    /// Attempts to find the current root view controller for presenting/click handling.
    private func currentRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
    
    /// Ensures the Google Mobile Ads SDK is initialized.
    private func ensureSDKStarted() {
        #if canImport(GoogleMobileAds)
        guard !isSDKStarted else { return }
        isSDKStarted = true
        MobileAds.shared.start(completionHandler: nil)
        #endif
    }

    private override init() {
        super.init()
        // Note: We intentionally avoid calling into the GoogleMobileAds SDK here
        // to prevent build issues across configurations. Using the official test
        // ad unit ID ensures test ads in Simulator and on devices.
    }

    /// Preloads an ad for a specific placement.
    func preloadAd(for placement: String) {
        // Ensure we are on the main thread and the SDK is initialized before loading.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.preloadAd(for: placement)
            }
            return
        }

        switch adStates[placement] ?? .idle {
        case .loading, .loaded:
            print("[AdService] Skipping preload for \(placement); state already active")
            return
        case .idle, .failed:
            break
        }

        ensureSDKStarted()

        adStates[placement] = .loading
        print("[AdService] Preloading native ad for placement: \(placement) | simulator: \(isSimulator)")
        let adLoader = AdLoader(
            adUnitID: testAdUnitID, // Use real ID in production
            rootViewController: currentRootViewController() ?? UIViewController(),
            adTypes: [.native],
            options: []
        )
        adLoader.delegate = self
        adLoaders[placement] = adLoader
        adLoader.load(Request())
    }

    /// Returns the preloaded ad for a placement, or nil.
    func ad(for placement: String) -> NativeAd? {
        nativeAds[placement]
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}

// MARK: - NativeAdLoaderDelegate

extension AdService: NativeAdLoaderDelegate, AdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("[AdService] Received native ad")
        // Find which placement this loader was for
        if let placement = adLoaders.first(where: { $0.value === adLoader })?.key {
            DispatchQueue.main.async {
                self.nativeAds[placement] = nativeAd
                self.adStates[placement] = .loaded
            }
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("[AdService] AdMob failed to load ad: \(error.localizedDescription)")
        Analytics.shared.logError(error, context: "AdMob_Load_Fail")
        if let placement = adLoaders.first(where: { $0.value === adLoader })?.key {
            DispatchQueue.main.async {
                self.adStates[placement] = .failed(error.localizedDescription)
            }
            print("[AdService] Placement \(placement) failed to load")
        }
    }
}
