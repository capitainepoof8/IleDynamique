import ServiceManagement

/// Ouverture à la connexion via SMAppService (ne fonctionne que depuis le bundle .app).
enum LancementAuDemarrage {
    static var estActif: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func definir(_ actif: Bool) throws {
        if actif {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
