//
//  SettingViewControoler.swift
//  Inpaint
//
//  Created by wudijimao on 2024/1/17.
//

import UIKit
import SwiftUI
import Toast_Swift

class SettingViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.title = *"设置"
        self.view.backgroundColor = .white
        // 创建并配置SwiftUI视图
        let settingView = SettingView()
        let hostingController = UIHostingController(rootView: settingView)
        // 将SwiftUI视图添加到当前视图控制器中
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        // 设置SwiftUI视图的约束
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// SettingView.swift
import SwiftUI
import CoreMLImage

struct SettingView: View {
    // 创建一个状态属性，用于控制恢复购买的操作
    @State private var isRestoring = false
    
    var body: some View {
        // 使用List来创建一个表格视图
        List {
            // 使用Button来创建一个可点击的行
            Button(action: {
                // 点击时，设置isRestoring为true，并调用恢复购买的方法
                self.isRestoring = true
                self.restorePurchases()
            }) {
                // 使用HStack来水平排列文本和图标
                HStack {
                    // 使用Text来显示文本
                    Text(*"恢复购买")
                    // 使用Spacer来占据剩余的空间
                    Spacer()
                    // 使用Image来显示系统图标
                    Image(systemName: "arrow.clockwise")
                }
            }
            // 使用disabled来禁用按钮，当isRestoring为true时
            .disabled(isRestoring)
            // 使用NavigationLink跳转到关于页面
            NavigationLink(destination: AboutView()) {
                HStack {
                    Text("关于")
                    Spacer() // 用于在文本和图标之间创建空间
                }
            }
        }
        // 使用navigationBarTitle来设置导航栏的标题
        .navigationBarTitle(*"设置")
    }
    
    // 定义一个恢复购买的方法
    func restorePurchases() {
        // 恢复完成后，设置isRestoring为false
        Task { @MainActor in
            if await PurchaseManager.shared.restorePurchases() {
                UIApplication.shared.keyWindow?.makeToast(*"恢复成功")
            } else {
                UIApplication.shared.keyWindow?.makeToast(*"恢复失败")
            }
            self.isRestoring = false
        }
    }
}
