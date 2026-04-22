import SwiftUI
import MapKit

/// Return Mode — the in-store screen. Rendered as an urgent "field briefing":
/// big serif countdown at the top, address and map, printed requirements
/// checklist. Designed to be legible at arm's length.
struct ReturnModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.colorSchemeContrast) private var contrast

    let item: ReceiptItem
    @State private var storeLocation: CLLocationCoordinate2D?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var receiptImage: UIImage?
    @State private var itemPhoto: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    briefingHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)

                    countdownBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    storeBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                    if !item.returnRequirements.isEmpty {
                        requirementsBlock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)
                    }

                    policyBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    if receiptImage != nil || itemPhoto != nil {
                        RFPerforation().padding(.horizontal, 20).padding(.bottom, 24)

                        imagesBlock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }

                    Spacer().frame(height: 80)
                }
            }
            .background(RFColors.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)
                }
            }
            .task {
                await searchStoreLocation()
                itemPhoto = await ImageStorageService.shared.loadItemImage(for: item)
                receiptImage = await ImageStorageService.shared.loadReceiptImage(for: item)
            }
        }
    }

    // MARK: - Briefing Header

    private var briefingHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("FIELD BRIEFING")
                    .font(RFFont.mono(10))
                    .tracking(2.0)
                    .foregroundStyle(RFColors.signal)
                Spacer()
                Text("RETURN MODE")
                    .font(RFFont.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(RFColors.mute)
            }
            .accessibilityHidden(true)

            Rectangle().fill(RFColors.signal).frame(height: 2)
                .accessibilityHidden(true)

            Text(item.productName)
                .font(RFFont.hero(40))
                .foregroundStyle(RFColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            HStack(spacing: 0) {
                Text("at ")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Text(item.storeName)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)
                if item.priceCents > 0 {
                    Text(" · ")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.mute)
                    Text(item.formattedPrice)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(RFColors.ink)
                }
                Spacer()
            }

            RFHairline()
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Return Mode field briefing for \(item.productName) at \(item.storeName)")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Countdown block
    //
    // Huge serif numeral at the top of the briefing. At arm's length, this
    // is the only number you need to see.

    private var countdownBlock: some View {
        VStack(spacing: 10) {
            Text("TIME TO RETURN")
                .font(RFFont.mono(11))
                .tracking(2.4)
                .foregroundStyle(RFColors.mute)
                .accessibilityHidden(true)

            if let days = item.returnDaysRemaining {
                if days == 0 {
                    Text("TODAY")
                        .font(RFFont.hero(96))
                        .tracking(6)
                        .foregroundStyle(RFColors.signal)
                        .accessibilityHidden(true)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Text("\(days)")
                            .font(.system(size: 144, weight: .regular, design: .serif))
                            .foregroundStyle(countdownColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(days == 1 ? "DAY" : "DAYS")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(countdownColor)
                    }
                    .accessibilityHidden(true)
                }

                if let endDate = item.returnWindowEndDate {
                    Text("DEADLINE · \(endDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())")
                        .font(RFFont.mono(10))
                        .tracking(1.6)
                        .foregroundStyle(RFColors.mute)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(countdownAccessibilityLabel)
    }

    private var countdownColor: Color {
        guard let days = item.returnDaysRemaining else { return RFColors.ink }
        if days <= 3 { return RFColors.signal }
        return RFColors.ink
    }

    private var countdownAccessibilityLabel: String {
        guard let days = item.returnDaysRemaining else { return "Return window closed" }
        if days == 0 { return "Last day to return" }
        let deadlineText: String
        if let endDate = item.returnWindowEndDate {
            deadlineText = ", deadline \(endDate.formatted(date: .long, time: .omitted))"
        } else {
            deadlineText = ""
        }
        return "\(days) day\(days == 1 ? "" : "s") left to return\(deadlineText)"
    }

    // MARK: - Store block

    private var storeBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Destination")

            HStack(spacing: 12) {
                StoreAvatar(name: item.storeName, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.storeName)
                        .font(RFFont.serifBody(18))
                        .foregroundStyle(RFColors.ink)

                    if let address = item.storeAddress {
                        Text(address)
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(RFColors.mute)
                    }
                }
                Spacer()
            }

            if let location = storeLocation {
                Map(position: $mapPosition) {
                    Marker(item.storeName, coordinate: location)
                        .tint(RFColors.signal)
                }
                .frame(height: 180)
                .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
            }
        }
    }

    // MARK: - Requirements block

    private var requirementsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Bring with you")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(item.returnRequirements, id: \.self) { req in
                    HStack(alignment: .top, spacing: 12) {
                        Text("☐")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(RFColors.ink)
                        Text(req)
                            .font(RFFont.serifBody(16))
                            .foregroundStyle(RFColors.ink)
                    }
                }
            }
        }
    }

    // MARK: - Policy block

    private var policyBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Policy")

            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(RFColors.ink)
                    .frame(width: 2)

                Text(item.returnPolicyDescription.isEmpty
                     ? "Confirm with the store clerk on arrival."
                     : "\u{201C}\(item.returnPolicyDescription)\u{201D}")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.ink)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Images block

    private var imagesBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let photo = itemPhoto {
                VStack(alignment: .leading, spacing: 10) {
                    RFEyebrow(text: "Item photograph")
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
                        .accessibilityLabel("Photo of \(item.productName)")
                }
            }

            if let image = receiptImage {
                VStack(alignment: .leading, spacing: 10) {
                    RFEyebrow(text: "Original receipt")
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 320)
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().stroke(RFColors.ink, lineWidth: 0.75))
                        .accessibilityLabel("Receipt photo for \(item.productName) from \(item.storeName)")
                }
            }
        }
    }

    // MARK: - Location lookup

    private func searchStoreLocation() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = item.storeName
        if let address = item.storeAddress {
            request.naturalLanguageQuery = "\(item.storeName) \(address)"
        }

        let search = MKLocalSearch(request: request)
        if let response = try? await search.start(),
           let mapItem = response.mapItems.first {
            storeLocation = mapItem.placemark.coordinate
            mapPosition = .region(MKCoordinateRegion(
                center: mapItem.placemark.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
}
