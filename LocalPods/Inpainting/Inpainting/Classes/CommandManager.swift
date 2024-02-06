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



public class AsyncCommandManager {
    /// 撤销栈的最大容量
    public var maxUndoStackSize: Int = .max
    /// 重做栈的最大容量
    public var maxRedoStackSize: Int = .max
    /// 撤销栈内存警告时保留数量
    public var minUndoStackSize: Int = 3
    /// 重做栈内存警告时保留数量
    public var minRedoStackSize: Int = 1
    
    private var undoStack: [AsyncCommand] = []
    private var redoStack: [AsyncCommand] = []
    
    private var isExecing = false

    @MainActor
    public func executeCommand(_ command: AsyncCommand) async {
        guard !isExecing else { return }
        isExecing = true
        await command.execute()
        undoStack.append(command)
        redoStack.removeAll() // 执行新命令后清空重做栈
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
    }

    @MainActor
    public func redo() async {
        guard !isExecing, let command = redoStack.popLast() else { return }
        isExecing = true
        await command.redo()
        undoStack.append(command)
        limitStackIfNeeded()
        isExecing = false
    }
    
    @MainActor
    public func reciveMemoryWarning() async {
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
    }
}





