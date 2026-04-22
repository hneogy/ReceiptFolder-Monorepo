import SwiftUI
import SwiftData
import Charts

/// Insights — rendered as the "business desk" page of the receipt folder.
/// Monochrome ink bars on cream, tabular spend columns, block-quoted
/// recommendations. No pie charts, no color legends.
struct InsightsView: View {
    @Query(filter: #Predicate<ReceiptItem> { !$0.isArchived }, sort: \ReceiptItem.purchaseDate, order: .reverse)
    private var items: [ReceiptItem]

    @Environment(\.legibilityWeight) private var legibilityWeight

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    masthead
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    headlineStats
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    if !recommendations.isEmpty {
                        recommendationsBlock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        RFPerforation()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }

                    spendingChart
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    storeLedger
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    RFPerforation()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    warrantyBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                }
            }
            .background(RFColors.paper)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 10) {
            HStack {
                Text("BUSINESS DESK")
                    .font(RFFont.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(RFColors.mute)
                Spacer()
                Text(Date.now.formatted(.dateTime.year().month(.wide)).uppercased())
                    .font(RFFont.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(RFColors.mute)
            }

            Rectangle().fill(RFColors.ink).frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("The")
                    .font(RFFont.hero(52))
                    .foregroundStyle(RFColors.ink)
                Text("Ledger")
                    .font(.system(size: 52, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.signal)
                Spacer()
            }

            HStack {
                Text(subtitleText)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                Spacer()
            }

            RFHairline()
                .padding(.top, 2)
        }
    }

    private var subtitleText: String {
        if items.isEmpty { return "No purchases on record." }
        if currentMonthItemCount == 0 { return "No purchases this month." }
        let totals = totalSpendingFormatted.isEmpty ? "" : ", totaling \(totalSpendingFormatted)"
        return "\(currentMonthItemCount) \(currentMonthItemCount == 1 ? "item" : "items") logged this month\(totals)."
    }

    // MARK: - Headline Stats

    private var headlineStats: some View {
        HStack(spacing: 0) {
            statColumn(label: "On File", value: "\(items.count)", isMoney: false)
            verticalRule
            statColumn(label: "Returned", value: "\(returnedCount)", isMoney: false, accent: returnedCount > 0)
            verticalRule
            statColumn(label: "Recovered", value: moneySavedFormatted, isMoney: true)
        }
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(RFColors.rule)
            .frame(width: 0.5, height: 60)
    }

    private func statColumn(label: String, value: String, isMoney: Bool, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.mute)

            Text(value)
                .font(.system(size: isMoney ? 24 : 36, weight: .regular, design: .serif))
                .foregroundStyle(accent ? RFColors.signal : RFColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    // MARK: - Recommendations
    //
    // Rendered as serif pull quotes with a red initial cap for the first one.

    @ViewBuilder
    private var recommendationsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "From the desk")

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(recommendations.prefix(3).enumerated()), id: \.offset) { index, rec in
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle()
                            .fill(rec.urgent ? RFColors.signal : RFColors.ink)
                            .frame(width: 2)

                        Text(rec.text)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(RFColors.ink)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if index < min(recommendations.count, 3) - 1 {
                        RFHairline()
                    }
                }
            }
        }
    }

    // MARK: - Spending Chart
    //
    // Monochrome ink bars on cream, thin tick marks, mono axis labels.

    private var spendingChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Monthly Spending")

            if monthlySpending.isEmpty {
                Text("No purchase data on record.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(monthlySpending, id: \.month) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", Double(item.totalCents) / 100.0),
                        width: .ratio(0.5)
                    )
                    .foregroundStyle(RFColors.ink)
                    .cornerRadius(0)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            .foregroundStyle(RFColors.rule)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0)))
                                    .font(RFFont.mono(9))
                                    .foregroundStyle(RFColors.mute)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(RFFont.mono(9))
                            .foregroundStyle(RFColors.mute)
                    }
                }
                .frame(height: 200)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(spendingChartAccessibilityLabel)
            }
        }
    }

    // MARK: - Store Ledger
    //
    // Replaces the donut chart. Tabular ledger of stores with dot-leaders.

    private var storeLedger: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                RFEyebrow(text: "By Merchant")
                Spacer()
                Text("TOTAL")
                    .font(RFFont.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(RFColors.mute)
            }

            RFHairline()

            if storeSpending.isEmpty {
                Text("No purchases recorded.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(RFColors.mute)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(storeChartData.prefix(8).enumerated()), id: \.offset) { index, entry in
                        storeLedgerRow(entry: entry, total: totalStoreSpending)

                        if index < min(storeChartData.count, 8) - 1 {
                            RFHairline()
                        }
                    }
                }
            }
        }
    }

    private func storeLedgerRow(entry: StoreSpend, total: Int) -> some View {
        let percent = total > 0 ? Double(entry.totalCents) / Double(total) : 0
        let formatted = (Double(entry.totalCents) / 100.0).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.store)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(RFColors.ink)

                LeaderDots()

                Text(formatted)
                    .font(RFFont.monoMedium(13))
                    .foregroundStyle(RFColors.ink)
            }

            HStack {
                Rectangle()
                    .fill(RFColors.ink)
                    .frame(width: max(0, CGFloat(percent) * 240), height: 1)
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(RFFont.mono(10))
                    .foregroundStyle(RFColors.mute)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.store): \(formatted), \(Int(percent * 100)) percent")
    }

    // MARK: - Warranty Block
    //
    // Three numerals in ember ink, labelled like a weather almanac.

    private var warrantyBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            RFEyebrow(text: "Warranty Almanac")

            HStack(spacing: 0) {
                warrantyColumn(label: "Active", value: activeWarranties)
                verticalRule
                warrantyColumn(label: "Expiring", value: expiringWarranties, accent: expiringWarranties > 0)
                verticalRule
                warrantyColumn(label: "Expired", value: expiredWarranties)
            }
        }
    }

    private func warrantyColumn(label: String, value: Int, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(RFFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(RFColors.mute)

            Text("\(value)")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(accent ? RFColors.ember : RFColors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Recommendations data

    private struct Recommendation {
        let text: String
        let urgent: Bool
    }

    private var recommendations: [Recommendation] {
        var recs: [Recommendation] = []

        let expiringThisWeek = items.filter {
            guard let days = $0.returnDaysRemaining else { return false }
            return days >= 0 && days <= 7 && !$0.isReturned
        }
        if !expiringThisWeek.isEmpty {
            let totalValue = expiringThisWeek.reduce(0) { $0 + $1.priceCents }
            let dollars = Double(totalValue) / 100.0
            let formatted = dollars.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
            recs.append(Recommendation(
                text: "\(expiringThisWeek.count) \(expiringThisWeek.count == 1 ? "item" : "items") worth \(formatted) will close this week. Review the urgent desk.",
                urgent: true
            ))
        }

        let returnedItems = items.filter { $0.isReturned }
        if !returnedItems.isEmpty {
            let saved = returnedItems.reduce(0) { $0 + $1.priceCents }
            let dollars = Double(saved) / 100.0
            let formatted = dollars.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
            recs.append(Recommendation(
                text: "You have recovered \(formatted) by returning \(returnedItems.count) \(returnedItems.count == 1 ? "item" : "items").",
                urgent: false
            ))
        }

        let storeCounts = Dictionary(grouping: items, by: \.storeName).mapValues(\.count)
        if let topStore = storeCounts.max(by: { $0.value < $1.value }), topStore.value >= 2 {
            if let policy = StorePolicyService.shared.findPolicy(storeName: topStore.key) {
                recs.append(Recommendation(
                    text: "\(topStore.key) is your most-shopped merchant, with \(topStore.value) items on file. Their \(policy.defaultReturnDays)-day return window offers notable flexibility.",
                    urgent: false
                ))
            }
        }

        let expiredItems = items.filter {
            !$0.isArchived && !$0.isReturned &&
            ($0.returnDaysRemaining == nil || $0.returnDaysRemaining == 0) &&
            ($0.warrantyDaysRemaining == nil || $0.warrantyDaysRemaining == 0)
        }
        if expiredItems.count >= 3 {
            recs.append(Recommendation(
                text: "Consider archiving \(expiredItems.count) items whose windows have closed.",
                urgent: false
            ))
        }

        return recs
    }

    // MARK: - Accessibility labels

    private var spendingChartAccessibilityLabel: String {
        guard !monthlySpending.isEmpty else { return "Monthly spending chart, no data" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let descriptions = monthlySpending.map { item in
            "\(formatter.string(from: item.month)): \((Double(item.totalCents) / 100.0).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))"
        }
        return "Monthly spending bar chart. \(descriptions.joined(separator: ", "))"
    }

    // MARK: - Computed

    private var currentMonthItemCount: Int {
        let calendar = Calendar.current
        let now = Date.now
        return items.filter { calendar.isDate($0.purchaseDate, equalTo: now, toGranularity: .month) }.count
    }

    private var totalSpendingFormatted: String {
        let calendar = Calendar.current
        let now = Date.now
        let cents = items
            .filter { calendar.isDate($0.purchaseDate, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.priceCents }
        guard cents > 0 else { return "" }
        return (Double(cents) / 100.0).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    private struct MonthlySpend {
        let month: Date
        let totalCents: Int
    }

    private struct StoreSpend {
        let store: String
        let totalCents: Int
    }

    private var monthlySpending: [MonthlySpend] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.dateInterval(of: .month, for: item.purchaseDate)?.start ?? item.purchaseDate
        }
        return grouped.map { MonthlySpend(month: $0.key, totalCents: $0.value.reduce(0) { $0 + $1.priceCents }) }
            .sorted { $0.month < $1.month }
            .suffix(12)
            .map { $0 }
    }

    private var storeSpending: [StoreSpend] {
        let grouped = Dictionary(grouping: items) { $0.storeName }
        return grouped.map { StoreSpend(store: $0.key, totalCents: $0.value.reduce(0) { $0 + $1.priceCents }) }
            .sorted { $0.totalCents > $1.totalCents }
    }

    private var storeChartData: [StoreSpend] {
        let top = Array(storeSpending.prefix(8))
        let otherTotal = storeSpending.dropFirst(8).reduce(0) { $0 + $1.totalCents }
        if otherTotal > 0 {
            return top + [StoreSpend(store: "Other", totalCents: otherTotal)]
        }
        return top
    }

    private var totalStoreSpending: Int {
        storeSpending.reduce(0) { $0 + $1.totalCents }
    }

    private var returnedCount: Int {
        items.filter(\.isReturned).count
    }

    private var moneySavedFormatted: String {
        let cents = items.filter(\.isReturned).reduce(0) { $0 + $1.priceCents }
        return (Double(cents) / 100.0).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    private var activeWarranties: Int {
        items.filter {
            guard let days = $0.warrantyDaysRemaining else { return false }
            return days > 90 && !$0.isWarrantyClaimed
        }.count
    }

    private var expiringWarranties: Int {
        items.filter {
            guard let days = $0.warrantyDaysRemaining else { return false }
            return days > 0 && days <= 90
        }.count
    }

    private var expiredWarranties: Int {
        items.filter {
            guard let endDate = $0.warrantyEndDate else { return false }
            return endDate < .now && !$0.isWarrantyClaimed
        }.count
    }
}
