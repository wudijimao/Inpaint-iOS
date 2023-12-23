//
//  InpaintingViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/13.
//

import UIKit
import SnapKit
import Toast_Swift

class InpaintingViewController: UIViewController {
    
    var inpenting = LaMaImageInpenting.init()
    
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
    
    lazy var drawView: SmudgeDrawingView = {
        let view = SmudgeDrawingView.init()
        return view
    }()
    
    public init(image: UIImage) {
        super.init(nibName: nil, bundle: nil)
        imageView.image = image
        imageView.backgroundColor = .red
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var unDoButton = UIBarButtonItem(title: *"undo", style: .plain, target: self, action: #selector(onUndo))
    
    override func viewDidLoad() {
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
        
        unDoButton.isEnabled = false
        // 创建消除和保存按钮
        let clearButton = UIBarButtonItem(title: *"inpaint", style: .plain, target: self, action: #selector(onInpaint))
        let saveButton = UIBarButtonItem(title: *"save_to_photo_lib", style: .plain, target: self, action: #selector(onSave))
        
        // 将按钮添加到导航栏
        navigationItem.rightBarButtonItems = [saveButton, clearButton, unDoButton]
        
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
    
    
    var undoList = [UIImage]() {
        didSet {
            unDoButton.isEnabled = undoList.count > 0
        }
    }
    @objc func onUndo() {
        guard undoList.count > 0 else { return }
        let img = undoList.removeLast()
        self.imageView.image = img
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // 如果收到内存警告则只保留最新的两次操作和原始图片
        if undoList.count > 3 {
            let lastTwoOperations = undoList.suffix(2)
            undoList = [undoList[0]] + lastTwoOperations
        }
    }
    
    var hasWarned = false

    @objc func onInpaint() {
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
            self.imageView.contentMode = .scaleAspectFit
            self.undoList.append(inputImage)
            self.drawView.clean()
            self.loadngView.stopAnimating()
        }
        
    }
    
    @objc func onSave() {
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
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        //TODO: 放大后对笔刷进行处理，这要求DrawView支持同时绘制不同大小的笔刷，需要先支持笔刷切换再做
    }
}
