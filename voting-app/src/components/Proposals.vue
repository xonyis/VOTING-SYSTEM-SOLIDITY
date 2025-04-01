<script setup>
import { ref, watch, onMounted, computed } from 'vue';
import { parseAbi, formatUnits } from 'viem';
import { useReadContract } from '@wagmi/vue';
import { writeContract } from '@wagmi/core';

// Props
const props = defineProps({
  isOpen: {
    type: Boolean,
    required: true
  },
  proposalId: {
    type: Number,
    required: true
  },
  onClose: {
    type: Function,
    required: true
  },
  onVoteClick: {
    type: Function,
    required: true
  },
  onExecuteSuccess: {
    type: Function,
    required: true
  }
});

// État du composant
const loading = ref(true);
const error = ref(null);
const proposalDetails = ref(null);
const isExecuting = ref(false);

// Adresse du contrat
const CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS;

// ABI du contrat
const abi = parseAbi([
  "function getProposalDetails(uint256) view returns (address proposer, string description, uint256 forVotes, uint256 againstVotes, uint256 closingTime, bool executed, bool tokensReturned, bool quorumReached, bool acceptedWithoutQuorum, string quorumStatus, bool passed)",
  "function executeProposal(uint256 proposalId) returns ()"
]);

// Computed property pour vérifier si proposalId est valide
const validProposalId = computed(() => {
  return props.proposalId !== null && props.proposalId !== undefined && !isNaN(props.proposalId);
});

// Computed property pour les arguments de la fonction
const functionArgs = computed(() => {
  return validProposalId.value ? [BigInt(props.proposalId)] : undefined;
});

// Utiliser useReadContract pour récupérer les détails de la proposition
const { 
  data: proposalData, 
  isLoading: isProposalLoading, 
  isError: isProposalError,
  error: proposalError,
  refetch 
} = useReadContract({
  address: CONTRACT_ADDRESS,
  abi,
  functionName: 'getProposalDetails',
  args: functionArgs,
  // Ne pas activer la requête automatiquement, nous la déclencherons manuellement
  enabled: false,
});

// Observer les changements des données de la proposition
watch([proposalData, isProposalLoading, isProposalError], ([data, isLoading, hasError]) => {
  loading.value = isLoading;
  
  if (hasError) {
    console.error("Erreur lors du chargement des détails de la proposition:", proposalError.value);
    error.value = "Impossible de charger les détails de la proposition";
  } else if (data) {
    proposalDetails.value = data;
    console.log("Détails de la proposition chargés:", data);
  }
});

// Observer l'ouverture du modal et l'ID de proposition pour recharger les données
watch([() => props.isOpen, () => props.proposalId], ([isOpen, proposalId]) => {
  console.log("Modal ouvert:", isOpen, "ID de proposition:", proposalId);
  
  if (isOpen && validProposalId.value) {
    loading.value = true;
    error.value = null;
    console.log("Chargement des détails pour l'ID:", proposalId);
    refetch();
  }
});

// Exécuter la proposition
async function executeProposal() {
  if (!proposalDetails.value || !validProposalId.value) return;
  
  isExecuting.value = true;

  try {
    await writeContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: 'executeProposal',
      args: [BigInt(props.proposalId)],
    });
    
    // Mettre à jour les détails localement
    const updatedDetails = [...proposalDetails.value];
    updatedDetails[5] = true; // Marquer comme exécutée
    proposalDetails.value = updatedDetails;
    
    // Notifier le composant parent
    props.onExecuteSuccess(props.proposalId);
    
  } catch (err) {
    console.error("Erreur lors de l'exécution de la proposition:", err);
    error.value = "Erreur lors de l'exécution: " + err.message;
  } finally {
    isExecuting.value = false;
  }
}

// Ouvrir le modal de vote
function openVoteModal() {
  // Fermer ce modal
  props.onClose();
  
  // Notifier le parent pour ouvrir le modal de vote
  props.onVoteClick(props.proposalId);
}

// Fonctions utilitaires
function shortenAddress(address) {
  if (!address) return '';
  return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
}

function formatDate(timestamp) {
  if (!timestamp) return '';
  // Ajuster pour le décalage de timestamp dans le contrat
  const adjustedTimestamp = Number(timestamp) - 2417100;
  const date = new Date(adjustedTimestamp * 1000);
  return date.toLocaleString();
}

