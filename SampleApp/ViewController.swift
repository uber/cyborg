//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit
import Cyborg

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let drawableData = [
            done,
            work,
            visibility,
            baselinesplit,
            androidDocsSampleTriangle,
            person,
            swapHorizontal,
            translate,
            timeline,
            power,
            ]
            .map { (data) in
                data.data(using: .utf8)!
        }
        var lastAnchor = view.leadingAnchor
        for data in drawableData {
            let vectorView = VectorView(frame: .zero)
            let debugView = DebugDiagnosticsView()
            debugView.attach(to: vectorView)
            view.addSubview(vectorView)
            vectorView.translatesAutoresizingMaskIntoConstraints = false
            VectorDrawable
                .create(from: data) { (result) in
                    switch result {
                    case .ok(let drawable):
                        vectorView.drawable = drawable
                    case .error(let error):
                        print(error)
                        fatalError(error)
                    }
            }
            NSLayoutConstraint
                .activate([
                    vectorView.leadingAnchor.constraint(equalTo: lastAnchor, constant: 8),
                    vectorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    ])
            lastAnchor = vectorView.trailingAnchor
        }
        
    }

}
