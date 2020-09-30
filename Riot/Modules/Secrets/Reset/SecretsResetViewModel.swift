// File created from ScreenTemplate
// $ createScreen.sh Secrets/Reset SecretsReset
/*
 Copyright 2020 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

final class SecretsResetViewModel: SecretsResetViewModelType {
    
    // MARK: - Properties
    
    // MARK: Private

    private let session: MXSession
    private let recoveryService: MXRecoveryService
    
    // MARK: Public

    weak var viewDelegate: SecretsResetViewModelViewDelegate?
    weak var coordinatorDelegate: SecretsResetViewModelCoordinatorDelegate?
    
    // MARK: - Setup
    
    init(session: MXSession) {
        self.session = session
        self.recoveryService = session.crypto.recoveryService
    }
    
    // MARK: - Public
    
    func process(viewAction: SecretsResetViewAction) {
        switch viewAction {
        case .loadData:
            break
        case .reset:
            self.askAuthentication()
        case .authenticationInfoEntered(let authInfo):
            self.resetSecrets(with: authInfo)
        case .cancel:
            self.coordinatorDelegate?.secretsResetViewModelDidCancel(self)
        }
    }
    
    // MARK: - Private
    
    private func update(viewState: SecretsResetViewState) {
        self.viewDelegate?.secretsResetViewModel(self, didUpdateViewState: viewState)
    }
    
    private func resetSecrets(with authInfo: [String: Any]) {
        guard let crossSigning = self.session.crypto.crossSigning else {
            return
        }
        NSLog("[SecretsResetViewModel] resetSecrets")

        self.update(viewState: .resetting)
        crossSigning.setup(withAuthParams: authInfo, success: { [weak self] in
            guard let self = self else {
                return
            }
            self.recoveryService.deleteRecovery(withDeleteServicesBackups: true, success: { [weak self] in
                guard let self = self else {
                    return
                }
                self.update(viewState: .resetDone)
                self.coordinatorDelegate?.secretsResetViewModelDidResetSecrets(self)

            }, failure: { [weak self] error in
                guard let self = self else {
                    return
                }
                self.update(viewState: .error(error))
            })

        }, failure: { [weak self] error in
            guard let self = self else {
                return
            }
            self.update(viewState: .error(error))
        })
    }
    
    // NOTE: Use a Coordinator instead of AuthenticatedSessionViewControllerFactory and delegate the presentation to SecretsResetCoordinator
    private func askAuthentication() {
        let path = "\(kMXAPIPrefixPathUnstable)/keys/device_signing/upload"
        let authenticatedSessionFactory = AuthenticatedSessionViewControllerFactory(session: self.session)
        let authData = SecretsResetAuthData(path: path, httpMethod: "POST", authenticatedSessionViewControllerFactory: authenticatedSessionFactory)
        
        self.update(viewState: .showAuthentication(authData: authData))
    }
}
