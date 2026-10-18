// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct SpeedTestStrings {
    let stop: String
    let rateLimited: String
    let server: String

    static func localized(_ language: AppLanguage) -> SpeedTestStrings {
        switch language {
        case .enUS: return .init(stop: "Stop test",
                                 rateLimited: "The test server is busy. Try again in a few minutes.",
                                 server: "Test server")
        case .ptBR: return .init(stop: "Parar teste",
                                 rateLimited: "O servidor de teste está ocupado. Tente de novo em alguns minutos.",
                                 server: "Servidor de teste")
        case .tr: return .init(stop: "Testi durdur",
                               rateLimited: "Test sunucusu meşgul. Birkaç dakika sonra yeniden deneyin.",
                               server: "Test sunucusu")
        case .ru: return .init(stop: "Остановить тест",
                               rateLimited: "Сервер теста занят. Повторите через несколько минут.",
                               server: "Сервер теста")
        case .es: return .init(stop: "Detener prueba",
                               rateLimited: "El servidor de prueba está ocupado. Vuelve a intentarlo en unos minutos.",
                               server: "Servidor de prueba")
        case .sk: return .init(stop: "Zastaviť test",
                               rateLimited: "Testovací server je zaneprázdnený. Skúste to znova o pár minút.",
                               server: "Testovací server")
        case .de: return .init(stop: "Test stoppen",
                               rateLimited: "Der Testserver ist ausgelastet. In ein paar Minuten erneut versuchen.",
                               server: "Testserver")
        case .fr: return .init(stop: "Arrêter le test",
                               rateLimited: "Le serveur de test est occupé. Réessayez dans quelques minutes.",
                               server: "Serveur de test")
        case .it: return .init(stop: "Interrompi test",
                               rateLimited: "Il server di test è occupato. Riprova tra qualche minuto.",
                               server: "Server di test")
        case .ja: return .init(stop: "テストを停止",
                               rateLimited: "テストサーバーが混雑しています。数分後にもう一度お試しください。",
                               server: "テストサーバー")
        case .ko: return .init(stop: "테스트 중지",
                               rateLimited: "테스트 서버가 혼잡합니다. 몇 분 후 다시 시도하세요.",
                               server: "테스트 서버")
        case .uk: return .init(stop: "Зупинити тест",
                               rateLimited: "Сервер тесту зайнятий. Спробуйте за кілька хвилин.",
                               server: "Сервер тесту")
        case .zhHans: return .init(stop: "停止测试",
                                   rateLimited: "测试服务器繁忙，请几分钟后再试。",
                                   server: "测试服务器")
        case .zhTW: return .init(stop: "停止測試",
                                 rateLimited: "測試伺服器忙碌中，請幾分鐘後再試。",
                                 server: "測試伺服器")
        case .zhHK: return .init(stop: "停止測試",
                                 rateLimited: "測試伺服器繁忙，請幾分鐘後再試。",
                                 server: "測試伺服器")
        }
    }
}
