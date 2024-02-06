//
//  InpaintingViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/13.
//

import UIKit
import SnapKit
import Toast_Swift
import CoreMLImage

open class InpaintingViewController: UIViewController {
    
    public var sendEventBlock: ((String) -> Void)?
    
    let inpenting = LaMaImageInpenting.init()
    
    public let commandManager = AsyncCommandManager()
    
    
    
    // 新增：加载指示器
    var loadngView = UIActivityIndicatorView(style: .large)

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        view.addSubview(scrollView)
        return scrollView
    }()
    var imageView = UIImageView()
    public private(set) var image: UIImage
    
    lazy var drawView: SmudgeDrawingView = {
        let view = SmudgeDrawingView.init()
        view.delegate = self
        view.alpha = 0.5
        return view
    }()
    
    public init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        imageView.image = image
        imageView.backgroundColor = .red
        inpenting.commandManager = self.commandManager
        inpenting.imageProvider = self
        
        self.unDoButton.isEnabled = false
        self.reDoButton.isEnabled = false
        self.commandManager.onStackChanged = { [weak self] in
            guard let self = self else { return }
            self._checkUndoButtonState()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var unDoButton = UIBarButtonItem(image: UIImage(named: "undo_btn"), style: .plain, target: self, action: #selector(onUndo))
    
    lazy var reDoButton = UIBarButtonItem(image: UIImage(named: "redo_btn"), style: .plain, target: self, action: #selector(onRedo))
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
        scrollView.addSubview(imageView)
        imageView.backgroundColor = .systemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        imageView.addSubview(drawView)
        imageView.isUserInteractionEnabled = true
        drawView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
//        unDoButton.isEnabled = false
        // 创建消除和保存按钮
        let clearButton = UIBarButtonItem(title: *"inpaint", style: .plain, target: self, action: #selector(onInpaint))
        let saveButton = UIBarButtonItem(title: *"save_to_photo_lib", style: .plain, target: self, action: #selector(onSave))
        
        // 将按钮添加到导航栏
        navigationItem.rightBarButtonItems = [saveButton, clearButton, reDoButton, unDoButton]
        
        loadngView.hidesWhenStopped = true
        view.addSubview(loadngView)
        loadngView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 创建滑动条
        let slider = UISlider()
        slider.minimumValue = 10
        slider.maximumValue = 50
        let lastSliderValue = UserDefaults.standard.object(forKey: "lastSliderValue") as? Float ?? 30
        slider.value = lastSliderValue
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        drawView.brushSize = CGFloat(lastSliderValue)
        
        // 将滑动条添加到导航栏
        let sliderBarItem = UIBarButtonItem(customView: slider)
        self.navigationItem.titleView = sliderBarItem.customView
        
        // 配置滑动条的布局以避开左右按钮
        slider.widthAnchor.constraint(equalToConstant: self.view.frame.width - 320).isActive = true // 根据需要调整120的值
    }
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        let roundedValue = round(sender.value)
        print("Slider value is now \(roundedValue)")
        
        // 保存四舍五入后的整数值到UserDefaults
        UserDefaults.standard.set(roundedValue, forKey: "lastSliderValue")
        drawView.brushSize = CGFloat(roundedValue)
    }
    
  
    @objc func onUndo() {
        // 先撤销笔触
        if drawView.canUndo {
            drawView.undo()
            return
        }
        Task {
            await commandManager.undo()
        }
    }
    
    @objc func onRedo() {
        // 先重做笔触
        if drawView.canRedo {
            drawView.redo()
            return
        }
        Task {
            await commandManager.redo()
        }
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // 如果收到内存警告则只保留最新的两次操作和原始图片
        commandManager.reciveMemoryWarning()
    }
    
    var hasWarned = false

    @objc func onInpaint() {
        sendEventBlock?("inpainted")
        guard let inputImage = imageView.image else { return }
        guard let maskImage = drawView.exportAsGrayscaleImage() else { return }
        loadngView.startAnimating()
        let bounds = drawView.drawBounds
        if !hasWarned, let rect = bounds.first, (rect.size.width > 512 || rect.size.height > 512) {
            hasWarned = true
            self.view.makeToast(*"toast_inpaint_warning", duration: 4.0, position: .bottom)
        }
        inpenting.inpent(image: inputImage, mask: maskImage, inpaintingRects: bounds) { [weak self] outImage, err in
            guard let self = self else { return }
            self.imageView.image = outImage
            self.image = outImage ?? self.image
            self.imageView.contentMode = .scaleAspectFit
            self.drawView.clean()
            self.loadngView.stopAnimating()
        }
        
    }
    
    @objc func onSave() {
        sendEventBlock?("inpaintsave")
        // 检查 imageView 是否有图像
        guard let imageToSave = imageView.image else {
            print("没有可保存的图像")
            return
        }
        // 保存图像到相册
        UIImageWriteToSavedPhotosAlbum(imageToSave, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    // UIImageWriteToSavedPhotosAlbum 的回调方法
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // 保存失败，显示Toast消息
            self.view.makeToast("\(*"toast_save_error")) \(error.localizedDescription)", duration: 3.0, position: .bottom)
        } else {
            // 保存成功
            self.view.makeToast(*"toast_save_success", duration: 3.0, position: .bottom)
        }
    }
    
}


extension InpaintingViewController: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        //TODO: 放大后对笔刷进行处理，这要求DrawView支持同时绘制不同大小的笔刷，需要先支持笔刷切换再做
    }
}

extension InpaintingViewController: InpaintingCurrentImageProvider {
    func getCurrentImageForInpainting() -> UIImage? {
        return self.image
    }
    
    func onInpaintingImageChanged(_ image: UIImage) {
        DispatchQueue.main.async {
            self.imageView.image = image
            self.image = image
        }
        
    }
}

extension InpaintingViewController: SmudgeDrawingViewDelegate {
    public func onDrawed(_ view: CoreMLImage.SmudgeDrawingView) {
        _checkUndoButtonState()
    }
    
    private func _checkUndoButtonState() {
        self.unDoButton.isEnabled = self.commandManager.undoStack.count > 0 || self.drawView.canUndo
        self.reDoButton.isEnabled = self.commandManager.redoStack.count > 0 || self.drawView.canRedo
    }
    
}

