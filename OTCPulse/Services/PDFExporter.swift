//
//  PDFExporter.swift
//  OTC Pulse
//
//  Renders a daily snapshot to a shareable PDF (dark-branded report):
//  header with date + stats, followed by every publication of the day.
//

import UIKit

@MainActor
enum PDFExporter {

    // nonisolated: referenced from nested helper functions inside the PDF
    // renderer closure, which don't inherit the enum's MainActor isolation.
    private nonisolated static let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
    private nonisolated static let margin: CGFloat = 40

    /// Renders the given day's publications to a PDF and returns the file URL.
    static func exportDailySnapshot(date: Date, publications: [Publication]) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        let highCount = publications.filter(\.isHighImpact).count

        let navy = UIColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1)
        let cyan = UIColor(red: 0, green: 0.94, blue: 1, alpha: 1)
        let white = UIColor(white: 0.94, alpha: 1)
        let grey = UIColor(white: 0.62, alpha: 1)

        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0

            func newPage() {
                ctx.beginPage()
                navy.setFill()
                ctx.cgContext.fill(pageSize)
                y = margin
            }

            func draw(_ text: String, font: UIFont, color: UIColor, spacing: CGFloat = 6) {
                let width = pageSize.width - margin * 2
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let bounds = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes, context: nil
                )
                if y + bounds.height > pageSize.height - margin { newPage() }
                (text as NSString).draw(
                    with: CGRect(x: margin, y: y, width: width, height: ceil(bounds.height)),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes, context: nil
                )
                y += ceil(bounds.height) + spacing
            }

            newPage()

            // Header
            draw("OTC PULSE", font: .systemFont(ofSize: 11, weight: .heavy), color: cyan, spacing: 2)
            draw("Daily Intelligence Snapshot", font: .systemFont(ofSize: 24, weight: .bold), color: white, spacing: 2)
            draw(Formatters.dayHeader.string(from: date), font: .systemFont(ofSize: 13), color: grey, spacing: 14)
            draw("\(publications.count) publications  ·  \(highCount) high-impact",
                 font: .systemFont(ofSize: 12, weight: .semibold), color: cyan, spacing: 18)

            // Body
            for pub in publications.sorted(by: { $0.impactScore > $1.impactScore }) {
                draw("\(pub.regulatorCode)  ·  \(pub.documentType)  ·  impact \(Formatters.score(pub.impactScore))",
                     font: .systemFont(ofSize: 9, weight: .bold),
                     color: pub.isHighImpact ? UIColor(red: 1, green: 0.3, blue: 0.43, alpha: 1) : cyan,
                     spacing: 3)
                draw(pub.title, font: .systemFont(ofSize: 12, weight: .semibold), color: white, spacing: 3)
                draw(pub.summary, font: .systemFont(ofSize: 9.5), color: grey, spacing: 4)
                if let deadlineDate = pub.deadlineDate, let label = pub.deadlineLabel {
                    draw("⏱ \(label): \(Formatters.shortDate.string(from: deadlineDate))",
                         font: .systemFont(ofSize: 9, weight: .medium), color: cyan, spacing: 4)
                }
                y += 8
            }
        }

        let filename = "OTCPulse-Snapshot-\(DailySnapshot.key(for: date)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
