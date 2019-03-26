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

class ThemeEditorViewController: ViewController<ThemeEditorView>,
UITableViewDelegate,
UITableViewDataSource,
ColorEditorListener{
    
    let theme: Theme
    let resources: Resources
    let preferences: Preferences

    private let reuseID = "reuseID"
    
    enum Section: Int, CaseIterable {
        
        case theme
        case resource
        
        init(from rawValue: Int) {
            if let new = Section(rawValue: rawValue) {
                self = new
            } else {
                fatalError("Invalid Section Index: \"\(rawValue)\"")
            }
        }
    }
    
    init(preferences: Preferences) {
        self.preferences = preferences
        self.theme = preferences.theme
        self.resources = preferences.resources
        super.init(viewCreator: ThemeEditorView.init)
    }
    
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        switch Section(from: section) {
        case .theme: return theme.colors.count
        case .resource: return resources.colors.count
        }
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath)
        cell.textLabel?.text = provider(for: indexPath).colors[indexPath.row].name
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        let provider = self.provider(for: indexPath)
        let color = provider.colors[indexPath.row]
        showColorEditor(for: color,
                        in: provider)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(from: section) {
        case .theme: return "Theme"
        case .resource: return "Resources"
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            provider(for: indexPath).removeColor(at: indexPath.row)
            writePreferenes()
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath],
                                 with: .bottom)
            tableView.endUpdates()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func provider(for indexPath: IndexPath) -> ColorProvider {
        switch Section(from: indexPath.section) {
        case .theme: return theme
        case .resource: return resources
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        specializedView.table.register(UITableViewCell.self,
                                       forCellReuseIdentifier: reuseID)
        specializedView.table.dataSource = self
        specializedView.table.delegate = self
        specializedView.addButton.addTarget(self,
                                            action: #selector(addNewColorPressed),
                                            for: .touchUpInside)
    }
    
    @objc
    func addNewColorPressed() {
        let bottomSheet = UIAlertController(title: "Where Should the Color be Added?",
                                            message: "",
                                            preferredStyle: .actionSheet)
        func showEditor(for provider: ColorProvider) -> (UIAlertAction) -> () {
            return { (action) in
                self.showColorEditor(for: NamedColor(name: "",
                                                     hex: 0),
                                     in: provider)
            }
        }
        bottomSheet.addAction(UIAlertAction(title: "Theme",
                                            style: .default,
                                            handler: showEditor(for: theme)))
        bottomSheet.addAction(UIAlertAction(title: "Resource",
                                            style: .default,
                                            handler: showEditor(for: resources)))
        present(bottomSheet, animated: true, completion: nil)
    }
    
    private func showColorEditor(for color: NamedColor,
                                 in provider: ColorProvider) {
        let colorEditorViewController = ColorEditorViewController(color: color,
                                                                  in: provider)
        colorEditorViewController.listener = self
        navigationController
            .orAssert("This view controller requires a navigation controller to function correctly")?
            .pushViewController(colorEditorViewController,
                                animated: true)
    }
    
    func finishedEditingColor(_ color: NamedColor) {
        writePreferenes()
        specializedView.table.reloadData()
    }
    
    func writePreferenes() {
        preferences.theme = theme
        preferences.resources = resources
    }
    
}

class ThemeEditorView: View {
    
    let addButton: Button = {
        let button = Button()
        button.setTitle("Add new Color",
                        for: .normal)
        return button
    }()
    
    let table = UITableView()
    
    override init() {
        super.init()
        addSubview(table)
        table.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint
            .activate([
                table.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
                table.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
                table.topAnchor.constraint(equalTo: topAnchor),
                table.bottomAnchor.constraint(equalTo: bottomAnchor),
                addButton.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
                addButton.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
                addButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
                ])
    }
    
}
