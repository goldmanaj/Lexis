import SwiftUI
import UIKit
import GoogleMobileAds

// MARK: - LexisNativeAdView (UIViewRepresentable)

/// A SwiftUI wrapper for AdMob's NativeAdView.
/// This allows us to style the ad data natively while satisfying
/// AdMob's requirements for impression tracking and click handling.
struct LexisNativeAdView: UIViewRepresentable {
    let nativeAd: NativeAd
    let compact: Bool

    func makeUIView(context: Context) -> NativeAdView {
        let nativeAdView = NativeAdView()
        
        // --- Headline ---
        let headlineLabel = UILabel()
        let georgia = UIFont(name: "Georgia", size: 15)
        headlineLabel.font = compact ? .systemFont(ofSize: 13, weight: .medium) : (georgia ?? .systemFont(ofSize: 15, weight: .medium))
        headlineLabel.textColor = UIColor(Color.lexisCream)
        headlineLabel.numberOfLines = 2
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.headlineView = headlineLabel
        
        // --- Body ---
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = UIColor(Color.lexisMuted)
        bodyLabel.numberOfLines = 3
        if !compact {
            nativeAdView.addSubview(bodyLabel)
            nativeAdView.bodyView = bodyLabel
        }
        
        // --- Call to Action ---
        let ctaLabel = UILabel()
        ctaLabel.font = .systemFont(ofSize: 11, weight: .medium)
        ctaLabel.textColor = UIColor(Color.lexisGold)
        nativeAdView.addSubview(ctaLabel)
        nativeAdView.callToActionView = ctaLabel
        
        // --- Ad Badge ---
        let adBadge = UILabel()
        adBadge.text = "AD"
        adBadge.font = .systemFont(ofSize: 7, weight: .bold)
        adBadge.textColor = UIColor(Color.lexisSubtle)
        adBadge.layer.borderColor = UIColor(Color.lexisBorder).cgColor
        adBadge.layer.borderWidth = 0.5
        adBadge.layer.cornerRadius = 2
        adBadge.textAlignment = .center
        nativeAdView.addSubview(adBadge)
        
        // --- Constraints ---
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        ctaLabel.translatesAutoresizingMaskIntoConstraints = false
        adBadge.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            adBadge.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 14),
            adBadge.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 14),
            adBadge.widthAnchor.constraint(equalToConstant: 16),
            adBadge.heightAnchor.constraint(equalToConstant: 10),
            
            headlineLabel.topAnchor.constraint(equalTo: adBadge.bottomAnchor, constant: 6),
            headlineLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 14),
            headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -14)
        ])
        
        if !compact {
            NSLayoutConstraint.activate([
                bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 8),
                bodyLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 14),
                bodyLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -14),
                ctaLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
                ctaLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -14),
                ctaLabel.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -14)
            ])
        } else {
            NSLayoutConstraint.activate([
                ctaLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 8),
                ctaLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -14),
                ctaLabel.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -10)
            ])
        }
        
        return nativeAdView
    }

    func updateUIView(_ nativeAdView: NativeAdView, context: Context) {
        nativeAdView.nativeAd = nativeAd
        
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        (nativeAdView.callToActionView as? UILabel)?.text = nativeAd.callToAction?.uppercased()
        
        nativeAdView.isUserInteractionEnabled = false
    }
}

// MARK: - AdSlotView

struct AdSlotView: View {
    let placement: String
    let compact: Bool

    @ObservedObject private var adService = AdService.shared

    init(placement: String, compact: Bool = false) {
        self.placement = placement
        self.compact = compact
    }

    var body: some View {
        Group {
            if LexisDemoMode.isEnabled {
                EmptyView()
            } else if let nativeAd = adService.ad(for: placement) {
                LexisNativeAdView(nativeAd: nativeAd, compact: compact)
                    .background(Color.lexisSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lexisBorder, lineWidth: 0.5))
            } else if isSimulator {
                SimulatorTestAdCard(placement: placement, compact: compact)
                    .onAppear {
                        let stateDescription = describe(adService.adStates[placement] ?? .idle)
                        print("[AdSlotView] Showing simulator fallback for \(placement) | state: \(stateDescription)")
                        adService.preloadAd(for: placement)
                    }
            } else {
                AdLoadingCard(compact: compact)
                    .onAppear {
                        let stateDescription = describe(adService.adStates[placement] ?? .idle)
                        print("[AdSlotView] No ad yet for \(placement) | state: \(stateDescription)")
                        adService.preloadAd(for: placement)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: slotHeight, alignment: .top)
        .clipped()
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private func describe(_ state: AdService.AdLoadState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .loading:
            return "loading"
        case .loaded:
            return "loaded"
        case .failed(let message):
            return "failed(\(message))"
        }
    }

    private var slotHeight: CGFloat {
        if LexisDemoMode.isEnabled {
            return 0
        }
        return compact ? 76 : 136
    }
}

private struct AdLoadingCard: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Text("AD")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.lexisSubtle)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.lexisBorder, lineWidth: 0.5))

            Text("Loading sponsor message...")
                .font(compact ? .system(size: 13, weight: .medium) : .lexisSerif(15))
                .foregroundColor(.lexisCream)

            if !compact {
                Text("An ad slot is reserved here while Google Mobile Ads finishes loading.")
                    .font(.system(size: 12))
                    .foregroundColor(.lexisMuted)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.lexisSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lexisBorder, lineWidth: 0.5))
    }
}

private struct SimulatorTestAdCard: View {
    let placement: String
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Text("TEST AD")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.lexisGold)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.lexisGold.opacity(0.5), lineWidth: 0.5))

            Text("Simulator sponsor placement")
                .font(compact ? .system(size: 13, weight: .medium) : .lexisSerif(15))
                .foregroundColor(.lexisCream)

            Text("Placement: \(placement)")
                .font(.system(size: 11))
                .foregroundColor(.lexisMuted)

            if !compact {
                Text("This fallback stays visible in Simulator until a live AdMob test native ad replaces it.")
                    .font(.system(size: 12))
                    .foregroundColor(.lexisMuted)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.lexisSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lexisBorder, lineWidth: 0.5))
    }
}
