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
            EmailCard(
                id: "mock-7",
                threadId: "thread-7",
                subject: "Rappel : rendez-vous médecin demain 9h30",
                snippet: "Nous vous rappelons votre rendez-vous de demain à 9h30. En cas d'empêchement, merci de nous prévenir 24h à l'avance.",
                senderName: "Cabinet Dr Martin",
                senderEmail: "secretariat@cabinet-martin.fr",
                date: now.addingTimeInterval(-3600 * 52),
                isUnread: true
            ),
            EmailCard(
                id: "mock-8",
                threadId: "thread-8",
                subject: "Ton abonnement salle de sport arrive à échéance",
                snippet: "Ton abonnement se termine le 30 septembre. Renouvelle-le avant cette date pour garder ton tarif préférentiel.",
                senderName: "FitClub",
                senderEmail: "contact@fitclub.fr",
                date: now.addingTimeInterval(-3600 * 60),
                isUnread: false
            ),
            EmailCard(
                id: "mock-9",
                threadId: "thread-9",
                subject: "Re: Devis site vitrine",
                snippet: "Merci pour votre retour rapide. Nous validons le devis, pouvez-vous nous envoyer le planning de réalisation ?",
                senderName: "Sophie Bernard",
                senderEmail: "sophie.bernard@atelier-bernard.fr",
                date: now.addingTimeInterval(-3600 * 70),
                isUnread: true
            ),
            EmailCard(
                id: "mock-10",
                threadId: "thread-10",
                subject: "Votre colis est disponible en point relais",
                snippet: "Votre colis vous attend au point relais Tabac de la Gare. Il sera conservé 9 jours.",
                senderName: "Mondial Relay",
                senderEmail: "notification@mondialrelay.fr",
                date: now.addingTimeInterval(-3600 * 80),
                isUnread: false
            ),
            EmailCard(
                id: "mock-11",
                threadId: "thread-11",
                subject: "Soirée jeux samedi ?",
                snippet: "On organise une soirée jeux de société chez nous samedi à 20h. Dis-moi si tu viens, on prévoit à manger !",
                senderName: "Thomas Leroy",
                senderEmail: "thomas.leroy@gmail.com",
                date: now.addingTimeInterval(-3600 * 90),
                isUnread: true
            ),
            EmailCard(
                id: "mock-12",
                threadId: "thread-12",
                subject: "Récapitulatif de votre semaine",
                snippet: "Cette semaine vous avez parcouru 48 km et atteint votre objectif 5 jours sur 7. Bravo !",
                senderName: "Podomètre",
                senderEmail: "no-reply@podometre.app",
                date: now.addingTimeInterval(-3600 * 100),
                isUnread: false
            ),
        ]
    }
}
