//
//  AboutViewController.swift
//  Inpaint
//
//  Created by wudijimao on 2024/1/27.
//

import SwiftUI
import UIKit

// SwiftUI 视图，用于实现横向滑动的页面和纵向滚动的用户列表
struct AboutView: View {
    // 示例数据
    let usersPage1 = ["用户1", "用户2", "用户3"]
    let usersPage2 = ["用户4", "用户5", "用户6"]
    
    var body: some View {
        TabView {
            // 第一个页面
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(usersPage1, id: \.self) { user in
                        Text(user)
                    }
                }
            }
            .tabItem {
                Text("第一页")
            }
            
            // 第二个页面
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(usersPage2, id: \.self) { user in
                        Text(user)
                    }
                }
            }
            .tabItem {
                Text("第二页")
            }
            
            // 可以继续添加更多页面...
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
}

//// 将 SwiftUI 视图包装成 UIViewController
//class AboutViewController: UIHostingController<AboutView> {
//    init() {
//        super.init(rootView: AboutView())
//    }
//    
//    @objc required dynamic init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder, rootView: AboutView())
//    }
//}
