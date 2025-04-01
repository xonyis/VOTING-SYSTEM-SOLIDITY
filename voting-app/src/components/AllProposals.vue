<template>
  <div class="all-proposals">
    <VoteModal 
      :is-open="isVoteModalOpen"
      :proposal="selectedProposalForVote"
      :on-close="closeVoteModal"
      :on-vote-success="handleVoteSuccess"
    />
    <!-- Nouveau modal de détails -->
    <ProposalDetailsModal
      :is-open="isDetailsModalOpen"
      :proposal-id="selectedProposalId"
      :on-close="closeDetailsModal"
      :on-vote-click="openVoteModalFromDetails"
      :on-execute-success="handleExecuteSuccess"
    />
    <h2 class="summary-value">Toutes les propositions</h2>
    
    <div v-if="isLoading" class="loading-container">
      <div class="spinner"></div>
      <p>Chargement des propositions...</p>
    </div>
    
    <div v-else-if="error" class="error-container">
      <div class="error-icon">⚠️</div>
      <p>{{ error }}</p>
      <button @click="fetchAllProposals" class="retry-button">Réessayer</button>
    </div>
    
    <div v-else>
      <div class="proposals-summary">
        <div class="summary-card">
          <div class="summary-value">{{ proposals.length }}</div>
          <div class="summary-label">Propositions totales</div>
        </div>
        
        <div class="summary-card">
          <div class="summary-value">{{ activeProposals.length }}</div>
          <div class="summary-label">En cours</div>
        </div>
        
        <div class="summary-card">
          <div class="summary-value">{{ pendingProposals.length }}</div>
          <div class="summary-label">En attente d'exécution</div>
        </div>
        
        <div class="summary-card">
          <div class="summary-value">{{ executedProposals.length }}</div>
          <div class="summary-label">Exécutées</div>
        </div>
      </div>
      
      <div class="filters">
        <div class="search-container">
          <input 
            type="text" 
            v-model="searchQuery" 
            placeholder="Rechercher une proposition..." 
            class="search-input"
          />
        </div>
        
        <div class="filter-buttons">
          <button 
            v-for="filter in filterOptions" 
            :key="filter.value"
            :class="['filter-button', { active: currentFilter === filter.value }]"
            @click="currentFilter = filter.value"
          >
            {{ filter.label }}
          </button>
        </div>
      </div>
      
      <div v-if="filteredProposals.length === 0" class="no-proposals">
        <p>Aucune proposition trouvée</p>
      </div>
      
      <div v-else class="proposals-list">
        <div 
          v-for="proposal in filteredProposals" 
          :key="proposal.id"
          class="proposal-card"
        >
          <div class="proposal-header">
            <div class="proposal-id">#{{ proposal.id }}</div>
            <div :class="['proposal-status', getStatusClass(proposal)]">
              {{ getStatusLabel(proposal) }}
            </div>
          </div>
          
          <div class="proposal-title">{{ proposal.description }}</div>
          
          <div class="proposal-details">
            <div class="detail">
              <span class="detail-label">Proposeur:</span>
              <span class="detail-value">{{ shortenAddress(proposal.proposer) }}</span>
            </div>
            
            <div class="detail">
              <span class="detail-label">Date de clôture:</span>
              <span class="detail-value">{{ formatDate(proposal.closingTime) }}</span>
            </div>
          </div>
          
          <div class="proposal-votes">
            <div class="vote-bar-container">
              <div class="vote-label">Pour</div>
              <div class="vote-bar-wrapper">
                <div 
                  class="vote-bar for" 
                  :style="{ width: getForPercentage(proposal) + '%' }"
                ></div>
                <span class="vote-percentage">{{ getForPercentage(proposal) }}%</span>
              </div>
              <div class="vote-amount">{{ formatVotes(proposal.forVotes) }}</div>
            </div>
            
            <div class="vote-bar-container">
              <div class="vote-label">Contre</div>
              <div class="vote-bar-wrapper">
                <div 
                  class="vote-bar against" 
                  :style="{ width: getAgainstPercentage(proposal) + '%' }"
                ></div>
                <span class="vote-percentage">{{ getAgainstPercentage(proposal) }}%</span>
              </div>
              <div class="vote-amount">{{ formatVotes(proposal.againstVotes) }}</div>
            </div>
          </div>
          
          <div class="proposal-actions">
            <button 
              v-if="canVote(proposal)" 
              @click="openVoteModal(proposal)"
              class="action-button vote"
            >
              Voter
            </button>
            
            <button 
              v-if="canExecute(proposal)" 
              @click="executeProposal(proposal.id)"
              class="action-button execute"
              :disabled="isExecuting === proposal.id"
            >
              <span v-if="isExecuting === proposal.id" class="button-spinner"></span>
              {{ isExecuting === proposal.id ? 'Exécution...' : 'Exécuter' }}
            </button>
            
            <button 
              @click="openDetailsModal(proposal.id)"
              class="action-button details"
            >
              Détails
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useReadContract } from '@wagmi/vue';
import { parseAbi, formatUnits, createPublicClient, http } from 'viem';
import { polygonAmoy } from 'wagmi/chains';
import { writeContract } from '@wagmi/core';
import { useAccount, useWriteContract } from '@wagmi/vue'

