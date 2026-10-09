import Foundation

enum MockData {
    /// Les mails de démonstration suivent la langue de l'interface.
    static var isFrench: Bool { Bundle.main.preferredLocalizations.first == "fr" }

    static func inbox() -> [EmailCard] { inbox(french: isFrench) }

    static func inbox(french: Bool) -> [EmailCard] { french ? frenchInbox() : englishInbox() }

    private static func frenchInbox() -> [EmailCard] {
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

    private static func englishInbox() -> [EmailCard] {
        let now = Date()
        func mail(_ n: Int, _ subject: String, _ snippet: String, _ name: String, _ email: String, hoursAgo: Double, unread: Bool) -> EmailCard {
            EmailCard(id: "mock-\(n)", threadId: "thread-\(n)", subject: subject, snippet: snippet, senderName: name,
                      senderEmail: email, date: now.addingTimeInterval(-3600 * hoursAgo), isUnread: unread)
        }
        return [
            mail(1, "Your September bill is available", "Hello, your September bill is now available in your customer area. Total amount: $42.90.", "Free Mobile", "billing@free.fr", hoursAgo: 0.5, unread: true),
            mail(2, "Q4 project check-in", "Hi, can you confirm you're free on Thursday to set next quarter's priorities? We have quite a few topics to settle.", "Camille Dupont", "camille.dupont@company.com", hoursAgo: 3, unread: true),
            mail(3, "Your order has shipped", "Your parcel no. FR2938471 is on its way! Estimated delivery between tomorrow and the day after.", "Amazon", "shipping@amazon.com", hoursAgo: 6, unread: false),
            mail(4, "Invitation: Léa's birthday 🎉", "Hey! We're throwing a little party for Léa's 30th next Saturday, are you free?", "Julien Martin", "julien.martin@gmail.com", hoursAgo: 20, unread: true),
            mail(5, "Your monthly bank statement", "Your account statement for the month is available. No anomalies were detected on your recent transactions.", "Online Bank", "no-reply@bank.com", hoursAgo: 30, unread: false),
            mail(6, "Tech Newsletter — this week's edition", "This week: what's new in Swift 6.2, the future of SwiftUI, and 5 tools to boost your productivity.", "The Tech Weekly", "newsletter@techweekly.io", hoursAgo: 48, unread: false),
            mail(7, "Reminder: doctor's appointment tomorrow 9:30", "This is a reminder of your appointment tomorrow at 9:30. If you can't make it, please let us know 24 hours in advance.", "Dr Martin's Office", "reception@martin-clinic.com", hoursAgo: 52, unread: true),
            mail(8, "Your gym membership is about to expire", "Your membership ends on September 30. Renew before then to keep your preferred rate.", "FitClub", "contact@fitclub.com", hoursAgo: 60, unread: false),
            mail(9, "Re: Website quote", "Thanks for your quick reply. We're approving the quote, could you send us the project schedule?", "Sophie Bernard", "sophie.bernard@bernard-studio.com", hoursAgo: 70, unread: true),
            mail(10, "Your parcel is available at a pickup point", "Your parcel is waiting at the Station Tobacco pickup point. It will be kept for 9 days.", "Mondial Relay", "notification@mondialrelay.com", hoursAgo: 80, unread: false),
            mail(11, "Game night Saturday?", "We're hosting a board game night at our place on Saturday at 8 PM. Let me know if you're coming, we'll have food!", "Thomas Leroy", "thomas.leroy@gmail.com", hoursAgo: 90, unread: true),
            mail(12, "Your weekly recap", "This week you walked 48 km and reached your goal 5 days out of 7. Well done!", "Podomètre", "no-reply@podometre.app", hoursAgo: 100, unread: false),
        ]
    }

    /// Corps complets des mails de démo (pour l'écran de lecture).
    static func body(for id: String) -> String { body(for: id, french: isFrench) }

    static func body(for id: String, french: Bool) -> String {
        french ? frenchBody(for: id) : englishBody(for: id)
    }

    private static func englishBody(for id: String) -> String {
        switch id {
        case "mock-2":
            return """
            Hi,

            Can you confirm you're free on Thursday to set next quarter's priorities? We have quite a few topics to settle:

            • the mobile roadmap (V2 delivery)
            • the user-testing budget
            • choosing between the onboarding redesign and notifications

            I suggest 2 PM in the Horizon room, 1.5 hours max. Let me know if that works, otherwise we'll move it to Friday morning.

            Thanks!
            Camille
            """
        case "mock-9":
            return """
            Hello,

            Thanks for your quick reply. We approve the quote as presented.

            Could you send us the project schedule with the delivery dates for each stage (mockups, development, acceptance)? We'd like to start next week if possible.

            Kind regards,
            Sophie Bernard
            Bernard Studio
            """
        default:
            let card = inbox(french: false).first { $0.id == id }
            return (card?.snippet ?? "")
                + "\n\nThis is a demo email: the full content of a real Gmail message appears here."
        }
    }

    private static func frenchBody(for id: String) -> String {
        switch id {
        case "mock-2":
            return """
            Salut,

            Peux-tu me confirmer si tu es dispo jeudi pour caler les priorités du prochain trimestre ? On a pas mal de sujets à trancher :

            • la roadmap mobile (livraison de la V2)
            • le budget des tests utilisateurs
            • l'arbitrage entre la refonte de l'onboarding et les notifications

            Je propose 14h en salle Horizon, 1h30 maximum. Dis-moi si ça te va, sinon on décale à vendredi matin.

            Merci !
            Camille
            """
        case "mock-9":
            return """
            Bonjour,

            Merci pour votre retour rapide. Nous validons le devis tel que présenté.

            Pouvez-vous nous envoyer le planning de réalisation avec les dates de livraison de chaque étape (maquettes, développement, recette) ? Nous aimerions démarrer la semaine prochaine si possible.

            Bien cordialement,
            Sophie Bernard
            Atelier Bernard
            """
        default:
            let card = inbox(french: true).first { $0.id == id }
            return (card?.snippet ?? "")
                + "\n\nCeci est un mail de démonstration : le contenu complet d'un vrai mail Gmail s'affiche ici."
        }
    }
}
