import SwiftUI

// MARK: - Preset Model

struct MoonlightPreset: Codable, Identifiable {
    var id = UUID()
    var name: String

    // Basis
    var width: Int = 2560
    var height: Int = 1440
    var fps: Int = 240
    var bitrateKbps: Int = 500000
    var windowMode: String = "fullscreen"
    var vsync: Bool = true
    var framePacing: Bool = true

    // Audio
    var audioConfig: String = "2"
    var muteHostAudio: Bool = true
    var muteOnFocusLoss: Bool = false

    // Host
    var gameOptimizations: Bool = true
    var quitAppAfter: Bool = false

    // Eingabe
    var mouseAcceleration: Bool = false
    var touchscreenTrackpad: Bool = false
    var swapMouseButtons: Bool = false
    var reverseScroll: Bool = false

    // Controller
    var swapABXY: Bool = false
    var keepController: Bool = false
    var holdStartMouseMode: Bool = true
    var backgroundGamepad: Bool = false

    // Erweitert
    var videoDecoderSelection: Int = 0
    var hdr: Bool = false
    var yuv444: Bool = false
    var unlockBitrate: Bool = true
    var autoFindPCs: Bool = true
    var detectBlockedConnections: Bool = true
    var showStats: Bool = false

    // Oberfläche
    var showWarnings: Bool = true
    var discordRichPresence: Bool = true
    var disableScreensaver: Bool = true

    static var defaultPresets: [MoonlightPreset] {[
        MoonlightPreset(name: "Standard",          width: 2560, height: 1440, fps: 240, bitrateKbps: 500000),
        MoonlightPreset(name: "Unterwegs",         width: 1920, height: 1080, fps: 60,  bitrateKbps: 20000),
        MoonlightPreset(name: "4K Kino",           width: 3840, height: 2160, fps: 60,  bitrateKbps: 150000, vsync: true),
        MoonlightPreset(name: "MacBook Air M1",          width: 1920, height: 1200, fps: 60,  bitrateKbps: 30000),
        MoonlightPreset(name: "MacBook Pro M4",          width: 3024, height: 1964, fps: 120, bitrateKbps: 80000),
        MoonlightPreset(name: "MacBook Air M4",          width: 2560, height: 1664, fps: 120, bitrateKbps: 60000),
        MoonlightPreset(name: "MacBook Air M4 Unterwegs",width: 1280, height:  832, fps: 60,  bitrateKbps: 20000),
        MoonlightPreset(name: "MacBook Pro M4 Unterwegs",width: 1512, height:  982, fps: 60,  bitrateKbps: 20000),
    ]}
}

// MARK: - Preset Store

class MoonlightPresetStore: ObservableObject {
    static let shared = MoonlightPresetStore()
    @Published var presets: [MoonlightPreset] = []
    @Published var activeIndex: Int = 0
    @Published var appliedIndex: Int = -1
    private let key = "moonlightPresets"
    private let activeKey = "moonlightActivePreset"
    private let appliedKey = "moonlightAppliedPreset"

