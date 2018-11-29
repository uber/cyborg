//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Cyborg
import UIKit

class Theme: Cyborg.ThemeProviding {

    func colorFromTheme(named _: String) -> UIColor {
        return .black
    }
    
}

class Resources: ResourceProviding {
    
    func colorFromResources(named _: String) -> UIColor {
        return .black
    }
        
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let drawableData = [
            rising,
        ]
        .map { data in
            data.data(using: .utf8)!
        }
        let scrollView = UIScrollView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.layoutMargins = .init(top: 20, left: 16, bottom: 0, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        view.addFullSizeSubview(scrollView)
        scrollView.addFullSizeSubview(stackView)
        scrollView.alwaysBounceVertical = true
        let views = drawableData.map { data -> VectorView in
            let vectorView = VectorView(theme: Theme(), resources: Resources())
            vectorView.translatesAutoresizingMaskIntoConstraints = false
            let result = VectorDrawable.create(from: data)
            switch result {
            case .ok(let drawable):
                vectorView.drawable = drawable
                NSLayoutConstraint
                    .activate([
                        vectorView.widthAnchor.constraint(equalToConstant: vectorView.intrinsicContentSize.width),
                        vectorView.heightAnchor.constraint(equalToConstant: vectorView.intrinsicContentSize.height),
                    ])
                return vectorView
            case .error(let error):
                print(error)
                fatalError(error)
            }
        }
        for view in views {
            stackView.addArrangedSubview(view)
        }
    }

}

extension UIView {

    func addFullSizeSubview(_ subview: UIView) {
        addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint
            .activate([
                subview.trailingAnchor.constraint(equalTo: trailingAnchor),
                subview.leadingAnchor.constraint(equalTo: leadingAnchor),
                subview.topAnchor.constraint(equalTo: topAnchor),
                subview.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])

    }

}
