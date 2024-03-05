//
//  SliderInputView.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import SwiftUI

struct SliderInputView: View {
    @State private var textValue: String
    private var continueAction: (String) -> Void
    private var cancelAction: () -> Void
    
    private var caption: String
    private var details: String
    
    @FocusState var isFocused: Bool
    
    var body: some View {
        VStack {
            Text(caption)
                .bold()
            
            Divider()
            
            Text(details)
                .font(.subheadline)

            HStack {
                TextField(text: $textValue) {}
                    .font(.title)
                    .keyboardType(.decimalPad)
                    .fixedSize(horizontal: true, vertical: false)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                Text("%")
                    .font(.title)
            }
            .padding(8)
            .padding(.horizontal, 24)
            .enframed(outline: .black.opacity(0.2), shadow: .clear, cornerRadius: 12)
            
            Divider()
            
            HStack {
                Button(action: self.cancelAction, label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)

                })
                
                Divider()
                    .frame(height: 30)
                
                Button(action: {
                    self.continueAction(self.textValue)
                }, label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)

                })
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .enframed()
    }
    
    init(
        value: Double,
        continueAction: @escaping (String) -> Void,
        cancelAction: @escaping () -> Void,
        caption: String,
        details: String
    ) {
        self._textValue = State(initialValue: String(value))
        self.continueAction = continueAction
        self.cancelAction = cancelAction
        self.caption = caption
        self.details = details
    }
}

struct SliderInputView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            SliderInputView(
                value: 60,
                continueAction: { _ in },
                cancelAction: {},
                caption: "Set target weight",
                details: "You need to select a target weight in percents of initial. 30% means that from 1kg of meat you get 300g of product."
            )
                .padding(.horizontal, 16)
            Spacer()
        }
    }
}
