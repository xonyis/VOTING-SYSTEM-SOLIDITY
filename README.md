# ReadMe Blockchain

Ce guide explique les étapes nécessaires pour installer et déployer le projet blockchain.

## Prérequis

Avant de commencer, assurez-vous d'avoir installé les éléments suivants :

- [Node.js](https://nodejs.org/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Rabit Wallet](https://rabby.io/)

1. **Cloner le dépôt**

```bash
  git clone https://github.com/xonyis/VOTING-SYSTEM-SOLIDITY.git
```
## Récupération des informations du wallet

Avant de commencer, vous aurez besoin d'un wallet avec des fonds sur le réseau Polygon Amoy (testnet) et des informations suivantes :

- **Clé privée** : clé privée de votre wallet
- **Adresse publique** : adresse publique de votre wallet

Assurez-vous de protéger votre clé privée.

## Comptes des utilisateurs

Recueillez les adresses publiques des utilisateurs pour leur transférer des tokens ou interagir avec eux.

## 1. Déployer les tokens

Déployez vos tokens sur Polygon Amoy avec :

```bash
forge create --rpc-url polygon_amoy --private-key <VOTRE_CLE_PRIVEE> src/GovernanceToken.sol:GovernanceToken --constructor-args "VOTES" "VOT" 10000000000000000000000 <VOTRE_ADRESSE> --legacy
```

### Explication :
- `--rpc-url polygon_amoy` : réseau Polygon Amoy.
- `--private-key` : clé privée de votre wallet.
- `src/GovernanceToken.sol:GovernanceToken` : contrat à déployer.
- `constructor-args` : paramètres du contrat (nom, symbole, montant initial, adresse réceptrice).

Récupérez l’adresse où le token a été déployé.

## 2. Déploiement du contrat VotingSystem

Déployez le contrat VotingSystem :

```bash
forge create --broadcast --rpc-url polygon_amoy --private-key <VOTRE_CLE_PRIVEE> src/VotingSystem.sol:VotingSystem --constructor-args <ADDRESS_TOKEN> 5000000000000000000000 8000 --legacy
```

### Explication :
- `--rpc-url polygon_amoy` : réseau Polygon Amoy.
- `--private-key` : clé privée de votre wallet.
- `src/VotingSystem.sol:VotingSystem` : contrat à déployer.
- `constructor-args` : paramètres du contrat (adresse token, 5000 token minimum pour créer une proposition, 80% du total des token doit avoir voter pour valider le vote).

Récupérez l’adresse où ce contrat a été déployé.

## 3. Mint de tokens supplémentaires

Lors du déploiement, 10 000 tokens sont mintés automatiquement. Il est recommandé d'en minter 10 000 supplémentaires pour les utilisateurs :

```bash
cast send --rpc-url polygon_amoy \
  --private-key <VOTRE_CLE_PRIVEE> <ADDRESS_TOKEN> \
  "mint(address,uint256)" \
  <VOTRE_ADRESSE> \
  10000000000000000000000 \
  --legacy
```

## 4. Transfert des tokens vers les utilisateurs

Transférez les tokens vers les utilisateurs avec la commande suivante :

```bash
cast send <ADDRESS_TOKEN> "transfer(address,uint256)(bool)" <ADRESSE_DESTINATAIRE> <MONTANT> --private-key <VOTRE_CLE_PRIVEE> --rpc-url polygon_amoy
```

Exemple pour transférer 1000 tokens :

`<MONTANT> = 1000000000000000000000`

## 5. Fichier `.env` (Vue)

Ajoutez ces deux adresses au fichier `.env` à la racine du projet voting-app :

```env
VITE_CONTRACT_ADDRESS=0x123...
VITE_TOKEN_ADDRESS=0xABC...
```

## 6. Exécuter le projet Vue (voting-app)

Exécutez ces commandes à la racine du dossier Vue :

```bash
npm install
npm run dev
```

Si toutes les modifications ont été correctement réalisées, bravo ! 🎉

