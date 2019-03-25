//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import UIKit

protocol ColorEditorListener: AnyObject {
    
    func finishedEditingColor(_ color: NamedColor)
    
}

class ColorEditorViewController: ViewController<ColorEditorView> {
    
    private var color: NamedColor
    private let colorProvider: ColorProvider
    weak var listener: ColorEditorListener?
    
    init(color: NamedColor,
         in colorProvider: ColorProvider) {
        self.colorProvider = colorProvider
        self.color = color
        super.init(viewCreator: ColorEditorView.init)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        specializedView
            .namefield
            .text = color.name
        specializedView
            .colorfield
            .text = String(color.hex)
        specializedView
            .namefield
            .addTarget(self,
                       action: #selector(nameDidChange(_:)),
                       for: .allEditingEvents)
        specializedView
            .colorfield
            .addTarget(self,
                       action: #selector(valueDidChange(_:)),
                       for: .allEditingEvents)
    }
    
    @objc
    func saveButtonTapped() {
        navigationController?
            .popViewController(animated: true)
        listener?.finishedEditingColor(color)
    }
    
    @objc
    func nameDidChange(_ sender: UITextField) {
        color.name = sender.text ?? ""
    }
    
    @objc
    func valueDidChange(_ sender: UITextField) {
        if let hexValue = Int64(sender.text ?? "", radix: 16) {
            color.hex = hexValue
            specializedView.errorMessage.text = ""
        } else {
            specializedView.errorMessage.text = "Invalid hex color value. Enter a number withou a leading \"#\"  or \"0x\""
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // assuming that editing is finished when the view disappears is a minor hack,
        // but it's a sample app, so w/e
        colorProvider.mappedColors[color.name] = color
    }
    
}

class ColorEditorView: View {
    
    let namefield: UITextField = {
       let field = UITextField()
        field.placeholder = "Color Name"
        return field
    }()
    
    let colorfield: UITextField = {
       let field = UITextField()
        field.placeholder = "Hex Number Value"
        return field
    }()
    
    let errorMessage: UILabel = {
        let label = UILabel()
        label.textColor = .red
        return label
    }()
    
    let saveButton: Button = {
        let button = Button()
        button.setTitle("Save", for: .normal)
        return button
    }()
    
    override init() {
        super.init()
        backgroundColor = .white
        addSubview(namefield)
        addSubview(colorfield)
        addSubview(errorMessage)
        addSubview(saveButton)
        namefield.translatesAutoresizingMaskIntoConstraints = false
        colorfield.translatesAutoresizingMaskIntoConstraints = false
        errorMessage.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint
            .activate([
                namefield.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                namefield.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
                namefield.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
                colorfield.topAnchor.constraint(equalTo: namefield.bottomAnchor),
                colorfield.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
                colorfield.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
                errorMessage.topAnchor.constraint(equalTo: colorfield.bottomAnchor),
                errorMessage.leadingAnchor.constraint(equalTo: colorfield.leadingAnchor),
                errorMessage.trailingAnchor.constraint(equalTo: colorfield.trailingAnchor),
                saveButton.bottomAnchor.constraint(equalTo: readableContentGuide.bottomAnchor),
                saveButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                ])
    }
    
}
