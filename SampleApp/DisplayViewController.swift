//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit
import Cyborg

class DisplayViewController: ViewController<DisplayView> {
    
    init(drawable: VectorDrawable) {
        super.init {
            DisplayView(drawable: drawable)
        }
        title = "Imported VectorDrawable"
    }
}

class DisplayView: View {
    
    let vectorView = VectorView(theme: Theme(),
                                resources: Resources())
    
    init(drawable: VectorDrawable) {
        super.init()
        backgroundColor = .white
        vectorView.drawable = drawable
        vectorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vectorView)
        NSLayoutConstraint
            .activate([
                vectorView.centerXAnchor.constraint(equalTo: centerXAnchor),
                vectorView.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
    }
    
}
