//
//  LoginView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/6/26.
//

import SwiftUI

struct LoginView: View {
    // Allow the parent to provide a handler when login succeeds
    var onLogin: (() -> Void)? = nil

    @State public var username = ""
    @State public var password = ""
    @State private var showError = false

    var body: some View {
        VStack {
            Spacer()
            Text("PlanIt")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(Color.accentColor)
            TextField("username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
            SecureField("password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(8)

            Button("Log In") {
                // Basic validation: require non-empty username/password
                globalUsername = username
                if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty {
                    showError = true
                } else {
                    showError = false
                    // call the provided handler so the root can navigate
                    // Dispatch asynchronously to avoid mutating parent state during view updates
                    print("LoginView: successful login for username=\(username)")
                    onLogin?()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            if showError {
                Text("Please enter username and password")
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            //TODO figure out page nav for 'Create account'
            Button("Don't have an account yet? Create one!"){
                //TODO present create-account flow
            }
                .font(.footnote)
                .padding(.top, 6)

            Spacer()
        }
        .padding()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