import VoteModal from './Voting.vue';
import ProposalDetailsModal from './Proposals.vue'
// Adresse du contrat
const CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS;
// État des modals
const selectedProposalForVote = ref(null);
const isVoteModalOpen = ref(false);
const isDetailsModalOpen = ref(false);
const selectedProposalId = ref(null);

// Flag pour éviter les doubles rafraîchissements
const isRefreshing = ref(false);

// ABI du contrat
const abi = parseAbi([
  "function proposalCount() view returns (uint256)",
  "function getProposalDetails(uint256) view returns (address proposer, string description, uint256 forVotes, uint256 againstVotes, uint256 closingTime, bool executed)",
  "function executeProposal(uint256 proposalId) returns ()"
]);

// Créer un client public viem pour les lectures directes
const publicClient = createPublicClient({
  chain: polygonAmoy,
  transport: http("https://rpc-amoy.polygon.technology") // RPC alternatif
});

const { address, isConnected } = useAccount();
  // Utiliser le hook useWriteContract pour écrire dans le contrat
  const { writeContractAsync } = useWriteContract();
// Variables réactives
const proposals = ref([]);
const isLoading = ref(true);
const error = ref(null);
const isExecuting = ref(null);
const searchQuery = ref('');
const currentFilter = ref('all');

// Options de filtrage
const filterOptions = [
  { label: 'Toutes', value: 'all' },
  { label: 'En cours', value: 'active' },
  { label: 'En attente', value: 'pending' },
  { label: 'Exécutées', value: 'executed' }
];

// Utiliser useReadContract pour récupérer le nombre de propositions
const { 
  data: countData, 
  isSuccess: isCountSuccess,
  isError: isCountError,
  error: countError
} = useReadContract({
  address: CONTRACT_ADDRESS,
  abi,
  functionName: 'proposalCount',
});

// Propositions filtrées par statut
const activeProposals = computed(() => {
  const now = Math.floor(Date.now() / 1000);
  return proposals.value.filter(p => !p.executed && p.closingTime > now);
});

const pendingProposals = computed(() => {
  const now = Math.floor(Date.now() / 1000);
  return proposals.value.filter(p => !p.executed && p.closingTime <= now);
});

const executedProposals = computed(() => {
  return proposals.value.filter(p => p.executed);
});

// Propositions filtrées par recherche et statut
const filteredProposals = computed(() => {
  let filtered = [...proposals.value];
  
  // Filtrer par statut
  if (currentFilter.value === 'active') {
    filtered = activeProposals.value;
  } else if (currentFilter.value === 'pending') {
    filtered = pendingProposals.value;
  } else if (currentFilter.value === 'executed') {
    filtered = executedProposals.value;
  }
  
  // Filtrer par recherche
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    filtered = filtered.filter(p => 
      p.description.toLowerCase().includes(query) || 
      p.proposer.toLowerCase().includes(query) ||
      p.id.toString().includes(query)
    );
  }
  
  return filtered;
});

