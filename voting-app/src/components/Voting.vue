<template>
    <div v-if="isOpen" class="vote-modal-overlay">
      <div class="vote-modal">
        <div class="modal-header">
          <h3>Voter sur la proposition #{{ proposal.id }}</h3>
          <button @click="onClose" class="close-button">&times;</button>
        </div>
  
        <div class="modal-content">
          <div class="proposal-info">
            <p class="proposal-description">{{ proposal?.description }}</p>
            <div class="proposal-details">
              <div class="detail">
                <span class="detail-label">Proposeur:</span>
                <span class="detail-value">{{ shortenAddress(proposal?.proposer) }}</span>
              </div>
              <div class="detail">
                <span class="detail-label">Date de clôture:</span>
                <span class="detail-value">{{ formatDate(proposal?.closingTime) }}</span>
              </div>
            </div>
          </div>
          
          <div class="vote-options">
            <h4>Choisissez votre vote:</h4>
            <div class="options-container">
              <button 
                @click="selectedVote = true" 
                :class="['vote-option', { selected: selectedVote === true }]"
              >
                <div class="option-icon for">✓</div>
                <div class="option-label">Pour</div>
              </button>
              
              <button 
                @click="selectedVote = false" 
                :class="['vote-option', { selected: selectedVote === false }]"
              >
                <div class="option-icon against">✗</div>
                <div class="option-label">Contre</div>
              </button>
            </div>
          </div>
          
          <div v-if="error" class="error-message">
            {{ error }}
          </div>
          
          <div v-if="transactionStatus" class="transaction-status">
            <div v-if="transactionStatus === 'checking-allowance'" class="status pending">
              <div class="spinner"></div>
              <span>Vérification de l'approbation...</span>
            </div>
            <div v-else-if="transactionStatus === 'approving'" class="status pending">
              <div class="spinner"></div>
              <span>Approbation des tokens en cours...</span>
            </div>
            <div v-else-if="transactionStatus === 'pending'" class="status pending">
              <div class="spinner"></div>
              <span>Vote en cours...</span>
            </div>
            <div v-else-if="transactionStatus === 'success'" class="status success">
              <div class="success-icon">✓</div>
              <span>Vote enregistré avec succès!</span>
            </div>
            <div v-else-if="transactionStatus === 'error'" class="status error">
              <div class="error-icon">✗</div>
              <span>Erreur: {{ errorMessage }}</span>
            </div>
          </div>
          
          <!-- Section d'aide -->
          <div v-if="transactionStatus === 'error'" class="help-section">
            <h4>Problèmes courants lors du vote:</h4>
            <ul>
              <li>Vous avez peut-être déjà voté pour cette proposition</li>
              <li>Vous n'avez peut-être pas les jetons nécessaires pour voter</li>
              <li>La période de vote est peut-être terminée</li>
              <li>Vous devez être connecté avec le même compte qui détient les jetons</li>
            </ul>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            @click="onClose" 
            class="cancel-button"
            :disabled="transactionStatus === 'pending' || transactionStatus === 'approving'"
          >
            Annuler
          </button>
          
          <button 
            @click="submitVote" 
            class="submit-button"
            :disabled="selectedVote === null || transactionStatus === 'pending' || transactionStatus === 'approving' || !isConnected"
          >
            <span v-if="transactionStatus === 'pending' || transactionStatus === 'approving'" class="button-spinner"></span>
            {{ getButtonText() }}
          </button>
        </div>
      </div>
    </div>
  </template>
  
  <script setup>
  import { ref, watch, computed, onMounted } from 'vue';
  import { parseAbi } from 'viem';
  import { useAccount, useWriteContract, useReadContract } from '@wagmi/vue';
  // Importez ethers correctement
  import * as ethers from 'ethers';
  
  // Props
  const props = defineProps({
    isOpen: {
      type: Boolean,
      required: true
    },
    proposal: {
      type: Object,
      default: null
    },
    onClose: {
      type: Function,
      required: true
    },
    onVoteSuccess: {
      type: Function,
      required: true
    }
  });
  
  // État du composant
  const selectedVote = ref(null);
  const transactionStatus = ref(null);
  const error = ref(null);
  const errorMessage = ref('');
  
  // Modifiez cette partie du code pour corriger le problème de détection de succès
  // Hook pour l'approbation - Utiliser ref pour les valeurs réactives
  const approvalHash = ref(null);
  const isWaitingForApproval = ref(false);
  const isApprovalSuccess = ref(false);
  
  // Hook pour le vote - Utiliser ref pour les valeurs réactives
  const voteHash = ref(null);
  const isWaitingForVote = ref(false);
  const isVoteSuccess = ref(false);
  
  // Récupérer l'adresse du compte connecté
  const { address, isConnected } = useAccount();
  
  // Adresses des contrats
  // Utilisez l'adresse de votre nouveau contrat déployé
  const VOTING_CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS;
  const TOKEN_CONTRACT_ADDRESS = import.meta.env.VITE_TOKEN_ADDRESS;
  
  // ABI du contrat de vote - Mise à jour pour inclure la fonction checkVotingStatus
  const votingAbi = parseAbi([
    "function castVote(uint256 proposalId, bool support) external",
    "function checkVotingStatus(uint256 proposalId, address voter) external view returns (uint256 userBalance, uint256 userAllowance, bool userHasVoted, uint256 voterStake, bool voteSupport, uint256 forVotes, uint256 againstVotes)"
  ]);
  
  // ABI du contrat de token
  const tokenAbi = parseAbi([
    "function approve(address spender, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function balanceOf(address account) view returns (uint256)"
  ]);
  
  // Utiliser les hooks Wagmi
  const { writeContractAsync } = useWriteContract();
  
  // Vérifier l'approbation actuelle
  const { data: currentAllowance, refetch: refetchAllowance } = useReadContract({
    address: TOKEN_CONTRACT_ADDRESS,
    abi: tokenAbi,
    functionName: 'allowance',
    args: address.value ? [address.value, VOTING_CONTRACT_ADDRESS] : undefined,
    enabled: !!address.value,
  });
  
  // Vérifier le solde de tokens
  const { data: tokenBalance, refetch: refetchBalance } = useReadContract({
    address: TOKEN_CONTRACT_ADDRESS,
    abi: tokenAbi,
    functionName: 'balanceOf',
    args: address.value ? [address.value] : undefined,
    enabled: !!address.value,
  });
  
  // Vérifier le statut de vote
  const { data: votingStatus, refetch: refetchVotingStatus } = useReadContract({
    address: VOTING_CONTRACT_ADDRESS,
    abi: votingAbi,
    functionName: 'checkVotingStatus',
    args: address.value && props.proposal?.id ? [BigInt(props.proposal.id), address.value] : undefined,
    enabled: !!address.value && !!props.proposal?.id,
  });
  
  // Réinitialiser l'état lorsque le modal s'ouvre/se ferme
  watch(() => props.isOpen, (isOpen) => {
    if (isOpen) {
      selectedVote.value = null;
      transactionStatus.value = null;
      error.value = null;
      errorMessage.value = '';
      approvalHash.value = null;
      voteHash.value = null;
      isWaitingForApproval.value = false;
      isApprovalSuccess.value = false;
      isWaitingForVote.value = false;
      isVoteSuccess.value = false;
      
      // Rafraîchir les données
      if (address.value) {
        refetchAllowance();
        refetchBalance();
        if (props.proposal?.id) {
          refetchVotingStatus();
        }
      }
    }
  });
  
  // Texte du bouton en fonction de l'état
  function getButtonText() {
    if (transactionStatus.value === 'checking-allowance') return 'Vérification...';
    if (transactionStatus.value === 'approving') return 'Approbation...';
    if (transactionStatus.value === 'pending') return 'Vote en cours...';
    
    // Si l'approbation est nécessaire
    if (needsApproval.value) return 'Approuver et voter';
    
    return 'Voter';
  }
  
  // Vérifier si l'approbation est nécessaire
  const needsApproval = computed(() => {
    if (!currentAllowance.value || !tokenBalance.value) return true;
    return currentAllowance.value < tokenBalance.value;
  });
  
  // Fonction pour surveiller manuellement l'approbation
  async function watchApprovalTransaction(hash) {
    if (!hash) return;
    
    try {
      isWaitingForApproval.value = true;
      console.log("Surveillance de la transaction d'approbation:", hash);
      
      // Utiliser le provider directement pour vérifier la transaction
      const { ethereum } = window;
      if (!ethereum) throw new Error("MetaMask non détecté");
      
      // Créer le provider avec la bonne syntaxe pour ethers v6
      const provider = new ethers.BrowserProvider(ethereum);
      const receipt = await provider.waitForTransaction(hash, 1); // Attendre 1 confirmation
      
      console.log("Reçu de transaction:", receipt);
      
      if (receipt.status === 1) {
        console.log("Transaction d'approbation réussie!");
        isApprovalSuccess.value = true;
        
        
        
        // Rafraîchir l'approbation
        await refetchAllowance();
        
        // Continuer avec le vote
        await castVote();
      } else {
        console.error("La transaction d'approbation a échoué");
        transactionStatus.value = 'error';
        errorMessage.value = "L'approbation a échoué. Veuillez réessayer.";
      }
    } catch (err) {
      console.error("Erreur lors de la surveillance de la transaction:", err);
      transactionStatus.value = 'error';
      errorMessage.value = `Erreur: ${err.message || 'Erreur inconnue'}`;
    } finally {
      isWaitingForApproval.value = false;
    }
  }
  
  // Fonction pour surveiller manuellement le vote
  async function watchVoteTransaction(hash) {
    if (!hash) return;
    
    try {
      isWaitingForVote.value = true;
      console.log("Surveillance de la transaction de vote:", hash);
      
      // Utiliser le provider directement pour vérifier la transaction
      const { ethereum } = window;
      if (!ethereum) throw new Error("MetaMask non détecté");
      
      // Créer le provider avec la bonne syntaxe pour ethers v6
      const provider = new ethers.BrowserProvider(ethereum);
      const receipt = await provider.waitForTransaction(hash, 1); // Attendre 1 confirmation
      
      console.log("Reçu de transaction:", receipt);
      
      if (receipt.status === 1) {
        console.log("Transaction de vote réussie!");
        isVoteSuccess.value = true;
        transactionStatus.value = 'success';
        
        // Notifier le composant parent du succès
        props.onVoteSuccess();
      } else {
        console.error("La transaction de vote a échoué");
        transactionStatus.value = 'error';
        errorMessage.value = "Le vote a échoué. Veuillez réessayer.";
      }
    } catch (err) {
      console.error("Erreur lors de la surveillance de la transaction:", err);
      transactionStatus.value = 'error';
      errorMessage.value = `Erreur: ${err.message || 'Erreur inconnue'}`;
    } finally {
      isWaitingForVote.value = false;
    }
  }
  
  // Approuver les tokens
  async function approveTokens() {
    if (!isConnected.value) return;
  
    transactionStatus.value = 'approving';
    error.value = null;
  
    try {
      console.log("Approbation des tokens...");
      
      // Approuver un montant important pour ne pas avoir à réapprouver à chaque fois
      // Utiliser MaxUint256 pour une approbation illimitée
      const approvalAmount = 115792089237316195423570985008687907853269984665640564039457584007913129639935n; // 2^256 - 1
      
      const hash = await writeContractAsync({
        address: TOKEN_CONTRACT_ADDRESS,
        abi: tokenAbi,
        functionName: 'approve',
        args: [VOTING_CONTRACT_ADDRESS, approvalAmount],
      });
      
      console.log("Approbation envoyée, hash:", hash);
      approvalHash.value = hash;
      
      // Surveiller manuellement la transaction
      watchApprovalTransaction(hash);
      
    } catch (err) {
      console.error("Erreur lors de l'approbation:", err);
      transactionStatus.value = 'error';
      errorMessage.value = `Erreur d'approbation: ${err.message || 'Erreur inconnue'}`;
    }
  }
  
  // Voter
  async function castVote() {
    if (selectedVote.value === null || !props.proposal) {
      console.error("Impossible de voter: selectedVote ou proposal est null", {
        selectedVote: selectedVote.value,
        proposal: props.proposal
      });
      return;
    }
  
    transactionStatus.value = 'pending';
    error.value = null;
  
    try {
      // Convertir l'ID de la proposition en BigInt et s'assurer que selectedVote est un booléen
      const proposalId = BigInt(props.proposal.id);
      const support = Boolean(selectedVote.value);
      
      console.log(`Soumission du vote pour la proposition #${props.proposal.id}: ${support ? 'Pour' : 'Contre'}`);
      
      // Appeler la fonction castVote du contrat avec une limite de gaz explicite
      const hash = await writeContractAsync({
        address: VOTING_CONTRACT_ADDRESS,
        abi: votingAbi,
        functionName: 'castVote',
        args: [proposalId, support],
        gas: 500000n, // Limite de gaz explicite
      });
      
      console.log("Vote soumis, hash:", hash);
      voteHash.value = hash;
      
      // Surveiller manuellement la transaction
      watchVoteTransaction(hash);
      
    } catch (err) {
      console.error("Erreur lors du vote:", err);
      console.error("Détails de l'erreur:", err);
      transactionStatus.value = 'error';
      
      // Analyser l'erreur pour fournir un message plus précis
      if (err.message) {
        if (err.message.includes("already voted") || err.message.includes("Already voted") || err.message.includes("hasVoted")) {
          errorMessage.value = "Vous avez déjà voté pour cette proposition.";
        } else if (err.message.includes("voting is closed") || err.message.includes("Voting period has ended")) {
          errorMessage.value = "La période de vote est terminée.";
        } else if (err.message.includes("no voting rights") || err.message.includes("No voting power")) {
          errorMessage.value = "Vous n'avez pas les jetons nécessaires pour voter.";
        } else if (err.message.includes("Insufficient allowance")) {
          errorMessage.value = "Allowance insuffisante. Veuillez approuver plus de tokens.";
        } else if (err.message.includes("execution reverted")) {
          errorMessage.value = "La transaction a été rejetée par le contrat. Consultez la section d'aide ci-dessous.";
        } else {
          errorMessage.value = err.message.substring(0, 100) + (err.message.length > 100 ? '...' : '');
        }
      } else {
        errorMessage.value = "Une erreur s'est produite lors du vote.";
      }
    }
  }
  
  // Soumettre le vote (avec vérification d'approbation)
  async function submitVote() {
    if (selectedVote.value === null || !props.proposal || !isConnected.value) {
      if (!isConnected.value) {
        error.value = "Vous devez être connecté pour voter.";
      }
      return;
    }
    
    // Vérifier si la proposition est encore en période de vote
    const now = Math.floor(Date.now() / 1000);
    if (props.proposal.closingTime <= now) {
      error.value = "La période de vote pour cette proposition est terminée.";
      return;
    }
    
    // Réinitialiser les erreurs
    error.value = null;
    errorMessage.value = '';
    
    // Vérifier l'approbation
    transactionStatus.value = 'checking-allowance';
    await refetchAllowance();
    await refetchBalance();
    
    if (needsApproval.value) {
      // Si une approbation est nécessaire, l'effectuer d'abord
      await approveTokens();
    } else {
      // Sinon, voter directement
      await castVote();
    }
  }
  
  // Fonctions utilitaires
  function shortenAddress(address) {
    if (!address) return '';
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  }
  
  function formatDate(timestamp) {
    if (!timestamp) return '';
    const date = new Date(timestamp * 1000);
    return date.toLocaleString();
  }
  
  // Afficher des informations de débogage au montage du composant
  onMounted(async () => {
    if (address.value) {
      await refetchAllowance();
      await refetchBalance();
      
      console.log("Adresse connectée:", address.value);
      console.log("Adresse du contrat de vote:", VOTING_CONTRACT_ADDRESS);
      console.log("Adresse du contrat de token:", TOKEN_CONTRACT_ADDRESS);
      
      if (currentAllowance.value) {
        console.log("Allowance actuelle:", currentAllowance.value.toString());
      }
      
      if (tokenBalance.value) {
        console.log("Solde de tokens:", tokenBalance.value.toString());
      }
    }
  });
  </script>
  
  <style scoped>
  /* Le style reste inchangé */
  .vote-modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  
  .vote-modal {
    background-color: white;
    border-radius: 0.5rem;
    width: 90%;
    max-width: 500px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    display: flex;
    flex-direction: column;
  }
  
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .modal-header h3 {
    margin: 0;
    font-size: 1.25rem;
    color: #111827;
  }
  
  .close-button {
    background: none;
    border: none;
    font-size: 1.5rem;
    color: #6b7280;
    cursor: pointer;
  }
  
  .modal-content {
    padding: 1.5rem;
    flex: 1;
  }
  
  .proposal-info {
    margin-bottom: 1.5rem;
  }
  
  .proposal-description {
    font-size: 1rem;
    color: #1f2937;
    margin-bottom: 1rem;
  }
  
  .proposal-details {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 0.75rem;
  }
  
  .detail {
    display: flex;
    flex-direction: column;
  }
  
  .detail-label {
    font-size: 0.75rem;
    color: #6b7280;
    margin-bottom: 0.25rem;
  }
  
  .detail-value {
    font-weight: 500;
    color: #1f2937;
  }
  
  .vote-options {
    margin-bottom: 1.5rem;
  }
  
  .vote-options h4 {
    margin-top: 0;
    margin-bottom: 0.75rem;
    font-size: 1rem;
    color: #374151;
  }
  
  .options-container {
    display: flex;
    gap: 1rem;
  }
  
  .vote-option {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 1rem;
    border: 2px solid #e5e7eb;
    border-radius: 0.375rem;
    background-color: white;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .vote-option:hover {
    border-color: #d1d5db;
  }
  
  .vote-option.selected {
    border-color: #6366f1;
    background-color: #f5f5ff;
  }
  
  .option-icon {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.25rem;
    margin-bottom: 0.5rem;
  }
  
  .option-icon.for {
    background-color: #10b981;
    color: white;
  }
  
  .option-icon.against {
    background-color: #ef4444;
    color: white;
  }
  
  .option-label {
    font-weight: 500;
    color: #374151;
  }
  
  .error-message {
    padding: 0.75rem;
    background-color: #fee2e2;
    border: 1px solid #fecaca;
    border-radius: 0.375rem;
    color: #b91c1c;
    margin-bottom: 1rem;
  }
  
  .transaction-status {
    margin-top: 1rem;
  }
  
  .status {
    display: flex;
    align-items: center;
    padding: 0.75rem;
    border-radius: 0.375rem;
    margin-bottom: 1rem;
  }
  
  .status.pending {
    background-color: #eff6ff;
    border: 1px solid #dbeafe;
    color: #1e40af;
  }
  
  .status.success {
    background-color: #f0fdf4;
    border: 1px solid #dcfce7;
    color: #166534;
  }
  
  .status.error {
    background-color: #fee2e2;
    border: 1px solid #fecaca;
    color: #b91c1c;
  }
  
  .help-section {
    margin-top: 1.5rem;
    padding: 1rem;
    background-color: #f9fafb;
    border-radius: 0.375rem;
    border: 1px solid #e5e7eb;
  }
  
  .help-section h4 {
    margin-top: 0;
    margin-bottom: 0.5rem;
    font-size: 0.875rem;
    color: #4b5563;
  }
  
  .help-section ul {
    margin: 0;
    padding-left: 1.5rem;
    font-size: 0.875rem;
    color: #6b7280;
  }
  
  .help-section li {
    margin-bottom: 0.25rem;
  }
  
  .spinner {
    border: 2px solid rgba(99, 102, 241, 0.1);
    border-top: 2px solid #6366f1;
    border-radius: 50%;
    width: 16px;
    height: 16px;
    animation: spin 1s linear infinite;
    margin-right: 0.5rem;
  }
  
  .button-spinner {
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top: 2px solid white;
    border-radius: 50%;
    width: 16px;
    height: 16px;
    animation: spin 1s linear infinite;
    margin-right: 0.5rem;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  .success-icon, .error-icon {
    width: 16px;
    height: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    margin-right: 0.5rem;
    font-size: 0.75rem;
  }
  
  .success-icon {
    background-color: #10b981;
    color: white;
  }
  
  .error-icon {
    background-color: #ef4444;
    color: white;
  }
  
  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
    padding: 1rem 1.5rem;
    border-top: 1px solid #e5e7eb;
  }
  
  .cancel-button, .submit-button {
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .cancel-button {
    background-color: #f3f4f6;
    color: #4b5563;
    border: none;
  }
  
  .cancel-button:hover {
    background-color: #e5e7eb;
  }
  
  .submit-button {
    background-color: #6366f1;
    color: white;
    border: none;
  }
  
  .submit-button:hover {
    background-color: #4f46e5;
  }
  
  .submit-button:disabled, .cancel-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  </style>
  
  