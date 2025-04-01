<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { useAccount, useDisconnect } from '@wagmi/vue';
import { createPublicClient, http, parseAbi, formatUnits } from 'viem';
import { polygonAmoy } from 'wagmi/chains';

const { address, chainId, status } = useAccount();
const { disconnect } = useDisconnect();

// Informations du token VOT
const tokenAddress = import.meta.env.VITE_TOKEN_ADDRESS;
const tokenBalance = ref<string>("--");
const isLoading = ref(false);
const error = ref<string | null>(null);

// Créer un client public pour interagir avec la blockchain
const publicClient = createPublicClient({
  chain: polygonAmoy,
  transport: http("https://rpc-amoy.polygon.technology")
});

// ABI minimal pour la fonction balanceOf
const erc20Abi = parseAbi([
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)"
]);

// Vérifier si l'utilisateur est connecté
const isConnected = computed(() => status.value === 'connected' && !!address.value);

// Fonction pour récupérer le solde du token
async function fetchTokenBalance() {
  // Vérifier si l'utilisateur est connecté
  if (!isConnected.value) {
    tokenBalance.value = "Connectez-vous pour voir votre solde";
    return;
  }
  
  isLoading.value = true;
  error.value = null;
  
  try {
    // Récupérer le solde en utilisant l'adresse connectée
    const balance = await publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: [address.value]
    });
    
    // Récupérer les décimales
    const decimals = await publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'decimals'
    });
    
    // Formater le solde
    const formattedBalance = formatUnits(balance, decimals);
    tokenBalance.value = parseFloat(formattedBalance).toLocaleString(undefined, {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    });
    
    // Récupérer le symbole (optionnel)
    try {
      const symbol = await publicClient.readContract({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'symbol'
      });
      
      tokenBalance.value += ` ${symbol}`;
    } catch (symbolError) {
      console.warn("Impossible de récupérer le symbole du token:", symbolError);
    }
    
  } catch (err) {
    console.error("Erreur lors de la récupération du solde:", err);
    error.value = "Impossible de récupérer le solde du token";
    tokenBalance.value = "Erreur";
  } finally {
    isLoading.value = false;
  }
}

// Observer les changements d'adresse pour mettre à jour le solde
watch(address, () => {
  if (isConnected.value) {
    fetchTokenBalance();
  } else {
    tokenBalance.value = "Connectez-vous pour voir votre solde";
    error.value = null;
  }
});

// Observer les changements de statut pour mettre à jour le solde
watch(status, (newStatus) => {
  if (newStatus === 'connected' && address.value) {
    fetchTokenBalance();
  } else if (newStatus !== 'connected') {
    tokenBalance.value = "Connectez-vous pour voir votre solde";
    error.value = null;
  }
});

// Charger le solde si l'utilisateur est déjà connecté
if (isConnected.value) {
  fetchTokenBalance();
} else {
  tokenBalance.value = "Connectez-vous pour voir votre solde";
}
</script>

<template>
  <div class="account-container">
    <h2 class="summary-value">Account</h2>

    <div class="account-details">
      <div class="detail-row">
        <p class="summary-label">Account:</p>
        <span v-if="address" class="account-address">{{ address }}</span>
        <span v-else class="account-address not-connected">Non connecté</span>
      </div>
      
      <div class="detail-row">
        <span class="summary-label">Chain ID:</span>
        <span class="chain-id">{{ chainId || '--' }}</span>
      </div>
      
      <div class="detail-row">
        <span class="summary-label">Status:</span>
        <span class="status-badge" :class="status">{{ status }}</span>
      </div>
      
      <!-- Section pour le solde de token -->
      <div class="detail-row token-balance-row">
        <span class="summary-label">Votre solde de tokens:</span>
        <div class="token-balance-container">
          <div v-if="isLoading" class="balance-loading">
            <div class="balance-spinner"></div>
            <span>Chargement du solde...</span>
          </div>
          <div v-else-if="error" class="balance-error">
            {{ error }}
          </div>
          <div v-else class="token-balance">
            <span class="balance-amount">{{ tokenBalance }}</span>
          </div>
        </div>
        <button 
          @click="fetchTokenBalance" 
          class="refresh-button"
          :disabled="isLoading || !isConnected"
        >
          Rafraîchir le solde
        </button>
      </div>
    </div>

    <button 
      v-if="status !== 'disconnected'" 
      type="button" 
      @click="disconnect()"
      class="disconnect-button"
    >
      Disconnect
    </button>
  </div>
</template>

<style scoped>
.account-container {
  background-color: #f9fafb;
  border-radius: 0.75rem;
  padding: 1.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  margin-bottom: 1.5rem;
}

.summary-value {
  font-size: 1.7rem;
  font-weight: 700;
  color: #6366f1;
  text-align: center;
  margin-bottom: 1.5rem;
  border-bottom: 2px solid #e5e7eb;
  padding-bottom: 0.75rem;
}

.account-details {
  margin-bottom: 1.25rem;
}

.detail-row {
  display: flex;
  flex-direction: column;
  margin-bottom: 0.75rem;
}

.summary-label {
  color: #4b5563;
  font-size: 0.875rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.account-address {
  font-family: monospace;
  background-color: #f3f4f6;
  padding: 0.5rem;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  word-break: break-all;
  margin-bottom: 0.5rem;
}

.account-address.not-connected {
  color: #9ca3af;
  font-style: italic;
}

.chain-id {
  font-weight: 600;
  color: #1f2937;
}

.status-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: capitalize;
}

.status-badge.connected {
  background-color: #d1fae5;
  color: #065f46;
}

.status-badge.connecting {
  background-color: #fef3c7;
  color: #92400e;
}

.status-badge.reconnecting {
  background-color: #fef3c7;
  color: #92400e;
}

.status-badge.disconnected {
  background-color: #fee2e2;
  color: #b91c1c;
}

.disconnect-button {
  width: 100%;
  background-color: #6366f1;
  color: white;
  font-weight: 600;
  padding: 0.625rem 1.25rem;
  border-radius: 0.375rem;
  border: none;
  cursor: pointer;
  transition: background-color 0.2s;
}

.disconnect-button:hover {
  background-color: #4f46e5;
}

.disconnect-button:focus {
  outline: 2px solid #818cf8;
  outline-offset: 2px;
}

/* Styles pour l'affichage du solde de token */
.token-balance-row {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid #e5e7eb;
}

.token-balance-container {
  background-color: #f3f4f6;
  padding: 0.75rem;
  border-radius: 0.375rem;
  display: flex;
  align-items: center;
  margin-bottom: 0.75rem;
}

.token-balance {
  display: flex;
  align-items: baseline;
}

.balance-amount {
  font-size: 1.25rem;
  font-weight: 700;
  color: #1f2937;
}

.balance-loading {
  display: flex;
  align-items: center;
  color: #6b7280;
  font-size: 0.875rem;
}

.balance-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(99, 102, 241, 0.2);
  border-top-color: #6366f1;
  border-radius: 50%;
  margin-right: 0.5rem;
  animation: spin 1s linear infinite;
}

.balance-error {
  color: #ef4444;
  font-size: 0.875rem;
}

.refresh-button {
  background-color: #e5e7eb;
  color: #4b5563;
  border: none;
  border-radius: 0.375rem;
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.refresh-button:hover {
  background-color: #d1d5db;
}

.refresh-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>