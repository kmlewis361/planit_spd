//
//  LoginView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/6/26.
//

import SwiftUI

struct LoginView: View {
    //TODO figure out what to do with these vars
    @State public var username = ""
    @State public var password = ""
    var body: some View {
        VStack {
            Spacer()
            Text("PlanIt")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(Color.accent)
            TextField("username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
            TextField("password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(8)
            //TODO figure out page nav
            Button("Don't have an account yet? Create one!"){
                //TODO figure out page nav
            }
                .font(.footnote)
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