// Observer les changements du nombre de propositions
watch([countData, isCountSuccess, isCountError], async ([count, success, hasError]) => {
  if (success && count && !isRefreshing.value) {
    console.log("Nombre de propositions récupéré:", count.toString());
    await fetchAllProposals();
  } else if (hasError) {
    console.error("Erreur lors de la récupération du nombre de propositions:", countError.value);
    error.value = "Impossible de récupérer le nombre de propositions";
    isLoading.value = false;
  }
});

// Récupérer toutes les propositions en utilisant viem directement
async function fetchAllProposals() {
  // Éviter les doubles rafraîchissements
  if (isRefreshing.value) {
    console.log("Rafraîchissement déjà en cours, opération ignorée");
    return;
  }
  
  isRefreshing.value = true;
  isLoading.value = true;
  error.value = null;
  proposals.value = [];

  try {
    if (!countData.value) {
      throw new Error("Impossible de récupérer le nombre de propositions");
    }
    
    const count = parseInt(countData.value.toString());
    console.log("Nombre total de propositions:", count);
    
    if (count === 0) {
      isLoading.value = false;
      isRefreshing.value = false;
      return;
    }
    
    // Récupérer les détails de chaque proposition avec viem
    for (let i = 1; i <= count; i++) {
      try {
        console.log(`Récupération de la proposition ${i}...`);
        
        const details = await publicClient.readContract({
          address: CONTRACT_ADDRESS,
          abi,
          functionName: 'getProposalDetails',
          args: [BigInt(i)],
        });
        
        console.log(`Proposition ${i} récupérée:`, details);
        
        proposals.value.push({
          id: i,
          proposer: details[0],
          description: details[1],
          forVotes: details[2],
          againstVotes: details[3],
          closingTime: Number(details[4]), // Ajustement pour le décalage de timestamp
          executed: details[5]
        });
      } catch (err) {
        console.error(`Erreur lors de la récupération de la proposition ${i}:`, err);
      }
    }
    
    // Trier les propositions par ID décroissant (les plus récentes d'abord)
    proposals.value.sort((a, b) => b.id - a.id);
    
  } catch (err) {
    console.error("Erreur lors de la récupération des propositions:", err);
    error.value = "Impossible de récupérer les propositions: " + err.message;
  } finally {
    isLoading.value = false;
    
    // Réinitialiser le flag après un délai pour éviter les rafraîchissements trop rapprochés
    setTimeout(() => {
      isRefreshing.value = false;
    }, 1000);
  }
}

// Exécuter une proposition
// Exécuter une proposition
async function executeProposal(proposalId) {
      if (!isConnected.value) {
        alert("Vous devez être connecté pour exécuter une proposition.");
        return;
      }
      
      isExecuting.value = proposalId;

      try {
        const hash = await writeContractAsync({
          address: CONTRACT_ADDRESS,
          abi,
          functionName: 'executeProposal',
          args: [BigInt(proposalId)],
        });
        
        console.log("Transaction d'exécution soumise, hash:", hash);
        
        // Mettre à jour le statut de la proposition localement
        const proposal = proposals.value.find(p => p.id === proposalId);
        if (proposal) {
          proposal.executed = true;
        }
        
      } catch (err) {
        console.error("Erreur lors de l'exécution de la proposition:", err);
        alert("Erreur lors de l'exécution de la proposition: " + (err.message || "Transaction rejetée"));
      } finally {
        isExecuting.value = null;
      }
    }


// Ouvrir le modal de détails
function openDetailsModal(proposalId) {
  selectedProposalId.value = proposalId;
  isDetailsModalOpen.value = true;
}

// Fermer le modal de détails
function closeDetailsModal() {
  isDetailsModalOpen.value = false;
  selectedProposalId.value = null;
}

// Ouvrir le modal de vote depuis le modal de détails
function openVoteModalFromDetails(proposalId) {
  const proposal = proposals.value.find(p => p.id === proposalId);
  if (proposal) {
    openVoteModal(proposal);
  }
}


// Ouvrir le modal de vote
function openVoteModal(proposal) {
  selectedProposalForVote.value = proposal;
  isVoteModalOpen.value = true;
}

// Fermer le modal de vote
function closeVoteModal() {
  isVoteModalOpen.value = false;
  selectedProposalForVote.value = null;
}

