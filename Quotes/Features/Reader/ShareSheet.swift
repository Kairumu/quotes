import SwiftUI
import UIKit

/// A thin `UIActivityViewController` wrapper for sharing capture images.
///
/// Presented from a sheet; works on both iPhone and iPad (the sheet host
/// provides a valid presentation context for the iPad popover).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Wraps a rendered capture image so it can drive a `.sheet(item:)` presentation.
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
