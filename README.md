# CalBalance

Application iOS de suivi du bilan calorique (calories consommées vs dépensées), avec :
- Connexion à **Apple Santé (HealthKit)** pour récupérer votre activité réelle (calories actives, calories au repos, pas, exercice)
- Ajout de repas **par photo**, analysés par l'IA (Claude Vision) qui identifie les aliments et estime les quantités/calories, avec confirmation/ajustement manuel via une base de données locale
- **Statistiques** jour / semaine / mois / année (graphiques Swift Charts)
- **Rappels programmables** pour manger et boire à des heures personnalisées

## ⚠️ Important : compiler sans Mac via GitHub Actions

iOS ne peut être compilé que par Xcode (macOS uniquement) — c'est une contrainte d'Apple. Comme vous n'avez pas de Mac, ce projet inclut un pipeline **GitHub Actions** ([.github/workflows/build.yml](.github/workflows/build.yml)) qui compile automatiquement l'app sur une machine macOS gratuite fournie par GitHub, à chaque `git push`. C'est la méthode décrite ci-dessous (section "Compiler sans Mac"). Une section alternative "Avec un Mac" reste plus bas si vous en obtenez un accès plus tard (test réel sur simulateur/iPhone, publication App Store).

## Compiler sans Mac (GitHub Actions)

### 1. Créer le dépôt GitHub

1. Sur [github.com/new](https://github.com/new), créez un dépôt (public ou privé, peu importe — les runners macOS gratuits fonctionnent pour les deux, avec un quota mensuel plus généreux en public).
2. Ne cochez aucune case d'initialisation (pas de README/gitignore, le projet en a déjà).
3. Copiez l'URL du dépôt (ex. `https://github.com/votre-compte/calbalance.git`).

### 2. Pousser le code

Depuis ce dossier `CalBalance/` :
```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/votre-compte/calbalance.git
git push -u origin main
```

### 3. Suivre le build

1. Sur GitHub, ouvrez l'onglet **Actions** du dépôt : le workflow "Build CalBalance (iOS Simulator)" se lance automatiquement.
2. Il installe XcodeGen, génère le projet Xcode, puis compile l'app pour le simulateur iOS (sans certificat de signature — juste pour vérifier que le code compile).
3. Un ✅ vert confirme que tout compile correctement. Un ❌ rouge affiche les erreurs de compilation dans les logs, à corriger comme n'importe quelle erreur de build.
4. Relancez manuellement le workflow à tout moment depuis l'onglet Actions (bouton "Run workflow") après avoir poussé des modifications.

### Limites de cette approche

- **Pas d'interface graphique interactive** : vous ne pouvez pas "voir" l'app tourner en direct pendant que vous codez, contrairement à un Mac local ou un Mac loué à distance. Le CI confirme seulement que le code compile.
- **Pas de test réel HealthKit/caméra** : ces fonctionnalités nécessitent un simulateur interactif (HealthKit limité) ou un iPhone physique (caméra, vraies données Santé) — impossibles à valider uniquement via CI.
- **Pas de build signé/IPA installable** pour l'instant : la génération d'un `.ipa` installable sur un iPhone ou publiable sur l'App Store nécessite un compte Apple Developer (99$/an) et des certificats de signature stockés en secrets GitHub. Dites-moi quand vous aurez ce compte et j'étendrai le workflow (avec `fastlane`) pour aller jusqu'à l'upload App Store Connect automatique, toujours sans Mac.

Pour un vrai test interactif de l'app (voir l'écran, tester la caméra, HealthKit), la solution la plus proche d'un Mac reste un **Mac loué à distance** (MacinCloud, MacStadium, Scaleway Mac mini — quelques dizaines de dollars par mois ou à l'heure) : dites-le moi si vous voulez basculer sur cette option en complément.

## Avec un Mac (si vous y avez accès plus tard)

## Étape 1 — Prérequis sur votre Mac

1. **Xcode** (gratuit) : installez-le depuis le Mac App Store. Version 15+ recommandée (pour iOS 17).
2. **XcodeGen** : outil qui génère le fichier de projet Xcode (`.xcodeproj`) à partir du fichier `project.yml` inclus. Sans lui, il faudrait recréer le projet à la main dans Xcode et y glisser tous les fichiers, ce qui est plus long et source d'erreurs.
   ```bash
   brew install xcodegen
   ```
   (Si vous n'avez pas Homebrew : installez-le depuis [brew.sh](https://brew.sh), c'est le gestionnaire de paquets standard sur Mac.)