function formatVotes(votes) {
  if (!votes) return '0';
  return parseFloat(formatUnits(votes, 18)).toLocaleString(undefined, {
    maximumFractionDigits: 0
  });
}

function getTotalVotes() {
  if (!proposalDetails.value) return 0n;
  return proposalDetails.value[2] + proposalDetails.value[3];
}

function getForPercentage() {
  if (!proposalDetails.value) return 0;
  const totalVotes = getTotalVotes();
  if (totalVotes === 0n) return 0;
  
  return Math.round(Number((proposalDetails.value[2] * 100n) / totalVotes));
}

function getAgainstPercentage() {
  return 100 - getForPercentage();
}

function getStatusLabel() {
  if (!proposalDetails.value) return '';
  
  if (proposalDetails.value[5]) return 'Exécutée';
  
  // Ajuster pour le décalage de timestamp dans le contrat
  const closingTime = Number(proposalDetails.value[4]) - 2417100;
  const now = Math.floor(Date.now() / 1000);
  
  if (closingTime > now) return 'En cours';
  return 'En attente';
}

function getStatusClass() {
  if (!proposalDetails.value) return '';
  
  if (proposalDetails.value[5]) return 'executed';
  
  // Ajuster pour le décalage de timestamp dans le contrat
  const closingTime = Number(proposalDetails.value[4]) - 2417100;
  const now = Math.floor(Date.now() / 1000);
  
  if (closingTime > now) return 'active';
  return 'pending';
}

function canVote() {
  if (!proposalDetails.value) return false;
  
  if (proposalDetails.value[5]) return false;
  
  // Ajuster pour le décalage de timestamp dans le contrat
  const closingTime = Number(proposalDetails.value[4]) - 2417100;
  const now = Math.floor(Date.now() / 1000);
  
  return closingTime > now;
}

function canExecute() {
  if (!proposalDetails.value) return false;
  
  if (proposalDetails.value[5]) return false;
  
  // Ajuster pour le décalage de timestamp dans le contrat
  const closingTime = Number(proposalDetails.value[4]) - 2417100;
  const now = Math.floor(Date.now() / 1000);
  
  return closingTime <= now;
}

// Charger les détails au montage si le modal est ouvert et l'ID est valide
onMounted(() => {
  if (props.isOpen && validProposalId.value) {
    console.log("Chargement initial des détails pour l'ID:", props.proposalId);
    refetch();
  }
});
</script>

