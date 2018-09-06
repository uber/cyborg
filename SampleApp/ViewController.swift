//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit
import Cyborg

class Theme: Cyborg.Theme {
    
    func color(named string: String) -> UIColor {
        return .black
    }
    
}

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let drawableData = [
            argentina,
            ]
            .map { (data) in
                data.data(using: .utf8)!
        }
        for data in drawableData {
            let vectorView = VectorView(theme: Theme())
//            let debugView = DebugDiagnosticsView()
//            debugView.attach(to: vectorView)
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
                    vectorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    vectorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//                    vectorView.widthAnchor.constraint(equalToConstant: 300),
//                    vectorView.heightAnchor.constraint(equalToConstant: 300)
                    ])
        }
        
    }

}
