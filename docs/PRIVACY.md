# Politique de confidentialité — MailSwipe

*Dernière mise à jour : 9 octobre 2026* · [English version below](#privacy-policy--mailswipe-english)

MailSwipe est une application iOS qui permet de trier ses mails Gmail d'un geste (répondre, supprimer, archiver, snoozer). Elle est éditée par Florian Viret (Flo Viret Solutions).

## Ce que l'application peut lire et faire

Lorsque vous connectez votre compte Google, MailSwipe demande l'autorisation :

| Autorisation Google | Pourquoi |
|---|---|
| `https://www.googleapis.com/auth/gmail.modify` | Lire vos mails (expéditeur, objet, extrait, corps du message quand vous l'ouvrez), les archiver, les mettre à la corbeille, appliquer le libellé « MailSwipe/Snoozed » |
| `https://www.googleapis.com/auth/gmail.send` | Envoyer les réponses que vous rédigez |
| `https://www.googleapis.com/auth/userinfo.email` | Afficher l'adresse du compte connecté |

MailSwipe n'agit sur un mail que lorsque vous le demandez par un geste ou un bouton.

## Où vont vos données

**Nulle part ailleurs que sur votre iPhone et chez Google.**

- L'application communique **directement** avec les serveurs de Google (`accounts.google.com`, `oauth2.googleapis.com`, `gmail.googleapis.com`). Il n'existe aucun serveur MailSwipe.
- Le développeur n'a **aucun accès** à vos mails, à votre compte ni à votre adresse.
- Aucun outil d'analyse, aucune publicité, aucun suivi, aucun SDK tiers.
- Vos données ne sont ni vendues, ni partagées, ni utilisées pour entraîner un modèle d'intelligence artificielle, ni lues par un humain.

## Ce qui est stocké sur l'appareil

- Le jeton d'accès à votre compte : dans le **Trousseau** iOS (Keychain), uniquement sur cet appareil.
- La liste des mails archivés et snoozés (expéditeur, objet, extrait) : dans un fichier protégé par iOS, exclu des sauvegardes.
- Les notifications de rappel de snooze sont locales et ne contiennent ni expéditeur ni objet.

Le mode démo utilise des mails fictifs et n'accède à aucun compte.

## Supprimer vos données

- **Se déconnecter** (Réglages → Se déconnecter de Gmail) efface le jeton et toutes les données locales.
- **Révoquer l'accès** à tout moment : <https://myaccount.google.com/permissions>.
- **Supprimer l'application** efface tout ce qu'elle a stocké.

## Conformité Google

L'utilisation par MailSwipe des informations reçues des API Google respecte la [politique relative aux données utilisateur des services d'API Google](https://developers.google.com/terms/api-services-user-data-policy), y compris les exigences d'utilisation limitée (*Limited Use*).

## Enfants

MailSwipe ne s'adresse pas aux enfants de moins de 13 ans.

## Modifications et contact

Toute modification sera publiée sur cette page. Pour toute question : <https://github.com/Fviret/MailSwipe/issues>.

---

# Privacy Policy — MailSwipe (English)

*Last updated: October 9, 2026*

MailSwipe is an iOS app that lets you triage your Gmail with gestures (reply, delete, archive, snooze). It is published by Florian Viret (Flo Viret Solutions).

## What the app can read and do

When you connect your Google account, MailSwipe requests:

| Google permission | Why |
|---|---|
| `https://www.googleapis.com/auth/gmail.modify` | Read your mail (sender, subject, snippet, and the message body when you open it), archive it, move it to trash, apply the "MailSwipe/Snoozed" label |
| `https://www.googleapis.com/auth/gmail.send` | Send the replies you write |
| `https://www.googleapis.com/auth/userinfo.email` | Show the address of the connected account |

MailSwipe only acts on a message when you ask it to, with a gesture or a button.

## Where your data goes

**Nowhere other than your iPhone and Google.**

- The app talks **directly** to Google's servers (`accounts.google.com`, `oauth2.googleapis.com`, `gmail.googleapis.com`). There is no MailSwipe server.
- The developer has **no access** to your mail, your account or your address.
- No analytics, no advertising, no tracking, no third-party SDKs.
- Your data is not sold, shared, used to train any AI model, or read by humans.

## What is stored on the device

- Your account access token: in the iOS **Keychain**, on this device only.
- The list of archived and snoozed mails (sender, subject, snippet): in a file protected by iOS and excluded from backups.
- Snooze reminder notifications are local and contain neither sender nor subject.

Demo mode uses fictional mail and does not access any account.

## Deleting your data

- **Signing out** (Settings → Sign out of Gmail) erases the token and all local data.
- **Revoke access** at any time: <https://myaccount.google.com/permissions>.
- **Deleting the app** removes everything it stored.

## Google compliance

MailSwipe's use and transfer to any other app of information received from Google APIs will adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

## Children

MailSwipe is not directed at children under 13.

## Changes and contact

Changes will be posted on this page. Questions: <https://github.com/Fviret/MailSwipe/issues>.
