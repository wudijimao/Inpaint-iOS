//
//  CommandManager.swift
//  Inpainting
//
//  Created by wudijimao on 2024/2/5.
//

import Foundation


// 异步命令接口
public protocol AsyncCommand {
    func execute() async
    func undo() async
    func redo() async
}

// 实现异步命令
public class BlockAsyncCommand: AsyncCommand {
    // 定义三个闭包属性，用于执行异步操作
    private var executeBlock: () async -> Void
    private var undoBlock: () async -> Void
    private var redoBlock: () async -> Void

    // 初始化方法，接受三个异步闭包作为参数
    public init(execute: @escaping () async -> Void, undo: @escaping () async -> Void, redo: @escaping () async -> Void) {
        self.executeBlock = execute
        self.undoBlock = undo
        self.redoBlock = redo
    }

    // 实现协议中的方法，调用相应的闭包
    public func execute() async {
        await executeBlock()
    }

    public func undo() async {
        await undoBlock()
    }

    public func redo() async {
        await redoBlock()
    }
}

public class AsyncCommandManager {
    /// 撤销栈的最大容量
    public var maxUndoStackSize: Int = .max
    /// 重做栈的最大容量
    public var maxRedoStackSize: Int = .max
    /// 撤销栈内存警告时保留数量
    public var minUndoStackSize: Int = 3
    /// 重做栈内存警告时保留数量
    public var minRedoStackSize: Int = 1
    
    public private(set) var undoStack: [AsyncCommand] = []
    public private(set) var redoStack: [AsyncCommand] = []
    
    private var isExecing = false
    
    public var onStackChanged: (() -> Void)? = nil

    @MainActor
    public func executeCommand(_ command: AsyncCommand) async {
        guard !isExecing else { return }
        isExecing = true
        await command.execute()
        undoStack.append(command)
        redoStack.removeAll() // 执行新命令后清空重做栈
        onStackChanged?()
        limitStackIfNeeded()
        isExecing = false
    }

    @MainActor
    public func undo() async {
        guard !isExecing, let command = undoStack.popLast() else { return }
        isExecing = true
        await command.undo()
        redoStack.append(command)
        limitStackIfNeeded()
        isExecing = false
        onStackChanged?()
    }

    @MainActor
    public func redo() async {
        guard !isExecing, let command = redoStack.popLast() else { return }
        isExecing = true
        await command.redo()
        undoStack.append(command)
        limitStackIfNeeded()
        isExecing = false
        onStackChanged?()
    }
    
    @MainActor
    public func reciveMemoryWarning() {
        limitStack(minUndoStackSize, minRedoStackSize)
    }
    
    private func limitStackIfNeeded() {
        limitStack(maxUndoStackSize, maxRedoStackSize)
    }
    
    private func limitStack(_ undoCount: Int, _ redoCount: Int) {
        if undoStack.count > undoCount {
            undoStack.removeFirst(undoStack.count - undoCount)
        }
        if redoStack.count > redoCount {
            redoStack.removeFirst(redoStack.count - redoCount)
        }
        onStackChanged?()
    }
}