// Gérer le succès du vote
function handleVoteSuccess() {
  // Mettre à jour uniquement la proposition votée au lieu de tout rafraîchir
  if (selectedProposalForVote.value) {
    updateSingleProposal(selectedProposalForVote.value.id);
  }
  
  // Fermer le modal après un délai
  setTimeout(() => {
    closeVoteModal();
  }, 2000);
}

// Gérer le succès de l'exécution depuis le modal de détails
function handleExecuteSuccess(proposalId) {
  // Mettre à jour la proposition dans la liste
  const proposal = proposals.value.find(p => p.id === proposalId);
  if (proposal) {
    proposal.executed = true;
  }
  
  // Fermer le modal après un délai
  setTimeout(() => {
    closeDetailsModal();
  }, 2000);
}

// Mettre à jour une seule proposition
async function updateSingleProposal(proposalId) {
  try {
    console.log(`Mise à jour de la proposition ${proposalId}...`);
    
    const details = await publicClient.readContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: 'getProposalDetails',
      args: [BigInt(proposalId)],
    });
    
    // Trouver et mettre à jour la proposition existante
    const index = proposals.value.findIndex(p => p.id === proposalId);
    if (index !== -1) {
      const updatedProposal = {
        id: proposalId,
        proposer: details[0],
        description: details[1],
        forVotes: details[2],
        againstVotes: details[3],
        closingTime: Number(details[4]) - 2417100,
        executed: details[5]
      };
      
      // Remplacer la proposition dans le tableau
      proposals.value.splice(index, 1, updatedProposal);
      console.log(`Proposition ${proposalId} mise à jour avec succès`);
    }
  } catch (err) {
    console.error(`Erreur lors de la mise à jour de la proposition ${proposalId}:`, err);
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
  console.log(timestamp);
  return date.toLocaleString();
}

function formatVotes(votes) {
  if (!votes) return '0';
  return parseFloat(formatUnits(votes, 18)).toLocaleString(undefined, {
    maximumFractionDigits: 0
  });
}

function getForPercentage(proposal) {
  const totalVotes = BigInt(proposal.forVotes) + BigInt(proposal.againstVotes);
  if (totalVotes === 0n) return 0;
  
  return Math.round(Number((BigInt(proposal.forVotes) * 100n) / totalVotes));
}

function getAgainstPercentage(proposal) {
  return 100 - getForPercentage(proposal);
}

function getStatusLabel(proposal) {
  if (proposal.executed) return 'Exécutée';
  
  const now = Math.floor(Date.now() / 1000);
  if (proposal.closingTime > now) return 'En cours';
  return 'En attente';
}

function getStatusClass(proposal) {
  if (proposal.executed) return 'executed';
  
  const now = Math.floor(Date.now() / 1000);
  if (proposal.closingTime > now) return 'active';
  return 'pending';
}

function canVote(proposal) {
  const now = Math.floor(Date.now() / 1000);
  return !proposal.executed && proposal.closingTime > now;
}

function canExecute(proposal) {
  const now = Math.floor(Date.now() / 1000);
  return !proposal.executed && proposal.closingTime <= now;
}

function navigateToDetails(proposalId) {
  // Rediriger vers la page de détails
  // window.location.href = `/proposal/${proposalId}`;
  console.log(`Naviguer vers la page de détails pour la proposition ${proposalId}`);
}

// Chargement initial
onMounted(() => {
  if (countData.value) {
    fetchAllProposals();
  }
});
</script>

<style scoped>
/* Le style reste inchangé */
.all-proposals {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1.5rem 2rem;
}

h2 {
  font-size: 1.75rem;
  color: #fff;
  margin-bottom: 1.5rem;
}

.loading-container, .error-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.spinner, .button-spinner {
  border: 3px solid rgba(99, 102, 241, 0.1);
  border-top: 3px solid #6366f1;
  border-radius: 50%;
  width: 30px;
  height: 30px;
  animation: spin 1s linear infinite;
  margin-bottom: 1rem;
}

