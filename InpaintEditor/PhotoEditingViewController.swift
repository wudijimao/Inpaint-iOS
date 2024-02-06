//
//  PhotoEditingViewController.swift
//  InpaintEditor
//
//  Created by wudijimao on 2024/1/29.
//

import UIKit
import Photos
import PhotosUI
import Inpainting
import SnapKit

class PhotoEditingViewController: UIViewController, PHContentEditingController {

    var input: PHContentEditingInput?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
        
    // MARK: - PHContentEditingController
    
    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        // Inspect the adjustmentData to determine whether your extension can work with past edits.
        // (Typically, you use its formatIdentifier and formatVersion properties to do this.)
        return true
    }
    
    var inpaintingVC: InpaintingViewController?
    
    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: UIImage) {
        // Present content for editing, and keep the contentEditingInput for use when closing the edit session.
        // If you returned true from canHandleAdjustmentData:, contentEditingInput has the original image and adjustment data.
        // If you returned false, the contentEditingInput has past edits "baked in".
        input = contentEditingInput
        
        if let image = contentEditingInput.displaySizeImage {
            let vc = InpaintingViewController(image: image)
            inpaintingVC = vc
            vc.commandManager.maxUndoStackSize = 2
            vc.commandManager.maxRedoStackSize = 1
            let nvc = UINavigationController(rootViewController: vc)
            self.present(nvc, animated: true)
            
//            // 将子视图控制器的视图添加到当前视图控制器的视图
//            self.addChild(vc)
//            self.view.addSubview(vc.view)
//
//            // 配置约束
//            vc.view.snp.makeConstraints { make in
//                make.edges.equalToSuperview()
//            }
//
//            // 调用 didMove(toParent:) 来完成添加流程
//            vc.didMove(toParent: self)
        }
    }
    
    func finishContentEditing(completionHandler: @escaping ((PHContentEditingOutput?) -> Void)) {
        // Update UI to reflect that editing has finished and output is being rendered.
        
        // Render and provide output on a background queue.
        DispatchQueue.global().async {
            // Create editing output from the editing input.
            let output = PHContentEditingOutput(contentEditingInput: self.input!)
            
            // Provide new adjustments and render output to given location.
            // output.adjustmentData = <#new adjustment data#>
            // let renderedJPEGData = <#output JPEG#>
            // renderedJPEGData.writeToURL(output.renderedContentURL, atomically: true)
            let adjustmentData = PHAdjustmentData(formatIdentifier: "YourApp.FormatIdentifier", formatVersion: "1.0", data: "YourAdjustmentsData".data(using: .utf8)!)
                    output.adjustmentData = adjustmentData
            do {
                // Call completion handler to commit edit to Photos.
                let data = self.inpaintingVC?.image.jpegData(compressionQuality: 1.0)
                try data?.write(to: output.renderedContentURL, options: .atomic)
            } catch (let err) {
                print(err)
            }
            completionHandler(output)
            
            // Clean up temporary files, etc.
        }
    }
    
    var shouldShowCancelConfirmation: Bool {
        // Determines whether a confirmation to discard changes should be shown to the user on cancel.
        // (Typically, this should be "true" if there are any unsaved changes.)
        return false
    }
    
    func cancelContentEditing() {
        // Clean up temporary files, etc.
        // May be called after finishContentEditingWithCompletionHandler: while you prepare output.
    }

}
