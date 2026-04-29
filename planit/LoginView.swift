//
//  LoginView.swift
//  planit
//

import CloudKit
import SwiftUI
import UIKit

struct LoginView: View {
    /// Called after onboarding succeeds. `showWelcome` is true only when the user just claimed a new username this session (show Welcome); returning users pass `false` (go to Home).
    var onLogin: ((_ showWelcome: Bool) -> Void)? = nil

    @State private var phase: Phase = .checking
    @State private var ownerRecordName: String = ""
    @State private var chosenUsername = ""
    @State private var errorMessage: String?

    private enum Phase: Equatable {
        case checking
        case iCloudHelp(reason: ICloudBlockReason)
        case cloudKitBackendMissing
        case chooseUsername
        case returning(username: String)
        case saving
    }

    private enum ICloudBlockReason: Equatable {
        case notSignedIn
        case restricted
        case temporarilyUnavailable
        case couldNotDetermine
        case generic
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Text("PlanIt")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)

            Group {
                switch phase {
                case .checking:
                    ProgressView("Checking iCloud…")
                        .padding(.top, 12)

                case .iCloudHelp(let reason):
                    Text(titleForICloud(reason))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text(detailForICloud(reason))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 10) {
                        Button("Try again") {
                            Task { await bootstrap() }
                        }
                        .buttonStyle(.borderedProminent)

                        if showsOpenSettings(for: reason) {
                            Button("Open Settings") {
                                openSystemSettings()
                            }
                            .buttonStyle(.bordered)
                        }

                        Link("Apple Support — iCloud", destination: URL(string: "https://support.apple.com/icloud")!)
                            .font(.footnote)
                    }

                case .cloudKitBackendMissing:
                    Text("PlanIt accounts aren’t available yet")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text(
                        """
                        Your device can be signed into iCloud while PlanIt’s database schema still isn’t published \
                        for this app version (often showing “did not find record type PlanItUser”).
                        Install an updated PlanIt build once your organizer deploys CloudKit, then tap Try again.
                        """
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                    Button("Try again") {
                        Task { await bootstrap() }
                    }
                    .buttonStyle(.borderedProminent)

                    Link("Apple — Designing a CloudKit database", destination: URL(string: "https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database")!)
                        .font(.footnote)

                    #if DEBUG
                    Text(
                        """
                        DEBUG: In Xcode with CloudKit enabled, deploy schema (PlanItUser with username, \
                        usernameLowercased QUERYABLE, ownerRecordName QUERYABLE). Deploy Development schema \
                        before Testing on device.
                        """
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
                    #endif

                case .chooseUsername:
                    Text("Choose your PlanIt username (letters, numbers, underscores). It must be unique.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    TextField("username", text: $chosenUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                    Button("Continue") {
                        Task { await saveNewUsername() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chosenUsername.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)

                case .returning(let username):
                    Text("Signed in with iCloud.")
                        .foregroundStyle(.secondary)
                    Text("@\(username)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Button("Continue") {
                        onLogin?(false)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)

                case .saving:
                    ProgressView("Saving profile…")
                        .padding(.top, 12)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .task {
            await bootstrap()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func showsOpenSettings(for reason: ICloudBlockReason) -> Bool {
        switch reason {
        case .notSignedIn, .restricted, .couldNotDetermine, .generic:
            return true
        case .temporarilyUnavailable:
            return false
        }
    }

    private func titleForICloud(_ reason: ICloudBlockReason) -> String {
        switch reason {
        case .notSignedIn:
            return "Sign in to iCloud"
        case .restricted:
            return "iCloud is restricted on this device"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        case .couldNotDetermine:
            return "Couldn’t verify iCloud status"
        case .generic:
            return "We couldn’t connect to iCloud"
        }
    }

    private func detailForICloud(_ reason: ICloudBlockReason) -> String {
        switch reason {
        case .notSignedIn:
            return "Open Settings → Apple ID → sign in, then enable iCloud Drive if prompted."
        case .restricted:
            return "Check Screen Time, parental controls, or a managed-device profile that limits iCloud."
        case .temporarilyUnavailable:
            return "Wait briefly and try again. Apple’s iCloud services may be recovering."
        case .couldNotDetermine:
            return "Check your network connection, then Try again."
        case .generic:
            return "Confirm iCloud is turned on for PlanIt’s container on this device and account."
        }
    }

    @MainActor
    private func bootstrap() async {
        phase = .checking
        errorMessage = nil
        do {
            let owner = try await cloudKitOwnerRecordName()
            ownerRecordName = owner

            if let profile = try await fetchPlanItUserProfile(ownerRecordName: owner),
               let rawName = profile["username"] as? String {
                let username = normalizedPlanItUsername(rawName)
                if username.isEmpty {
                    phase = .chooseUsername
                    return
                }
                globalUsername = username
                globalCloudKitOwnerRecordName = owner
                phase = .returning(username: username)
            } else {
                phase = .chooseUsername
            }
        } catch PlanItAccountError.iCloudNotSignedIn {
            phase = .iCloudHelp(reason: .notSignedIn)
        } catch PlanItAccountError.iCloudRestricted {
            phase = .iCloudHelp(reason: .restricted)
        } catch PlanItAccountError.iCloudTemporarilyUnavailable {
            phase = .iCloudHelp(reason: .temporarilyUnavailable)
        } catch PlanItAccountError.iCloudCouldNotDetermine {
            phase = .iCloudHelp(reason: .couldNotDetermine)
        } catch PlanItAccountError.iCloudUnavailable {
            phase = .iCloudHelp(reason: .generic)
        } catch PlanItAccountError.noUserRecord {
            errorMessage = PlanItAccountError.noUserRecord.localizedDescription
            phase = .iCloudHelp(reason: .generic)
        } catch PlanItAccountError.cloudKitSchemaMissing {
            phase = .cloudKitBackendMissing
        } catch {
            let mapped = mapPlanItAccountCloudKitError(error)
            if let planIt = mapped as? PlanItAccountError {
                switch planIt {
                case .cloudKitSchemaMissing:
                    phase = .cloudKitBackendMissing
                    return
                default:
                    errorMessage = planIt.localizedDescription
                    phase = .iCloudHelp(reason: .generic)
                    return
                }
            }
            errorMessage = mapped.localizedDescription
            phase = .iCloudHelp(reason: .generic)
        }
    }

    @MainActor
    private func saveNewUsername() async {
        phase = .saving
        errorMessage = nil
        do {
            let owner: String
            if ownerRecordName.isEmpty {
                owner = try await cloudKitOwnerRecordName()
                ownerRecordName = owner
            } else {
                owner = ownerRecordName
            }

            let saved = try await upsertPlanItUser(displayUsername: chosenUsername, ownerRecordName: owner)
            globalUsername = saved
            globalCloudKitOwnerRecordName = owner
            onLogin?(true)
        } catch PlanItAccountError.cloudKitSchemaMissing {
            phase = .cloudKitBackendMissing
        } catch {
            let mapped = mapPlanItAccountCloudKitError(error)
            if let planIt = mapped as? PlanItAccountError {
                switch planIt {
                case .cloudKitSchemaMissing:
                    phase = .cloudKitBackendMissing
                default:
                    errorMessage = planIt.localizedDescription
                    phase = .chooseUsername
                }
            } else {
                errorMessage = mapped.localizedDescription
                phase = .chooseUsername
            }
        }
    }
}

#Preview {
    LoginView()
}
