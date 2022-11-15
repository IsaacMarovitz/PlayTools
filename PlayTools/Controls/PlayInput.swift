import Foundation
import GameController
import UIKit

class PlayInput {
    static let shared = PlayInput()

    var leftMouseButtonActions: [MouseButtonAction] = []
    var middleMouseButtonActions: [MouseButtonAction] = []
    var rightMouseButtonActions: [MouseButtonAction] = []

    var buttonActions: [ButtonAction] = []
    var draggableButtonActions: [DraggableButtonAction] = []
    var joystickButtonActions: [JoystickAction] = []

    var inputEnabled: Bool = false
    var creationCount = 0

    static private var lCmdPressed = false
    static private var rCmdPressed = false

    func setupActions() {
        var counter = 0
        for button in keymap.keymapData.buttonModels {
            if button.keyCode > 0 {
                buttonActions.append(ButtonAction(id: counter, data: button))
            } else {
                switch button.keyCode {
                case -1:
                    leftMouseButtonActions.append(MouseButtonAction(id: counter, data: button))
                case -2:
                    rightMouseButtonActions.append(MouseButtonAction(id: counter, data: button))
                case -3:
                    middleMouseButtonActions.append(MouseButtonAction(id: counter, data: button))
                default:
                    buttonActions.append(ButtonAction(id: counter, data: button))
                }
            }
            counter += 1
        }

        for draggableButton in keymap.keymapData.draggableButtonModels {
            draggableButtonActions.append(DraggableButtonAction(id: counter, data: draggableButton))
            counter += 1
        }

        for mouse in keymap.keymapData.mouseAreaModel {
            PlayMice.shared.setup(mouse)
            counter += 1
        }

        for joystick in keymap.keymapData.joystickModel {
            joystickButtonActions.append(JoystickAction(id: counter, data: joystick))
            counter += 1
        }

        setupKeyboardHandlers()
        setupMouseHandlers()
    }

    func setupKeyboardHandlers() {
        if let keyboard = GCKeyboard.coalesced?.keyboardInput {
            keyboard.keyChangedHandler = { _, _, keyCode, pressed in
                if editor.editorMode
                    && !PlayInput.cmdPressed()
                    && !PlayInput.FORBIDDEN.contains(keyCode)
                    && self.isSafeToBind(keyboard) {
                    // EditorController.shared.setKeyCode(keyCode.rawValue)
                } else {
                    if self.inputEnabled {
                        NotificationCenter.default.post(name: NSNotification.Name("playtools.\(keyCode.rawValue)"),
                                                        object: nil,
                                                        userInfo: ["pressed": pressed,
                                                                   "keyCode": keyCode])
                    }
                }
            }
            keyboard.button(forKeyCode: .leftGUI)?.pressedChangedHandler = { _, _, pressed in
                PlayInput.lCmdPressed = pressed
            }
            keyboard.button(forKeyCode: .rightGUI)?.pressedChangedHandler = { _, _, pressed in
                PlayInput.rCmdPressed = pressed
            }
            keyboard.button(forKeyCode: .leftAlt)?.pressedChangedHandler = { _, _, pressed in
                if pressed {
                    self.toggleInput(setTo: !self.inputEnabled)
                }
            }
            keyboard.button(forKeyCode: .rightAlt)?.pressedChangedHandler = { _, _, pressed in
                if pressed {
                    self.toggleInput(setTo: !self.inputEnabled)
                }
            }
        }
    }

