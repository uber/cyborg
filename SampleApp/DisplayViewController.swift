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
