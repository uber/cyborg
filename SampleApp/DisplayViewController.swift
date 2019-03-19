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
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
                vectorView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(vectorView)
        addSubview(scrollView)
        NSLayoutConstraint
            .activate([
                vectorView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
                vectorView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                ])
    }
    
}
