import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newSymbolName: String = ""
    @State private var showAllSymbols: Bool = false
    @FocusState private var isSymbolFieldFocused: Bool

    var body: some View {
        NavigationSplitView {
            optionsInspector
                .frame(minWidth: 340)
                .padding(10)
        } detail: {
            ZStack {
                backgroundLayer

                VStack(spacing: 14) {
                    Spacer()
                    iconDropArea
                    Spacer()
                    topPathBar
                }
                .padding(10)
                .fontDesign(.rounded)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                Button {
                    model.revealSelectedFolderInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "arrow.forward.folder.fill")
                        .symbolEffect(.bounce.down.byLayer, options: .nonRepeating, value: model.revealBounceTrigger)
                }
                .disabled(model.selectedFolderURL == nil)
                Button {
                    model.resetFolderCustomization()
                } label: {
                    Label("Reset Folder Customization", systemImage: "arrow.trianglehead.counterclockwise")
                        .symbolEffect(.rotate, value: model.resetRotateTrigger)
                        .symbolEffect(.wiggle, value: model.resetWiggleTrigger)
                }
                .disabled(model.selectedFolderURL == nil)
                Button {
                    model.applyFolderCustomization()
                } label: {
                    Label("Apply", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce.down.byLayer, options: .nonRepeating, value: model.applySuccessTrigger)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green.opacity(0.45))
            }
        }
        .onAppear {
            model.promptForFolderAtLaunchIfNeeded()
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.91, green: 0.80, blue: 0.62),   // light tan
                Color(red: 0.80, green: 0.67, blue: 0.48),   // medium tan
                Color(red: 0.68, green: 0.53, blue: 0.32),   // cardboard brown
                Color(red: 0.53, green: 0.37, blue: 0.22)    // deeper brown for depth
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            Image("Cardboard")
                .resizable()
                .ignoresSafeArea()
                .scaledToFill()
                .blendMode(.overlay)
                .saturation(0.7)
                .opacity(0.5)
        }
    }

    private var topPathBar: some View {
        HStack(spacing: 10) {
            Text(model.folderPathText)
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.95))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button("Select Folder") {
                model.chooseFolder()
            }
            .buttonStyle(.bordered)

            Button("Choose Image") {
                model.chooseIconImage()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .panelGlass(cornerRadius: 10)
        .shadow(color: Color.black.opacity(0.5), radius: 7)
    }

    private var isDropped: Bool { model.droppedImage != nil }
    
    private var iconDropArea: some View {
        VStack(spacing: 12) {
            ZStack {
                if model.dropTargetIsActive {
                    GeometryReader { geo in
                        let cornerRadius: CGFloat = 50
                        let lineWidth: CGFloat = 8

                        // Draw dashes manually with trim() so there is no seam where the dash pattern "wraps".
                        let dashCount = 20
                        let segment = 1 / CGFloat(dashCount)

                        // Portion of each segment that is visible as a dash (rest is spacing).
                        // Tune 0.35...0.50 depending on how much gap you want.
                        let dashPortion: CGFloat = 0.5

                        TimelineView(.periodic(from: Date(), by: 1.0 / 30.0)) { context in
                            // 0...1 phase, completes one full lap every 25 seconds (slower)
                            let t = context.date.timeIntervalSinceReferenceDate
                            let phase = CGFloat((t / 25).truncatingRemainder(dividingBy: 1))

                            let strokeColor = Color.cyan.opacity(1)
                            let base = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .inset(by: lineWidth / 2) // keeps stroke fully inside the frame

                            ZStack {
                                ForEach(0..<dashCount, id: \.self) { i in
                                    // Move dashes clockwise by shifting their trim range.
                                    let rawStart = (CGFloat(i) * segment) + phase
                                    let start = rawStart.truncatingRemainder(dividingBy: 1)
                                    let end = start + (segment * dashPortion)

                                    Group {
                                        if end <= 1 {
                                            base
                                                .trim(from: start, to: end)
                                                .stroke(
                                                    strokeColor,
                                                    style: StrokeStyle(
                                                        lineWidth: lineWidth,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                        } else {
                                            // Wrap-around at 1.0 -> split into two trims.
                                            base
                                                .trim(from: start, to: 1)
                                                .stroke(
                                                    strokeColor,
                                                    style: StrokeStyle(
                                                        lineWidth: lineWidth,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )

                                            base
                                                .trim(from: 0, to: end - 1)
                                                .stroke(
                                                    strokeColor,
                                                    style: StrokeStyle(
                                                        lineWidth: lineWidth,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                        }
                                    }
                                }
                            }
                            .scaleEffect(!model.dropTargetIsActive ? 0.8 : 1)
                            .opacity(!model.dropTargetIsActive ? 0 : 1)
                            .blur(radius: !model.dropTargetIsActive ? 16 : 0)
                        }
                    }
                    .frame(width: 410, height: 340)
                } else {
                    Color.clear.frame(width: 0, height: 0)
                }

                Image(nsImage: model.previewIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: 230)
                    .scaleEffect(model.dropTargetIsActive ? 1.65 : 1.5)
                    .padding()

            }
            .animation(.spring(response: 0.35, dampingFraction: 0.54), value: model.dropTargetIsActive)
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .onTapGesture {
                model.chooseIconImage()
            }
            .onDrop(
                of: [UTType.plainText.identifier, UTType.fileURL.identifier, UTType.image.identifier],
                isTargeted: Binding(
                    get: { model.dropTargetIsActive },
                    set: { isTargeted in
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            model.dropTargetIsActive = isTargeted
                        }
                    }
                ),
                perform: model.handleDrop
            )

            if !isDropped {
                Image(systemName: "arrow.up")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .symbolEffect(.wiggle.wholeSymbol, options: .repeat(.periodic(delay: 3.0)))
                    .shadow(color: Color.black.opacity(0.5), radius: 7)
                
                Text("Drop image or SF Symbol here")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.5), radius: 7)
            }

            Text(model.statusMessage)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .shadow(color: Color.black.opacity(0.5), radius: 7)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 10)
    }

    private var optionsInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CustomFolder")
                .font(.system(size: 26, weight: .heavy, design: .rounded))

            ScrollView {
                Form {
                    Section("Symbols") {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Add SF Symbol:", text: $newSymbolName)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                                .focused($isSymbolFieldFocused)
                                .onSubmit {
                                    let trimmed = newSymbolName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    model.addSymbol(named: trimmed)
                                    newSymbolName = ""
                                }

                            VStack(spacing: 6) {
                                let all = model.symbols
                                let limit = 5
                                let needsExpand = all.count > limit
                                let visible = (showAllSymbols || !needsExpand) ? all : Array(all.prefix(limit))

                                ForEach(visible) { symbol in
                                    VStack {
                                        Divider()
                                            .frame(height: 0)
                                        HStack(spacing: 10) {
                                            Image(systemName: symbol.name)
                                                .frame(width: 18, alignment: .center)
                                            Text(symbol.name)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                        }
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            model.setDroppedSymbol(named: symbol.name)
                                        }
                                        .onDrag {
                                            NSItemProvider(object: symbol.name as NSString)
                                        }
                                        .contextMenu {
                                            Button("Remove") {
                                                model.removeSymbol(named: symbol.name)
                                            }
                                        }
                                    }
                                }

                                if needsExpand {
                                    VStack {
                                        Divider()
                                            .frame(height: 0)
                                        Button(showAllSymbols ? "Show less" : "Show all (\(all.count))") {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                showAllSymbols.toggle()
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        .padding(.top, 6)
                    }

                    Section("Folder Settings") {
                        Picker("Folder Texture", selection: $model.folderTextureSource) {
                            ForEach(AppModel.FolderTextureSource.allCases) { source in
                                Text(source.rawValue).tag(source)
                            }
                        }

                        ColorPicker(selection: $model.folderTintColor, supportsOpacity: false) {
                            Label("Folder Color", systemImage: "paintpalette.fill")
                        }
                        Slider(value: $model.folderTintIntensity, in: 0...1)
                    }

                    Section("Icon Settings") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Shadow", systemImage: "app.shadow")
                                Spacer()
                                Text("\(Int(model.iconShadow))")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $model.iconShadow, in: 0...36)
                            
                            Divider()
                                .frame(height: 0)

                            HStack {
                                Label("Size", systemImage: "arrow.up.left.and.arrow.down.right")
                                Spacer()
                                Text("\(Int(model.iconScale * 100))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $model.iconScale, in: 0.6...1.8)

                            Divider()
                                .frame(height: 0)

                            HStack {
                                Label("Opacity", systemImage: "drop.fill")
                                Spacer()
                                Text("\(Int(model.iconOpacity * 100))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $model.iconOpacity, in: 0.1...1)

                            Divider()
                                .frame(height: 0)

                            Picker("Blending Mode",  systemImage: "square.stack.3d.up.fill", selection: $model.iconBlendMode) {
                                ForEach(AppModel.IconBlendMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            
                            Divider()
                                .frame(height: 0)

                            ColorPicker(selection: $model.iconTintColor, supportsOpacity: false) {
                                HStack {
                                    ZStack(alignment: .leading) {
                                        Label("Icon Color", systemImage: "paintbrush")
                                            .opacity(1 - model.iconTintIntensity)
                                            .labelStyle(.iconOnly)
                                        Label("Icon Color", systemImage: "paintbrush.fill")
                                            .opacity(model.iconTintIntensity)
                                            .labelStyle(.iconOnly)
                                    }
                                    Text("Icon Color")
                                    Spacer()
                                }
                            }
                            Slider(value: $model.iconTintIntensity, in: 0...1)
                        }
                    }
                    Section("Legal") {
                        VStack(alignment: .leading, spacing: 10) {
                            Link(destination: URL(string: "https://moysoft.com/privacy")!) {
                                Label(String(localized: "Privacy"), systemImage: "hand.raised")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Divider()
                                .frame(height: 0)
                            Link(destination: URL(string: "https://moysoft.com/imprint")!) {
                                Label(String(localized: "Imprint"), systemImage: "doc.plaintext")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(.clear)
                HStack {
                    Link(destination: URL(string: "https://www.moysoft.com")!) {
                        Image("moysoftfull")
                            .resizable()
                            .interpolation(.high)      // aktiviert weiches Blending
                            .antialiased(true)         // glättet Kanten
                            .scaledToFit()
                            .frame(height: 25)
                            .padding(.horizontal)
                    }
                    Spacer()
                }
                .padding(.bottom)
            }
            .frame(minHeight: 230)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.02),
                        .init(color: .black, location: 0.98),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppModel())
            .frame(width: 1100, height: 760)
    }
}
#endif

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                )
        }
    }
}

private extension View {
    func panelGlass(cornerRadius: CGFloat) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}
