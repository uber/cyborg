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
        specializedView
            .saveButton
            .addTarget(self,
                       action: #selector(saveButtonTapped),
                       for: .touchUpInside)
    }
    
    @objc
    func saveButtonTapped() {
        navigationController?
            .popViewController(animated: true)
        colorProvider.mappedColors[color.name] = color
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
            specializedView.errorMessage.text = "Invalid hex color value. Enter a number without a leading \"#\"  or \"0x\""
        }
    }
    
}

class ColorEditorView: View {
    
    let namefield: UITextField = {
       let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.borderStyle = .bezel
        field.placeholder = "Color Name"
        return field
    }()
    
    let colorfield: UITextField = {
       let field = UITextField()
        field.borderStyle = .bezel
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
    
    var observer: AnyObject?
    
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
        let saveButtonConstraint = saveButton.bottomAnchor.constraint(equalTo: readableContentGuide.bottomAnchor)
        observer = saveButtonConstraint.moveWithKeyboard(in: self)
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
                saveButtonConstraint,
                saveButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                ])
    }
    
}
