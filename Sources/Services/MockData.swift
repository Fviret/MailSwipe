import Foundation

enum MockData {
    static func inbox() -> [EmailCard] {
        let now = Date()
        return [
            EmailCard(
                id: "mock-1",
                threadId: "thread-1",
                subject: "Ta facture Septembre est disponible",
                snippet: "Bonjour, votre facture du mois de septembre est maintenant disponible sur votre espace client. Montant total : 42,90€.",
                senderName: "Free Mobile",
                senderEmail: "facture@free.fr",
                date: now.addingTimeInterval(-1800),
                isUnread: true
            ),
            EmailCard(
                id: "mock-2",
                threadId: "thread-2",
                subject: "Point sur le projet Q4",
                snippet: "Salut, peux-tu me confirmer si tu es dispo jeudi pour caler les priorités du prochain trimestre ? On a pas mal de sujets à trancher.",
                senderName: "Camille Dupont",
                senderEmail: "camille.dupont@entreprise.fr",
                date: now.addingTimeInterval(-3600 * 3),
                isUnread: true
            ),
            EmailCard(
                id: "mock-3",
                threadId: "thread-3",
                subject: "Votre commande a été expédiée",
                snippet: "Votre colis n°FR2938471 est en route ! Livraison estimée entre demain et après-demain.",
                senderName: "Amazon",
                senderEmail: "expedition@amazon.fr",
                date: now.addingTimeInterval(-3600 * 6),
                isUnread: false
            ),
            EmailCard(
                id: "mock-4",
                threadId: "thread-4",
                subject: "Invitation : Anniversaire de Léa 🎉",
                snippet: "Coucou ! On organise une petite fête pour les 30 ans de Léa samedi prochain, tu es dispo ?",
                senderName: "Julien Martin",
                senderEmail: "julien.martin@gmail.com",
                date: now.addingTimeInterval(-3600 * 20),
                isUnread: true
            ),
            EmailCard(
                id: "mock-5",
                threadId: "thread-5",
                subject: "Votre relevé bancaire mensuel",
                snippet: "Votre relevé de compte du mois est disponible. Aucune anomalie détectée sur vos opérations récentes.",
                senderName: "Banque en ligne",
                senderEmail: "no-reply@banque.fr",
                date: now.addingTimeInterval(-3600 * 30),
                isUnread: false
            ),
            EmailCard(
                id: "mock-6",
                threadId: "thread-6",
                subject: "Newsletter Tech — édition de la semaine",
                snippet: "Cette semaine : les nouveautés Swift 6.2, le futur de SwiftUI, et 5 outils pour booster votre productivité.",
                senderName: "The Tech Weekly",
                senderEmail: "newsletter@techweekly.io",
                date: now.addingTimeInterval(-3600 * 48),
                isUnread: false
            ),
        ]
    }
}