<template>
  <div v-if="isOpen" class="details-modal-overlay">
    <div class="details-modal">
      <div class="modal-header">
        <h3>Détails de la proposition #{{ proposalId }}</h3>
        <button @click="onClose" class="close-button">&times;</button>
      </div>
      
      <div class="modal-content">
        <div v-if="loading" class="loading-container">
          <div class="spinner"></div>
          <p>Chargement des détails...</p>
        </div>
        
        <div v-else-if="error" class="error-message">
          {{ error }}
        </div>
        
        <div v-else-if="proposalDetails" class="proposal-details-content">
          <div class="detail-section">
            <h4>Informations générales</h4>
            <div class="detail-row">
              <span class="detail-label">Description:</span>
              <span class="detail-value">{{ proposalDetails[1] }}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Proposeur:</span>
              <span class="detail-value">{{ shortenAddress(proposalDetails[0]) }}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Date de clôture:</span>
              <span class="detail-value">{{ formatDate(proposalDetails[4]) }}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Statut:</span>
              <span class="detail-value status" :class="getStatusClass()">
                {{ getStatusLabel() }}
              </span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Quorum atteint:</span>
              <span class="detail-value passed" >
                {{ proposalDetails[7] }}
              </span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Est validé:</span>
              <span class="detail-value passed" >
                {{ proposalDetails[10] }}
              </span>
            </div>
            <div class="detail-row">
              <span class="detail-value passed" >
                {{ proposalDetails[9] }}
              </span>
            </div>
          </div>
          
          <div class="detail-section">
            <h4>Résultats du vote</h4>
            <div class="votes-summary">
              <div class="vote-card">
                <div class="vote-value">{{ formatVotes(proposalDetails[2]) }}</div>
                <div class="vote-label">Pour</div>
                <div class="vote-percentage">{{ getForPercentage() }}%</div>
              </div>
              
              <div class="vote-card">
                <div class="vote-value">{{ formatVotes(proposalDetails[3]) }}</div>
                <div class="vote-label">Contre</div>
                <div class="vote-percentage">{{ getAgainstPercentage() }}%</div>
              </div>
              
              <div class="vote-card">
                <div class="vote-value">{{ formatVotes(getTotalVotes()) }}</div>
                <div class="vote-label">Total</div>
                <div class="vote-percentage">100%</div>
              </div>
            </div>
            
            <div class="vote-progress">
              <div class="vote-bar-container">
                <div 
                  class="vote-bar for" 
                  :style="{ width: getForPercentage() + '%' }"
                ></div>
                <div 
                  class="vote-bar against" 
                  :style="{ width: getAgainstPercentage() + '%' }"
                ></div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          v-if="canVote()" 
          @click="openVoteModal"
          class="action-button vote"
        >
          Voter
        </button>
        
        <button 
          v-if="canExecute()" 
          @click="executeProposal"
          class="action-button execute"
          :disabled="isExecuting"
        >
          <span v-if="isExecuting" class="button-spinner"></span>
          {{ isExecuting ? 'Exécution...' : 'Exécuter' }}
        </button>
        
        <button 
          @click="onClose" 
          class="action-button cancel"
        >
          Fermer
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.details-modal-overlay {
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

.details-modal {
  background-color: white;
  border-radius: 0.5rem;
  width: 90%;
  max-width: 600px;
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

.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem;
}

.spinner, .button-spinner {
  border: 2px solid rgba(99, 102, 241, 0.1);
  border-top: 2px solid #6366f1;
  border-radius: 50%;
  width: 24px;
  height: 24px;
  animation: spin 1s linear infinite;
  margin-bottom: 1rem;
}

.button-spinner {
  width: 16px;
  height: 16px;
  margin: 0 0.5rem 0 0;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.error-message {
  padding: 0.75rem;
  background-color: #fee2e2;
  border: 1px solid #fecaca;
  border-radius: 0.375rem;
  color: #b91c1c;
}

.proposal-details-content {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.detail-section {
  border: 1px solid #e5e7eb;
  border-radius: 0.375rem;
  padding: 1rem;
}

.detail-section h4 {
  margin-top: 0;
  margin-bottom: 1rem;
  font-size: 1rem;
  color: #4b5563;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 0.5rem;
}

.detail-row {
  display: flex;
  margin-bottom: 0.75rem;
  align-items: flex-start;
}

.detail-label {
  width: 120px;
  font-weight: 500;
  color: #6b7280;
  font-size: 0.875rem;
}

.detail-value {
  flex: 1;
  color: #1f2937;
}

.status {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.status.active {
  background-color: #f59e0b;
  color: white;
}

.status.pending {
  background-color: #10b981;
  color: white;
}

.status.executed {
  background-color: #6b7280;
  color: white;
}

.votes-summary {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.vote-card {
  padding: 0.75rem;
  background-color: #f9fafb;
  border-radius: 0.375rem;
  text-align: center;
}

.vote-value {
  font-size: 1.25rem;
  font-weight: 700;
  color: #111827;
  margin-bottom: 0.25rem;
}

.vote-label {
  font-size: 0.75rem;
  color: #6b7280;
  margin-bottom: 0.25rem;
}

.vote-percentage {
  font-size: 0.875rem;
  font-weight: 600;
  color: #4b5563;
}

.vote-progress {
  margin-top: 1rem;
}

.vote-bar-container {
  height: 24px;
  background-color: #f3f4f6;
  border-radius: 0.25rem;
  overflow: hidden;
  display: flex;
}

.vote-bar {
  height: 100%;
}

.vote-bar.for {
  background-color: #10b981;
}

.vote-bar.against {
  background-color: #ef4444;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid #e5e7eb;
}

.action-button {
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-button.vote {
  background-color: #6366f1;
  color: white;
  border: none;
}

.action-button.vote:hover {
  background-color: #4f46e5;
}

.action-button.execute {
  background-color: #10b981;
  color: white;
  border: none;
}

.action-button.execute:hover {
  background-color: #059669;
}

.action-button.execute:disabled {
  background-color: #d1d5db;
  cursor: not-allowed;
}

.action-button.cancel {
  background-color: #f3f4f6;
  color: #4b5563;
  border: none;
}

.action-button.cancel:hover {
  background-color: #e5e7eb;
}

@media (max-width: 640px) {
  .votes-summary {
    grid-template-columns: 1fr;
  }
  
  .detail-row {
    flex-direction: column; 
  }
  
  .detail-label {
    width: 100%;
    margin-bottom: 0.25rem;
  }
}
</style>