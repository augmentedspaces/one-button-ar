//
//  ContentView.swift
//  OneButtonAR
//
//  Created by Nien Lam on 9/8/21.
//

import SwiftUI
import ARKit
import RealityKit
import Combine

class ViewModel: ObservableObject {
    let uiSignal = PassthroughSubject<UISignal, Never>()

    enum UISignal {
        case screenTapped
        case reset
    }
}

struct ContentView : View {
    @StateObject var viewModel = ViewModel()

    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
                .onTapGesture {
                    viewModel.uiSignal.send(.screenTapped)
                }

            Button {
                viewModel.uiSignal.send(.reset)
            } label: {
                Label("Reset", systemImage: "gobackward")
                    .font(.system(.title))
                    .foregroundColor(.white)
                    .labelStyle(IconOnlyLabelStyle())
                    .frame(width: 44, height: 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel

    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var originAnchor: AnchorEntity!
    var pov: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()
    let planeModel = try! Entity.loadModel(named: "plane.usda")

    
    // TODO: Add local variables here. //////////////////////////////////////

    // Image aspect ratio should be square.

    let textures = ["smile.png", "snowflake.png", "turtle.png"]

    /////////////////////////////////////////////////////////////////////////

    // Index for tracking current texture.
    var textureIdx = 0

    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
    }

    func setupScene() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)
        
        // Add pov entity that follows the camera.
        pov = AnchorEntity(.camera)
        arView.scene.addAnchor(pov)

        // Setup world tracking.
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
    }

    func processUISignal(_ signal: ViewModel.UISignal) {
        switch signal {
        case .screenTapped:
            addImagePlane()

        case .reset:
            originAnchor.children.removeAll()
        }
    }
    
    func addImagePlane() {
        let textureName = textures[textureIdx]

        // Cycle through texture indices.
        if textureIdx + 1 == textures.count {
            textureIdx = 0
        } else {
            textureIdx += 1
        }
        
        // Create material for entity.
        var material = UnlitMaterial()
        let texture = try! TextureResource.load(named: textureName)
        material.baseColor = .texture(texture)
        material.tintColor = .white.withAlphaComponent(0.999)

        // Create new plane entity.
        let entity = planeModel.clone(recursive: false)

        // Set plane entity with material
        entity.model?.materials = [material]

        // Set entity 0.5 meters in front of the camera.
        entity.transform.matrix = pov.transformMatrix(relativeTo: originAnchor)
                                  * float4x4(translation: [0.0, 0.0, -0.5])

        // Scale entity by 0.25
        entity.scale = SIMD3(repeating: 0.25)

        // Add entity to scene.
        originAnchor.addChild(entity)
    }
}
