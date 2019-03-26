//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


import UIKit

class View: UIView {
    
    init() {
        super.init(frame: .zero)
    }
    
    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension NSLayoutConstraint {
    
    func moveWithKeyboard(in view: UIView) -> AnyObject {
        return NotificationCenter
            .default
            .addObserver(forName: UIResponder.keyboardWillChangeFrameNotification,
                         object: nil,
                         queue: nil) { [weak view] (note) in
                            // TODO: this makes a lot of assumptions about where we are on screen
                            // and what's in the dictionary. This should be factored out into a
                            // keyboard layout guide.
                            if let userInfo = note.userInfo,
                                let finalFrame = userInfo[AnyHashable(UIWindow.keyboardFrameEndUserInfoKey)] as? CGRect,
                                let rawCurve = userInfo[UIWindow.keyboardAnimationCurveUserInfoKey] as? Int,
                                let curve = UIView.AnimationCurve(rawValue: rawCurve),
                                let duration = userInfo[UIWindow.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
                                view?.layoutIfNeeded()
                                UIViewPropertyAnimator(duration: duration, curve: curve, animations: {
                                    self.constant = -finalFrame.height
                                    view?.layoutIfNeeded()
                                })
                                    .startAnimation()
                            }
        }

    }
    
}


class ViewController<View: UIView>: UIViewController {
    
    private let viewCreator: () -> View
    
    override func loadView() {
        view = viewCreator()
    }
    
    var specializedView: View {
        return unsafeDowncast(view, to: View.self)
    }
    
    init(viewCreator: @escaping () -> View) {
        self.viewCreator = viewCreator
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "NSCoder and Interface Builder is not supported. Use Programmatic layout.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension Optional {
    
    func orAssert(_ message: String) -> Wrapped? {
        if self == nil {
            assertionFailure(message)
        }
        return self
    }
    
}
