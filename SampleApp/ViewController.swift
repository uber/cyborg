//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Cyborg
import UIKit

class Theme: Cyborg.ValueProviding {

    func colorFromTheme(named _: String) -> UIColor {
        return .black
    }

    func colorFromResources(named _: String) -> UIColor {
        return .black
    }

}

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let drawableData = [
            spain,
        ]
        .map { data in
            data.data(using: .utf8)!
        }
        for data in drawableData {
            let vectorView = VectorView(externalValues: Theme())
            view.addSubview(vectorView)
            vectorView.translatesAutoresizingMaskIntoConstraints = false
            let result = VectorDrawable.create(from: data)
            switch result {
            case .ok(let drawable):
                vectorView.drawable = drawable
                NSLayoutConstraint
                    .activate([
                        vectorView.widthAnchor.constraint(equalToConstant: vectorView.intrinsicContentSize.width * 30),
                        vectorView.heightAnchor.constraint(equalToConstant: vectorView.intrinsicContentSize.height * 30),
                    ])
                return vectorView
            case .error(let error):
                print(error)
                fatalError(error)
            }
        }
    }
}
