// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import UniformTypeIdentifiers

/// The controls of the export dialog (accessory of the save panel, after
/// Tagwerk's `show_export`): preset range, from and to, a summary of the
/// range with the figures of the file, and the format.
final class RecordsExportAccessory: NSObject {
    let view: NSView
    weak var panel: NSSavePanel?
    private weak var model: RecordsModel?
    private let preset = NSPopUpButton()
    private let fromPicker = NSDatePicker()
    private let toPicker = NSDatePicker()
    private let format = NSPopUpButton()
    private let summary = NSTextField(labelWithString: "")
    private let presets: [TTExportPreset] = TTExportPreset.allCases

    init(model: RecordsModel) {
        self.model = model
        let s = model.strings
        let texts = model.texts
        let today = TimeTrackingService.shared.now().date
        let stack = NSStackView()
        view = stack
        super.init()

        for (i, p) in presets.enumerated() {
            if p == .custom { preset.menu?.addItem(.separator()) }
            preset.addItem(withTitle: p.label(s))
            preset.lastItem?.tag = i
        }
        preset.selectItem(withTag: 0)
        preset.target = self
        preset.action = #selector(presetChosen(_:))
        let range = TTExportPreset.lastFourWeeks.range(today: today) ?? (today, today)
        for (picker, date) in [(fromPicker, range.from), (toPicker, range.to)] {
            picker.datePickerStyle = .textFieldAndStepper
            picker.datePickerElements = .yearMonthDay
            picker.locale = RecordsTime.locale
            picker.calendar = RecordsTime.calendar
            picker.timeZone = RecordsTime.calendar.timeZone
            picker.isBezeled = true
            picker.drawsBackground = true
            picker.dateValue = RecordsTime.date(date, 12 * 3600)
            picker.target = self
            picker.action = #selector(rangeChanged(_:))
        }
        for f in TTExportFormat.allCases { format.addItem(withTitle: f.label(texts)) }
        format.target = self
        format.action = #selector(formatChosen(_:))
        summary.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        summary.textColor = .secondaryLabelColor

        func caption(_ text: String) -> NSTextField {
            let label = NSTextField(labelWithString: text)
            label.alignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 70).isActive = true
            return label
        }
        func row(_ views: [NSView]) -> NSStackView {
            let row = NSStackView(views: views)
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 8
            return row
        }
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        stack.addArrangedSubview(row([caption(s.periodLabel), preset]))
        stack.addArrangedSubview(row([caption(s.fromLabel), fromPicker, NSTextField(labelWithString: s.to), toPicker]))
        stack.addArrangedSubview(row([caption(""), summary]))
        stack.addArrangedSubview(row([caption(s.formatLabel), format]))
        stack.translatesAutoresizingMaskIntoConstraints = true
        let size = stack.fittingSize
        stack.setFrameSize(NSSize(width: Swift.max(size.width, 460), height: size.height))
    }

    /// The chosen range, earliest day first.
    var range: (from: TTDate, to: TTDate) {
        let a = RecordsTime.day(fromPicker.dateValue), b = RecordsTime.day(toPicker.dateValue)
        return (Swift.min(a, b), Swift.max(a, b))
    }

    var chosenFormat: TTExportFormat {
        let all = TTExportFormat.allCases
        return all.indices.contains(format.indexOfSelectedItem) ? all[format.indexOfSelectedItem] : .markdown
    }

    /// Range or format changed: summary and file name follow.
    func update() {
        guard let model else { return }
        let (from, to) = range
        // The same figures as in the file.
        let report = TTReport(model.days, from: from, to: to, today: TimeTrackingService.shared.now().date,
                              settings: model.settings, model.texts)
        summary.stringValue = TTRecords.exportSummary(report, model.strings)
        summary.sizeToFit()
        let format = chosenFormat
        if let type = UTType(filenameExtension: format.fileExtension) { panel?.allowedContentTypes = [type] }
        panel?.nameFieldStringValue = TTExport.fileName(from: from, to: to, format: format)
    }

    @objc private func presetChosen(_ sender: NSPopUpButton) {
        let today = TimeTrackingService.shared.now().date
        if presets.indices.contains(sender.selectedTag()), let range = presets[sender.selectedTag()].range(today: today) {
            fromPicker.dateValue = RecordsTime.date(range.from, 12 * 3600)
            toPicker.dateValue = RecordsTime.date(range.to, 12 * 3600)
        }
        update()
    }

    @objc private func rangeChanged(_ sender: Any?) {
        if let custom = presets.firstIndex(of: .custom) { preset.selectItem(withTag: custom) }
        update()
    }

    @objc private func formatChosen(_ sender: Any?) {
        update()
    }
}

extension RecordsModel {
    // MARK: Export

