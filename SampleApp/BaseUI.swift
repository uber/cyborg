//
//  Copyright © Uber Technologies, Inc. All rights reserved.
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
