//
//  SyntaxHighlighterViewController.swift
//  DigitalInkRecognitionExample
//
//  Created by Ari Jain on 3/7/23.
//

import UIKit
import Foundation
import Sourceful

class SyntaxHighlighterViewController: UIViewController, SyntaxTextViewDelegate {
    
    let lexer = Python3Lexer()
    let textView = SyntaxTextView()
    
    override func viewDidLoad() {
        self.view.backgroundColor = .red
        
        setupTextView()
        
        addText()
    }
    
    func addText() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.textView.text += "def"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.textView.text += " main():"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.textView.text += "\n\tdo_work()"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.textView.text += "\n\treturn"
                    }
                }
            }
        }
    }
    
    func setupTextView() {
        let lexer = Python3Lexer()
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(textView)
        textView.theme = DefaultSourceCodeTheme()
        textView.delegate = self
        
        NSLayoutConstraint.activate([
            textView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            textView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            textView.heightAnchor.constraint(equalToConstant: 1000),
            textView.widthAnchor.constraint(equalToConstant: 800)
        ])
    }
    
    func lexerForSource(_ source: String) -> Sourceful.Lexer {
        return lexer
    }
}


