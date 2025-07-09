//
//  ContentView.swift
//  Artemis
//
//  Created by Joshua Kaufman on 7/8/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var showScan = false
    @State private var showBrowse = false
    var body: some View {
        if !isAuthenticated {
            AuthScreen(onAuth: { isAuthenticated = true })
        } else if showScan {
            ScanView(onExit: {
                showScan = false
            })
        } else if showBrowse {
            BrowseView(onBack: { showBrowse = false })
        } else {
            ChoiceScreen(onScan: { showScan = true }, onBrowse: { showBrowse = true })
        }
    }
}

struct AuthScreen: View {
    var onAuth: () -> Void
    @State private var isSignUp = false
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(isSignUp ? "Create Account" : "Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
            VStack(spacing: 16) {
                Button(action: { /* Google Auth */ onAuth() }) {
                    HStack { Image(systemName: "g.circle"); Text(isSignUp ? "Sign up with Google" : "Sign in with Google") }
                        .frame(maxWidth: .infinity)
                        .padding().background(Color(.systemGray6)).cornerRadius(10)
                }
                Button(action: { /* Apple Auth */ onAuth() }) {
                    HStack { Image(systemName: "applelogo"); Text(isSignUp ? "Sign up with Apple" : "Sign in with Apple") }
                        .frame(maxWidth: .infinity)
                        .padding().background(Color(.systemGray6)).cornerRadius(10)
                }
                Button(action: { /* Email Auth */ onAuth() }) {
                    HStack { Image(systemName: "envelope"); Text(isSignUp ? "Sign up with Email" : "Sign in with Email") }
                        .frame(maxWidth: .infinity)
                        .padding().background(Color(.systemGray6)).cornerRadius(10)
                }
            }
            Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                isSignUp.toggle()
            }.padding(.top)
            Button("Continue as Guest") {
                onAuth()
            }.padding(.top, 8)
            Spacer()
        }.padding()
    }
}

struct ChoiceScreen: View {
    var onScan: () -> Void
    var onBrowse: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("What would you like to do?")
                .font(.title)
                .fontWeight(.semibold)
            Button(action: onScan) {
                Text("Scan a Room")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            Button(action: onBrowse) {
                Text("Browse the App")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            Spacer()
        }
    }
}

struct BrowseView: View {
    var onBack: () -> Void
    var body: some View {
        VStack {
            Text("Browse Placeholder")
            Button("Back", action: onBack)
        }
    }
}

#Preview {
    ContentView()
}