3. Un **compte Apple Developer** (99$/an) — nécessaire uniquement pour tester sur un iPhone physique et publier sur l'App Store. Pas nécessaire pour tester sur le simulateur iOS inclus dans Xcode.
4. Une **clé API Anthropic** (pour la reconnaissance photo des aliments) — créez un compte sur [console.anthropic.com](https://console.anthropic.com) et générez une clé. Cette clé sera saisie directement dans l'app (écran Profil), jamais dans le code — elle est stockée dans le Keychain de l'appareil.

## Étape 2 — Transférer et générer le projet

1. Copiez tout le dossier `CalBalance/` sur votre Mac (clé USB, AirDrop, Git, cloud...).
2. Ouvrez le Terminal, placez-vous dans le dossier :
   ```bash
   cd chemin/vers/CalBalance
   xcodegen generate
   ```
   Cela crée `CalBalance.xcodeproj`.
3. Ouvrez-le : `open CalBalance.xcodeproj`.

## Étape 3 — Configurer la capability HealthKit dans Xcode

XcodeGen configure déjà l'entitlement HealthKit dans `CalBalance.entitlements`, mais il faut vérifier dans Xcode :
1. Sélectionnez le projet `CalBalance` dans le navigateur > cible `CalBalance` > onglet **Signing & Capabilities**.
2. Dans **Signing**, sélectionnez votre **Team** (votre compte Apple Developer, ou votre Apple ID personnel pour tester en simulateur/appareil perso sans compte payant).
3. Vérifiez que la capability **HealthKit** apparaît dans la liste. Si elle n'apparaît pas, cliquez sur **+ Capability** et ajoutez-la manuellement.

## Étape 4 — Lancer l'app

1. Choisissez un simulateur (ex. iPhone 15 Pro) dans la barre d'outils Xcode.
2. Cliquez sur ▶️ (Run) ou `Cmd+R`.
3. **Note simulateur** : le simulateur iOS n'a pas de vraies données Apple Santé ni de caméra. Pour tester HealthKit et la caméra réellement, utilisez un iPhone physique connecté (nécessite de faire confiance au certificat de développement dans Réglages > Général > VPN et gestion de l'appareil, sur l'iPhone).
4. Au premier lancement, l'app demande l'autorisation d'accès à Apple Santé puis aux notifications (écran d'onboarding).
5. Allez dans l'onglet **Profil** pour renseigner vos infos (âge, poids, taille, activité, objectif) et coller votre clé API Anthropic.

## Étape 5 — Publier sur l'App Store (quand vous êtes prêt)

1. Compte Apple Developer actif obligatoire (99$/an, sur [developer.apple.com](https://developer.apple.com)).
2. Dans Xcode : **Product > Archive** (nécessite un appareil/certificat de distribution, pas le simulateur).
3. Une fois l'archive créée, **Distribute App > App Store Connect > Upload**.
4. Créez la fiche de l'app sur [App Store Connect](https://appstoreconnect.apple.com) (nom, description, captures d'écran, catégorie "Santé et forme").
5. Soumettez pour review Apple (délai généralement 24-48h).

**Point d'attention review Apple** : les apps utilisant HealthKit doivent avoir une politique de confidentialité claire (obligatoire pour la soumission) expliquant l'usage des données de santé — à rédiger et héberger avant soumission (ex. simple page web).

## Structure du projet

```
CalBalance/
├── project.yml                    # Config XcodeGen (cible, capabilities, Info.plist)
├── CalBalance/
│   ├── CalBalanceApp.swift        # Point d'entrée, conteneur SwiftData, injection des services
│   ├── Models/                    # Meal, FoodItem, UserProfile, ReminderSetting (SwiftData)
│   ├── Services/
│   │   ├── HealthKitManager.swift     # Lecture activité / écriture calories consommées
│   │   ├── CalorieCalculator.swift    # BMR (Mifflin-St Jeor), TDEE, agrégations jour/semaine/mois/année
│   │   ├── FoodVisionService.swift    # Appel API Claude pour analyser une photo de repas
│   │   ├── FoodDatabase.swift         # Recherche dans la base locale d'aliments
│   │   ├── NotificationManager.swift  # Planification des rappels manger/boire
│   │   └── KeychainStore.swift        # Stockage sécurisé de la clé API
│   ├── ViewModels/                 # Logique par écran (MVVM)
│   ├── Views/                      # Écrans SwiftUI
│   └── Resources/CommonFoods.json  # ~90 aliments courants avec valeurs nutritionnelles
```

## Comment fonctionne le calcul du bilan calorique

- **Calories dépensées** = calories actives (mouvement/sport, mesurées par l'iPhone/Apple Watch via HealthKit) + calories au repos mesurées par Apple Santé quand disponibles, sinon métabolisme de base calculé par la formule de **Mifflin-St Jeor** (la plus précise reconnue scientifiquement) à partir de votre âge/poids/taille/sexe.
- **Calories consommées** = somme des repas enregistrés dans l'app (détectés par photo + ajustés manuellement, ou saisis manuellement).
- **Objectif quotidien** = BMR + activité réelle, ajusté de -500 kcal (perte de poids), 0 (maintien) ou +400 kcal (prise de poids) — des marges modérées et durables recommandées en nutrition.
- Chaque repas enregistré est aussi écrit dans Apple Santé (calories alimentaires) pour centraliser vos données dans l'écosystème Apple Health.

## Limites connues du MVP à garder en tête

- La reconnaissance photo dépend de la qualité de l'estimation de l'IA sur les portions — toujours vérifiable/ajustable manuellement avant sauvegarde, exactement pour cette raison.
- La base de données locale (~90 aliments) couvre les aliments courants mais pas un catalogue exhaustif type USDA ; un aliment absent peut être ajouté en ajustant simplement un aliment proche.
- Pas de scan de code-barres dans le MVP (mentionné comme piste d'évolution possible).
- La clé API Anthropic est à la charge de l'utilisateur (facturation à l'usage sur console.anthropic.com) — aucune clé n'est ni ne peut être intégrée dans l'app par sécurité.