    func setupMouseHandlers() {
        for mouse in GCMouse.mice() {
            if PlaySettings.shared.mouseMapping {
                mouse.mouseInput?.mouseMovedHandler = { _, deltaX, deltaY in
                    if self.inputEnabled {
                        NotificationCenter.default.post(name: NSNotification.Name("playtools.mouseMoved"),
                                                        object: nil,
                                                        userInfo: ["dx": CGFloat(deltaX),
                                                                   "dy": CGFloat(deltaY)])
                    }
                }
            }

            mouse.mouseInput?.leftButton.pressedChangedHandler = { _, _, pressed in
                if self.inputEnabled {
                    for action in self.leftMouseButtonActions {
                        action.update(pressed: pressed)
                    }
                }
            }

            mouse.mouseInput?.middleButton?.pressedChangedHandler = { _, _, pressed in
                if self.inputEnabled {
                    for action in self.middleMouseButtonActions {
                        action.update(pressed: pressed)
                    }
                }
            }

            mouse.mouseInput?.rightButton?.pressedChangedHandler = { _, _, pressed in
                if self.inputEnabled {
                    for action in self.rightMouseButtonActions {
                        action.update(pressed: pressed)
                    }
                }
            }
        }
    }

    static public func cmdPressed() -> Bool {
        return lCmdPressed || rCmdPressed
    }

    private func isSafeToBind(_ input: GCKeyboardInput) -> Bool {
           var result = true
           for forbidden in PlayInput.FORBIDDEN where input.button(forKeyCode: forbidden)?.isPressed ?? false {
               result = false
               break
           }
           return result
       }

    private static let FORBIDDEN: [GCKeyCode] = [
        .leftGUI,
        .rightGUI,
        .leftAlt,
        .rightAlt,
        .printScreen
    ]

    func toggleInput(setTo: Bool) {
        if !editor.editorMode {
            inputEnabled = setTo

            if PlaySettings.shared.mouseMapping {
                if setTo {
                    if screen.fullscreen {
                        screen.switchDock(false)
                    }
                    if let akInterface = AKInterface.shared {
                        akInterface.hideCursor()
                    } else {
                        Toast.showOver(msg: "AKInterface not found!")
                    }
                } else {
                    if screen.fullscreen {
                        screen.switchDock(true)
                    }
                    if let akInterface = AKInterface.shared {
                        akInterface.unhideCursor()
                    } else {
                        Toast.showOver(msg: "AKInterface not found!")
                    }
                }
            }
        }
    }

    var root: UIViewController? {
        return screen.window?.rootViewController
    }

    func initialize() {
        if !PlaySettings.shared.keymapping {
            return
        }

        let centre = NotificationCenter.default
        let main = OperationQueue.main

        centre.addObserver(forName: NSNotification.Name.GCKeyboardDidConnect, object: nil, queue: main) { _ in
            self.creationCount += 1
            Toast.showOver(msg: "Keyboard Connected. Recreating handlers... \(self.creationCount)")
            PlayInput.shared.setupActions()
        }

        centre.addObserver(forName: NSNotification.Name.GCKeyboardDidDisconnect, object: nil, queue: main) { _ in
            self.creationCount += 1
            Toast.showOver(msg: "Keyboard Disconnected. Recreating handlers... \(self.creationCount)")
            PlayInput.shared.setupActions()
        }

        centre.addObserver(forName: NSNotification.Name.GCMouseDidConnect, object: nil, queue: main) { _ in
            self.creationCount += 1
            Toast.showOver(msg: "Mouse Connected. Recreating handlers... \(self.creationCount)")
            PlayInput.shared.setupActions()
        }

        centre.addObserver(forName: NSNotification.Name.GCMouseDidDisconnect, object: nil, queue: main) { _ in
            self.creationCount += 1
            Toast.showOver(msg: "Keyboard Disconnected. Recreating handlers... \(self.creationCount)")
            PlayInput.shared.setupActions()
        }

        creationCount += 1
        Toast.showOver(msg: "Setting up... \(creationCount)")
        setupActions()

        // Fix beep sound
        if let akInterface = AKInterface.shared {
            akInterface.eliminateRedundantKeyPressEvents({ self.dontIgnore() })
        } else {
            Toast.showOver(msg: "AKInterface not found!")
        }
    }

    func dontIgnore() -> Bool {
        (!self.inputEnabled && !EditorController.shared.editorMode) || PlayInput.cmdPressed()
    }
}
