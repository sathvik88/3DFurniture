//
//  ContentView.swift
//  3DFurniture
//
//  Created by Sathvik Konuganti on 10/1/20.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit
import FocusEntity

struct ContentView : View {
    
    @State var totalClicked: Int = 0
    @State private var isPlacementEnabled = false
    @State private var selectedModel: Model?
    @State private var modelConfirmedForPlacement:
        Model?
    
    
    //Model names
    private var models: [Model] = {
        let filemanager = FileManager.default
        
        guard let path = Bundle.main.resourcePath, let
            files = try?
                filemanager.contentsOfDirectory(atPath: path)else{
            return []
        }
        
        var availableModels: [Model] = []
        for filename in files where
            filename.hasSuffix("usdz"){
            let modelName =
                filename.replacingOccurrences(of: ".usdz", with: "")
            let model = Model(modelName: modelName)
            
            availableModels.append(model)
        }
        
        return availableModels
    }()
    
    var body: some View {
        
        ZStack(alignment: .bottom){//Allows us to arrange view eliments in a depth maner. Stack views on top of each other
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement)
            
            if self.isPlacementEnabled{
                PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, modelConfirmedForPlacement: self.$modelConfirmedForPlacement)
            }else{
                ModelPickerView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, models: self.models)
            }
        
        }
        VStack{
            Button("button"){
                print("hello")
                //arview.screenShot()
            }
        }
        
    }
    
        
}



struct ARViewContainer: UIViewRepresentable {
    
    @Binding var modelConfirmedForPlacement: Model?
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = CustomARView(frame: .zero)
        arView.enableObjectRemoval()
        
        func screenShot(){
            arView.snapshot(saveToHDR: false){ (image) in
                let compressedImage = UIImage(
                    data: (image?.pngData())!)
                UIImageWriteToSavedPhotosAlbum(compressedImage!, nil, nil, nil)
            }
        }
        
        return arView
    }
    
    
    func updateUIView(_ uiView: ARView, context: Context) {
        
        if let model = self.modelConfirmedForPlacement{
           
            if let modelEntity = model.modelEntity{
                
                let clonedEntity = modelEntity.clone(recursive: true)
                let anchorEntity = AnchorEntity(plane: .any)
                anchorEntity.addChild(clonedEntity)
                anchorEntity.name = "object"
                
                print("DEBUG: adding model to scene - \(model.modelName)")
                uiView.scene.addAnchor(anchorEntity)
                clonedEntity.generateCollisionShapes(recursive: true)
                uiView.installGestures([.translation, .rotation], for: clonedEntity)
                

                
            }else{
                print("DEBUG: Unable to load modelEntity for  \(model.modelName)")
            }
            
            DispatchQueue.main.async {
                self.modelConfirmedForPlacement = nil
            }
        }
    }
   
    
}
class CustomARView: ARView{
    let focusSquare = FESquare()
    
    required init(frame frameRect: CGRect){
        super.init(frame: frameRect)
        
        focusSquare.viewDelegate = self
        focusSquare.delegate = self
        focusSquare.setAutoUpdate(to: true)
        self.setupARView()
       
    }
    
    @objc required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupARView(){
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh){
            config.sceneReconstruction = .mesh
        }
        
        self.session.run(config)
    }
        

}
extension CustomARView: FEDelegate{
    func toTrackingState() {
        print("tracking")
    }
    func toInitializingState() {
        print("tracking")
    }
    
}

extension ARView{
    func enableObjectRemoval(){
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(recognizer:)))
        self.addGestureRecognizer(longPressGestureRecognizer)
    }
    @objc func handleLongPress(recognizer:UILongPressGestureRecognizer){
        let location = recognizer.location(in: self)
        if let entity = self.entity(at: location){
            if let anchorEntity = entity.anchor, anchorEntity.name == "object"{
                anchorEntity.removeFromParent()
                print("Removed anchor with name: " + anchorEntity.name)
            }
        }
    }
    
}



struct ModelPickerView: View{
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?
    
    var models: [Model]
    
    var body: some View{
        ScrollView(.horizontal, showsIndicators: false){
            HStack(spacing: 30){
                ForEach(0 ..< self.models.count){
                    index in
                    Button(action: {
                        print("DEBUG: selected model with name: \(self.models[index].modelName)")
                        
                        self.selectedModel = self.models[index]
                        
                        self.isPlacementEnabled = true
                    }){
                        Image(uiImage: self.models[index].image)
                            .resizable()
                            .frame(height: 80)
                            .aspectRatio(1/1, contentMode: .fit)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
    }
}



struct PlacementButtonsView: View{
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?
    @Binding var modelConfirmedForPlacement: Model?
    
    var body: some View{
        HStack{
            //Cancle Button
            Button(action: {
                print("DEBUG: Cancle model placement.")
                
                self.resetPlacementParameters()
            }){
                Image(systemName: "xmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
            //Confirm Button
            Button(action: {
                print("DEBUG: Model placement confirm.")
                
                self.modelConfirmedForPlacement = self.selectedModel
                
                self.resetPlacementParameters()
            }){
                Image(systemName: "checkmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
        }
    }
    func resetPlacementParameters(){
        self.isPlacementEnabled = false
        self.selectedModel = nil
    }
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
