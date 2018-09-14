//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit

/// For Debug purposes only.
/// This view is implemented ease of use, *not* correctness.
/// It deliberately creates reference cycles and modifies the internals
/// its host view, and uses inefficient core graphics APIs.
/// **Do not use it in production**.
public final class DebugDiagnosticsView: UIView {

    private var view: VectorView?
    private let padding: CGFloat = 10
    private var lastLaidOutSize: CGSize = .zero

    fileprivate class HorizontalDividerView: UIView {
        let label = UILabel()
        let divider = UIView()

        init(number: Int) {
            super.init(frame: .zero)
            label.text = String(number)
            label.font = UIFont.systemFont(ofSize: 8)
            divider.backgroundColor = .gray
            addSubview(divider)
            addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            divider.translatesAutoresizingMaskIntoConstraints = false
            createConstraints()
        }

        func createConstraints() {
            NSLayoutConstraint
                .activate([
                    label.leadingAnchor.constraint(equalTo: leadingAnchor),
                    label.centerYAnchor.constraint(equalTo: centerYAnchor),
                    divider.leadingAnchor.constraint(equalTo: label.trailingAnchor),
                    divider.trailingAnchor.constraint(equalTo: trailingAnchor),
                    divider.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                    divider.heightAnchor.constraint(equalToConstant: 1),
                ])
        }

        @available(*, unavailable, message: "Not Supported.")
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    fileprivate class VerticalDividerView: HorizontalDividerView {
        override func createConstraints() {
            NSLayoutConstraint
                .activate([
                    label.topAnchor.constraint(equalTo: topAnchor),
                    label.centerXAnchor.constraint(equalTo: centerXAnchor),
                    divider.topAnchor.constraint(equalTo: label.bottomAnchor),
                    divider.bottomAnchor.constraint(equalTo: bottomAnchor),
                    divider.centerXAnchor.constraint(equalTo: label.centerXAnchor),
                    divider.widthAnchor.constraint(equalToConstant: 1),
                ])
        }
    }

    public func attach(to view: VectorView) {
        self.view = view
        view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint
            .activate([
                centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -padding),
                centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -padding),
                widthAnchor.constraint(equalTo: view.widthAnchor, constant: padding),
                heightAnchor.constraint(equalTo: view.heightAnchor, constant: padding),
            ])
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        if lastLaidOutSize != size {
            for view in subviews {
                view.removeFromSuperview()
            }
            if let drawable = view?.drawable {
                let linesX = Int(drawable.intrinsicSize.width)
                let linesY = Int(drawable.intrinsicSize.height)
                let scaleX = size.width / drawable.intrinsicSize.width
                let scaleY = size.height / drawable.intrinsicSize.height
                for i in 0..<linesY {
                    let view = HorizontalDividerView(number: i)
                    addSubview(view)
                    let height = view.label.sizeThatFits(size).height
                    view.frame = CGRect(x: 0,
                                        y: CGFloat(i) * scaleY,
                                        width: size.width,
                                        height: height)
                }
                for i in 0..<linesX {
                    let view = VerticalDividerView(number: i)
                    addSubview(view)
                    let width = view.label.sizeThatFits(size).width
                    view.frame = CGRect(x: CGFloat(i) * scaleX,
                                        y: 0,
                                        width: width,
                                        height: size.height)
                }
            }
        }
    }

}
