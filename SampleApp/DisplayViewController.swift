//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit
import Cyborg

class DisplayViewController: ViewController<DisplayView> {
    
    init(drawable: VectorDrawable,
         theme: Theme,
         resources: Resources) {
        super.init {
            DisplayView(drawable: drawable,
                        theme: theme,
                        resources: resources)
        }
        title = "Imported VectorDrawable"
    }
}

class DisplayView: View {
    
    let vectorView: VectorView
    
    init(drawable: VectorDrawable,
         theme: Theme,
         resources: Resources) {
        vectorView = VectorView(theme: theme,
                                resources: resources)
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