    /// "Export…": the save panel with range and format.
    func showExport() {
        guard let window, window.attachedSheet == nil, exportAccessory == nil else { return }
        let s = strings
        let panel = NSSavePanel()
        panel.title = s.export
        panel.message = s.exportMessage
        panel.prompt = s.export
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if let downloads, FileManager.default.fileExists(atPath: downloads.path) { panel.directoryURL = downloads }
        let accessory = RecordsExportAccessory(model: self)
        accessory.panel = panel
        panel.accessoryView = accessory.view
        exportAccessory = accessory
        accessory.update()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.exportAccessory = nil
            guard response == .OK, let url = panel.url else { return }
            panel.orderOut(nil)
            self.export(to: url, range: accessory.range, format: accessory.chosenFormat)
        }
    }

    /// Writes the export with the current data (all days: the day before for
    /// the rest period, the first recorded day for the workdays without an entry).
    private func export(to url: URL, range: (from: TTDate, to: TTDate), format: TTExportFormat) {
        let (s, texts) = (strings, self.texts)
        let result: Result<Void, Error>
        do {
            let state = try TimeTrackingService.shared.recordsState()
            let report = { TTReport(state.days, from: range.from, to: range.to, today: state.now.date,
                                    settings: state.settings, texts) }
            switch format {
            case .markdown:
                let text = TTExport.markdown(state.days, from: range.from, to: range.to, now: state.now,
                                             settings: state.settings, appName: AppInfo.name, texts)
                try Data(text.utf8).write(to: url, options: .atomic)
            case .csv:
                try Data(TTExport.csv(report(), texts).utf8).write(to: url, options: .atomic)
            case .pdf:
                try TimeTrackingPDF.write(report(), settings: state.settings, now: state.now, appName: AppInfo.name,
                                          texts, s, to: url)
            }
            result = .success(())
        } catch {
            result = .failure(error)
        }
        switch result {
        case .success:
            let text = String(format: s.exportSavedFormat, TTFormat.day(range.from, texts), TTFormat.day(range.to, texts),
                              url.lastPathComponent)
            ask(s.exportSavedTitle, text, buttons: [AlertButton(s.ok, isDefault: true), AlertButton(s.showInFinder)],
                style: .informational) { i in
                if i == 1 { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        case let .failure(error):
            ask(s.exportFailedTitle, String(format: s.writeFailedFormat, error.localizedDescription),
                buttons: [AlertButton(s.ok, isDefault: true)]) { _ in }
        }
    }

    // MARK: Import

    /// "Import…": choose a Markdown export, ask, take the days over.
    func showImport() {
        guard let window, window.attachedSheet == nil else { return }
        let s = strings
        let panel = NSOpenPanel()
        panel.title = s.importLabel
        panel.message = s.importMessage
        panel.prompt = s.open
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType.plainText].compactMap { $0 }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            panel.orderOut(nil)
            self?.confirmImport(url)
        }
    }

    /// Reads the file and asks before replacing days. Days the window would
    /// not allow either (times in the future, a start not before the end, a
    /// full-day absence next to entries) are skipped and named.
    private func confirmImport(_ url: URL) {
        let (s, texts) = (strings, self.texts)
        let name = url.lastPathComponent
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            showSheetLater(s.importFailedTitle, String(format: s.importReadFailedFormat, name, error.localizedDescription),
                           style: .warning)
            return
        }
        let checked = TTImport.check(TTImport.parseFile(text), now: TimeTrackingService.shared.now())
        let skipped = checked.skippedText(texts)
        let days = checked.days
        guard let first = days.first?.date, let last = days.last?.date else {
            if skipped.isEmpty {
                showSheetLater(s.noRecordsTitle, String(format: s.noRecordsFormat, name))
            } else {
                showSheetLater(s.nothingToImportTitle, String(format: s.nothingToImportFormat, name, skipped))
            }
            return
        }
        func count(_ n: Int) -> String { String(format: n == 1 ? s.importDaysOneFormat : s.importDaysManyFormat, n) }
        let existing = days.filter { day($0.date) != nil }.count
        let title = String(format: s.importConfirmFormat, count(days.count), TTFormat.day(first, texts),
                           TTFormat.day(last, texts))
        var info = existing == 0 ? s.importNoExisting : String(format: s.importExistingFormat, count(existing))
        if !skipped.isEmpty { info += " " + skipped }
        info += " " + s.importBackupNote
        ask(title, info, buttons: [AlertButton(s.importLabel, isDefault: true), AlertButton(s.cancel, isCancel: true)],
            style: .informational) { [weak self] i in
            guard i == 0, let self else { return }
            do {
                let backup = try TimeTrackingService.shared.importDays(days)
                // Undo would refer to the state before the import.
                self.reloadAfterImport()
                let imported = count(days.count)
                let done = backup.map { String(format: s.importedBackupFormat, imported, $0.lastPathComponent) }
                    ?? String(format: s.importedFormat, imported)
                self.showSheetLater(s.importDoneTitle, done)
            } catch {
                self.showSheetLater(s.importFailedTitle, String(describing: error), style: .warning)
            }
        }
    }
}