.button-spinner {
  width: 16px;
  height: 16px;
  margin: 0 0.5rem 0 0;
  border-width: 2px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.error-icon {
  font-size: 2rem;
  margin-bottom: 1rem;
}

.retry-button {
  margin-top: 1rem;
  padding: 0.5rem 1rem;
  background-color: #6366f1;
  color: white;
  border: none;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: background-color 0.2s;
}

.retry-button:hover {
  background-color: #4f46e5;
}

.proposals-summary {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.summary-card {
  padding: 1.5rem;
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  text-align: center;
}

.summary-value {
  font-size: 2rem;
  font-weight: 700;
  color: #6366f1;
  margin-bottom: 0.5rem;
}

.summary-label {
  color: #4b5563;
  font-size: 0.875rem;
}

.filters {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
  gap: 1rem;
}

.search-container {
  flex: 1;
  min-width: 250px;
}

.search-input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  color: black;
  background: #fff;
}

.filter-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.filter-button {
  padding: 0.5rem 1rem;
  background-color: #f3f4f6;
  border: none;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: #4b5563;
  cursor: pointer;
  transition: background-color 0.2s;
}

.filter-button:hover {
  background-color: #e5e7eb;
}

.filter-button.active {
  background-color: #6366f1;
  color: white;
}

.no-proposals {
  padding: 3rem;
  text-align: center;
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  color: #6b7280;
}

.proposals-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 1.5rem;
}

.proposal-card {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.proposal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.proposal-id {
  font-weight: 600;
  color: #6b7280;
}

.proposal-status {
  padding: 0.25rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.proposal-status.active {
  background-color: #f59e0b;
  color: white;
}

.proposal-status.pending {
  background-color: #10b981;
  color: white;
}

.proposal-status.executed {
  background-color: #6b7280;
  color: white;
}

.proposal-title {
  font-weight: 500;
  color: #111827;
  font-size: 1.125rem;
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

.proposal-votes {
  margin-top: 0.5rem;
}

.vote-bar-container {
  display: flex;
  align-items: center;
  margin-bottom: 0.75rem;
}

.vote-label {
  width: 50px;
  font-weight: 500;
  color: #4b5563;
  font-size: 0.875rem;
}

.vote-bar-wrapper {
  flex: 1;
  height: 20px;
  background-color: #f3f4f6;
  border-radius: 0.25rem;
  margin: 0 0.75rem;
  position: relative;
  overflow: hidden;
}

.vote-bar {
  height: 100%;
  transition: width 0.5s ease;
}

.vote-bar.for {
  background-color: #10b981;
}

.vote-bar.against {
  background-color: #ef4444;
}

.vote-percentage {
  position: absolute;
  top: 50%;
  left: 8px;
  transform: translateY(-50%);
  color: white;
  font-size: 0.75rem;
  font-weight: 600;
  text-shadow: 0 0 2px rgba(0, 0, 0, 0.5);
}

.vote-amount {
  width: 80px;
  text-align: right;
  font-weight: 500;
  color: #4b5563;
  font-size: 0.875rem;
}

.proposal-actions {
  display: flex;
  gap: 0.5rem;
  margin-top: auto;
}

.action-button {
  flex: 1;
  padding: 0.5rem;
  border: none;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-button.vote {
  background-color: #6366f1;
  color: white;
}

.action-button.vote:hover {
  background-color: #4f46e5;
}

.action-button.execute {
  background-color: #10b981;
  color: white;
}

.action-button.execute:hover {
  background-color: #059669;
}

.action-button.execute:disabled {
  background-color: #d1d5db;
  cursor: not-allowed;
}

.action-button.details {
  background-color: #f3f4f6;
  color: #4b5563;
}

.action-button.details:hover {
  background-color: #e5e7eb;
}

@media (max-width: 768px) {
  .all-proposals {
    padding: 1rem;
  }
  
  .proposals-list {
    grid-template-columns: 1fr;
  }
  
  .filters {
    flex-direction: column;
    align-items: stretch;
  }
  
  .search-container {
    width: 100%;
  }
  
  .filter-buttons {
    justify-content: center;
  }
  
  .vote-bar-container {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .vote-label {
    width: 100%;
    margin-bottom: 0.25rem;
  }
  
  .vote-bar-wrapper {
    width: 100%;
    margin: 0.25rem 0;
  }
  
  .vote-amount {
    width: 100%;
    text-align: left;
    margin-top: 0.25rem;
  }
}
</style>