    init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([MoonlightPreset].self, from: data) {
            presets = decoded
        } else {
            presets = MoonlightPreset.defaultPresets
        }
        activeIndex = min(UserDefaults.standard.integer(forKey: activeKey), presets.count - 1)
        appliedIndex = UserDefaults.standard.integer(forKey: appliedKey)
        if appliedIndex >= presets.count { appliedIndex = -1 }
    }

    func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: key)
        }
        UserDefaults.standard.set(activeIndex, forKey: activeKey)
        UserDefaults.standard.set(appliedIndex, forKey: appliedKey)
    }

    func addPreset(name: String) {
        var p = presets[safe: activeIndex] ?? MoonlightPreset(name: name)
        p.id = UUID()
        p.name = name
        presets.append(p)
        activeIndex = presets.count - 1
        save()
    }

    func deletePreset(at index: Int) {
        guard presets.count > 1 else { return }
        presets.remove(at: index)
        activeIndex = max(0, min(activeIndex, presets.count - 1))
        save()
    }

    var active: Binding<MoonlightPreset> {
        Binding(
            get: { self.presets[safe: self.activeIndex] ?? MoonlightPreset(name: "Standard") },
            set: { self.presets[safe: self.activeIndex] = $0; self.save() }
        )
    }

    func applyToMoonlight() {
        guard let preset = presets[safe: activeIndex] else { return }
        let domain = "com.moonlight-stream.Moonlight" as CFString

        func setPref(_ key: String, _ value: CFPropertyList) {
            CFPreferencesSetAppValue(key as CFString, value, domain)
        }

        setPref("width",                    preset.width as CFPropertyList)
        setPref("height",                   preset.height as CFPropertyList)
        setPref("fps",                      preset.fps as CFPropertyList)
        setPref("bitrateKbps",              preset.bitrateKbps as CFPropertyList)
        setPref("windowMode",               preset.windowMode as CFPropertyList)
        setPref("enableVsync",              preset.vsync as CFPropertyList)
        setPref("framePacing",              preset.framePacing as CFPropertyList)
        setPref("audioConfig",              preset.audioConfig as CFPropertyList)
        setPref("playAudioOnHost",          preset.muteHostAudio as CFPropertyList)
        setPref("muteOnFocusLoss",          preset.muteOnFocusLoss as CFPropertyList)
        setPref("gameOptimizations",        preset.gameOptimizations as CFPropertyList)
        setPref("quitAppAfter",             preset.quitAppAfter as CFPropertyList)
        setPref("mouseAcceleration",        preset.mouseAcceleration as CFPropertyList)
        setPref("swapMouseButtons",         preset.swapMouseButtons as CFPropertyList)
        setPref("reverseScrollDirection",   preset.reverseScroll as CFPropertyList)
        setPref("swapGamepadButtons",       preset.swapABXY as CFPropertyList)
        setPref("keepController",           preset.keepController as CFPropertyList)
        setPref("holdStartMouseMode",       preset.holdStartMouseMode as CFPropertyList)
        setPref("backgroundGamepad",        preset.backgroundGamepad as CFPropertyList)
        setPref("videoDecoderSelection",    preset.videoDecoderSelection as CFPropertyList)
        setPref("enableHdr",                preset.hdr as CFPropertyList)
        setPref("enableYUV444",             preset.yuv444 as CFPropertyList)
        setPref("unlockBitrate",            preset.unlockBitrate as CFPropertyList)
        setPref("autoFindPCs",              preset.autoFindPCs as CFPropertyList)
        setPref("detectBlockedConnections", preset.detectBlockedConnections as CFPropertyList)
        setPref("showStats",                preset.showStats as CFPropertyList)
        setPref("showWarnings",             preset.showWarnings as CFPropertyList)
        setPref("discordRichPresence",      preset.discordRichPresence as CFPropertyList)
        setPref("disableScreensaver",       preset.disableScreensaver as CFPropertyList)

        CFPreferencesAppSynchronize(domain)
        appliedIndex = activeIndex
        save()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        get { indices.contains(index) ? self[index] : nil }
        set { if let v = newValue, indices.contains(index) { self[index] = v } }
    }
}

// MARK: - Main View

struct MoonlightSettingsTab: View {
    @ObservedObject var store = MoonlightPresetStore.shared
    @State private var showingAddPreset = false
    @State private var newPresetName = ""
    @State private var saved = false
    @State private var showingTemplates = false


