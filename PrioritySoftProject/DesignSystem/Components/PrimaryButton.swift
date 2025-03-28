//
//  PrimaryButton.swift
//  PrioritySoftProject
//
//  Created by Milena Predic on 26.3.25..
//

import SwiftUI

struct PrimaryButton: View {
    var title: String = HomeViewStrings.allow
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 51)
                .background(.appRed)
                .cornerRadius(10)
        }
    }
}

