//
//  ContentView.swift
//  NepaliPatro
//
//  Created by Pranab Kc on 12/03/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Nepali patro")
                .font(.headline)

            Button("Do Something") {
                print("Clicked")
            }
        }
        .padding()
        .frame(width: 200)
    }
}