    let resolutions = [(1920,1080,"1080p"), (2560,1440,"1440p"), (3840,2160,"4K"), (0,0,"Benutzerdefiniert")]
    let fpsOptions = [30, 60, 120, 144, 240]
    let windowModes = [("fullscreen","Vollbild"), ("windowed","Fenster"), ("borderless","Randlos")]
    let audioConfigs = [("2","Stereo"), ("6","5.1"), ("8","7.1")]
    let decoders = [(0,"Automatisch"), (1,"Hardware"), (2,"Software")]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Preset Tabs
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(store.presets.indices, id: \.self) { i in
                            presetTab(i)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // Preset hinzufügen
                Button(action: { newPresetName = "Neues Preset"; showingAddPreset = true }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
                .buttonStyle(.plain)

                // Vorlage hinzufügen
                Menu {
                    ForEach(MoonlightPreset.defaultPresets, id: \.name) { template in
                        let exists = store.presets.contains(where: { $0.name == template.name })
                        Button(action: {
                            if !exists {
                                store.presets.append(template)
                                store.activeIndex = store.presets.count - 1
                                store.save()
                            }
                        }) {
                            Label(
                                exists ? "✓ \(template.name)" : template.name,
                                systemImage: exists ? "checkmark" : "rectangle.badge.plus"
                            )
                        }
                        .disabled(exists)
                    }
                } label: {
                    Image(systemName: "square.stack.badge.plus")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
            .padding(.top, 4)
            .padding(.bottom, 8)

            Divider()

            // Preset Inhalt
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let preset = store.presets[safe: store.activeIndex] {
                        presetContent(preset)
                    }
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                if store.presets.count > 1 {
                    Button(role: .destructive, action: { store.deletePreset(at: store.activeIndex) }) {
                        Label("Preset löschen", systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
                Spacer()
                if saved {
                    Label("Gespeichert & angewendet", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.system(size: 11))
                }
                Button("Speichern & Anwenden") {
                    store.save()
                    store.applyToMoonlight()
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.rogueRed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showingAddPreset) {
            VStack(spacing: 16) {
                Text("Neues Preset").font(.headline)
                TextField("Name", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                HStack {
                    Button("Abbrechen") { showingAddPreset = false }.keyboardShortcut(.escape)
                    Button("Erstellen") {
                        store.addPreset(name: newPresetName)
                        showingAddPreset = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPresetName.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 300)
        }
    }

    private func presetTab(_ i: Int) -> some View {
        let isSelected = store.activeIndex == i
        let isApplied  = store.appliedIndex == i

        return Button(action: { store.activeIndex = i }) {
            HStack(spacing: 4) {
                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                Text(store.presets[i].name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? Color.rogueRed.opacity(0.15)
                          : Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isApplied ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? Color.rogueRed : .secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func presetContent(_ preset: MoonlightPreset) -> some View {
        let binding = store.active

        // Basis
        settingsGroup("BASIS") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auflösung").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    let standardRes = resolutions.dropLast().map { ($0.0, $0.1) }
                    let isCustom = !standardRes.contains(where: { $0.0 == preset.width && $0.1 == preset.height })
                    Picker("", selection: Binding(
                        get: { isCustom ? "custom" : "\(preset.width)x\(preset.height)" },
                        set: { val in
                            if val == "custom" {
                                // keep current values, just switch mode
                            } else if let r = resolutions.first(where: { "\($0.0)x\($0.1)" == val }) {
                                binding.wrappedValue.width = r.0
                                binding.wrappedValue.height = r.1
                            }
                        }
                    )) {
                        ForEach(resolutions.dropLast(), id: \.2) { Text($0.2).tag("\($0.0)x\($0.1)") }
                        Text("Benutzerdefiniert").tag("custom")
                    }.frame(width: 150)
                    if isCustom {
                        HStack(spacing: 4) {
                            TextField("Breite", value: binding.width, format: .number)
                                .frame(width: 65).textFieldStyle(.roundedBorder)
                            Text("×").font(.system(size: 11))
                            TextField("Höhe", value: binding.height, format: .number)
                                .frame(width: 65).textFieldStyle(.roundedBorder)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("FPS").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Picker("", selection: binding.fps) {
                        ForEach(fpsOptions, id: \.self) { Text("\($0)").tag($0) }
                    }.frame(width: 80)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anzeigemodus").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Picker("", selection: binding.windowMode) {
                        ForEach(windowModes, id: \.0) { Text($0.1).tag($0.0) }
                    }.frame(width: 110)
                }
            }.padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Bitrate: \(preset.bitrateKbps / 1000) Mbps").font(.system(size: 12)).padding(.horizontal, 16)
                Slider(value: Binding(
                    get: { Double(preset.bitrateKbps) },
                    set: { binding.wrappedValue.bitrateKbps = Int($0) }
                ), in: 5000...150000, step: 1000).padding(.horizontal, 16)
            }

            HStack(spacing: 20) {
                Toggle("VSync", isOn: binding.vsync)
                Toggle("Frame Pacing", isOn: binding.framePacing)
                Toggle("Bitrate-Limit aufheben", isOn: binding.unlockBitrate)
            }.padding(.horizontal, 16)
        }

        // Audio
        settingsGroup("AUDIO") {
            HStack(spacing: 20) {
                Picker("Kanal", selection: binding.audioConfig) {
                    ForEach(audioConfigs, id: \.0) { Text($0.1).tag($0.0) }
                }.frame(width: 140)
                Toggle("Host stumm", isOn: binding.muteHostAudio)
                Toggle("Stumm bei Fokus-Verlust", isOn: binding.muteOnFocusLoss)
            }.padding(.horizontal, 16)
        }

        // Host
        settingsGroup("HOST") {
            HStack(spacing: 20) {
                Toggle("Spieleinstellungen optimieren", isOn: binding.gameOptimizations)
                Toggle("App nach Stream beenden", isOn: binding.quitAppAfter)
            }.padding(.horizontal, 16)
        }

        // Eingabe & Controller
        settingsGroup("EINGABE & CONTROLLER") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 20) {
                    Toggle("Maustasten tauschen", isOn: binding.swapMouseButtons)
                    Toggle("Scrollrichtung umkehren", isOn: binding.reverseScroll)
                    Toggle("Touchscreen als Trackpad", isOn: binding.touchscreenTrackpad)
                }
                HStack(spacing: 20) {
                    Toggle("A/B und X/Y tauschen", isOn: binding.swapABXY)
                    Toggle("Controller immer verbunden", isOn: binding.keepController)
                    Toggle("Start halten = Maus", isOn: binding.holdStartMouseMode)
                }
            }.padding(.horizontal, 16)
        }

        // Erweitert
        settingsGroup("ERWEITERT") {
            HStack(spacing: 16) {
                Picker("Decoder", selection: binding.videoDecoderSelection) {
                    ForEach(decoders, id: \.0) { Text($0.1).tag($0.0) }
                }.frame(width: 200)
                Toggle("HDR", isOn: binding.hdr)
                Toggle("YUV 4:4:4", isOn: binding.yuv444)
                Toggle("Statistiken", isOn: binding.showStats)
            }.padding(.horizontal, 16)
        }
    }

    private func settingsGroup<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }
}
