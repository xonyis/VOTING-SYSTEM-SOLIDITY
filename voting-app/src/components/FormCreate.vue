<script setup>
import { ref, computed } from 'vue'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from '@wagmi/vue'
import { parseAbiItem } from 'viem'

// État du formulaire
const proposalName = ref('')
const proposalDuration = ref(3600)
const isSubmitting = ref(false)
const error = ref('')
const success = ref(false)
const transactionHash = ref('')

// Adresse du contrat
const contractAddress = import.meta.env.VITE_CONTRACT_ADDRESS;

// ABI pour la fonction de création de proposition
const createProposalAbi = [
  parseAbiItem('function createProposal(string name, uint256 durationInSeconds) public')
]

// Hooks Wagmi
const { address, isConnected } = useAccount()
const { writeContractAsync, isPending } = useWriteContract()

// Attente de la transaction
const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
  hash: transactionHash.value,
  onSuccess: () => {
    success.value = true
    isSubmitting.value = false
    proposalName.value = ''
    proposalDuration.value = 3600
    console.log("Transaction confirmée avec succès!")
  }
})

// Validation du formulaire
const isFormValid = computed(() => {
  return proposalName.value.trim().length > 0 && proposalDuration.value > 0
})

// Soumission du formulaire
const submitProposal = async () => {
  if (!isFormValid.value || isSubmitting.value) return

  console.log("Début de la soumission de la proposition")
  console.log("Nom:", proposalName.value)
  console.log("Durée:", proposalDuration.value)
  
  error.value = ''
  success.value = false
  isSubmitting.value = true
  
  try {
    console.log("Préparation de la transaction avec:", {
      address: contractAddress,
      functionName: 'createProposal',
      args: [proposalName.value, Number(proposalDuration.value)]
    })
    
    // Utiliser writeContractAsync au lieu de writeContract
    const hash = await writeContractAsync({
      address: contractAddress,
      abi: createProposalAbi,
      functionName: 'createProposal',
      args: [proposalName.value, Number(proposalDuration.value)]
    })
    
    console.log("Transaction envoyée, hash:", hash)
    transactionHash.value = hash
  } catch (err) {
    console.error('Erreur détaillée:', err)
    error.value = `Erreur: ${err.message || 'Erreur inconnue'}`
    isSubmitting.value = false
  }
}

// Réinitialiser le formulaire
const resetForm = () => {
  proposalName.value = ''
  proposalDuration.value = 3600
  error.value = ''
  success.value = false
}
</script>

<template>
  <div class="bg-white rounded-lg shadow overflow-hidden mt-6 mb-6 p-4">
    <h2 class="text-md font-bold !mb-2 summary-value mt-2">Créer une proposition</h2>
    <p class="summary-label !mb-5" >Il est nécessaire de posséder <span class="font-bold" >plus</span> de 5 000 pour créer une proposition</p>
    <!-- Formulaire simplifié -->
    <form @submit.prevent="submitProposal" class="space-y-4">
      <!-- Nom de la proposition -->
      <div>
        <label for="proposal-name" class="block text-sm font-medium text-gray-700 mb-1">
          Nom de la proposition *
        </label>
        <input
          id="proposal-name"
          v-model="proposalName"
          type="text"
          placeholder="Entrez le nom de votre proposition"
          class="w-full px-4 py-2 border border-gray-300 rounded-md"
          :disabled="isSubmitting || isPending || isConfirming"
        />
      </div>
      
      <!-- Durée de la proposition -->
      <div>
        <label for="proposal-duration" class="block text-sm font-medium text-gray-700 mb-1">
          Durée (en secondes)
        </label>
        <input
          id="proposal-duration"
          v-model="proposalDuration"
          type="number"
          min="60"
          step="60"
          class="w-full px-4 py-2 border border-gray-300 rounded-md"
          :disabled="isSubmitting || isPending || isConfirming"
        />
      </div>
      
      <!-- État de la transaction -->
      <div v-if="isPending" class="p-3 bg-blue-50 text-blue-700 rounded-md">
        Transaction en cours d'envoi...
      </div>
      
      <div v-if="isConfirming" class="p-3 bg-blue-50 text-blue-700 rounded-md">
        Transaction en cours de confirmation...
      </div>
      
      <!-- Messages -->
      <div v-if="error" class="p-3 bg-red-50 text-red-700 rounded-md">
        {{ error }}
      </div>
      
      <div v-if="success" class="p-3 bg-green-50 text-green-700 rounded-md">
        Proposition créée avec succès !
        <div v-if="transactionHash" class="text-sm mt-1">
          Hash de transaction: {{ transactionHash }}
        </div>
      </div>
      
      <!-- Boutons -->
      <div class="flex space-x-3 btn-container">
        <button
          type="button"
          @click="resetForm"
          class="px-4 py-2 border border-gray-300 rounded-md"
          :disabled="isSubmitting || isPending || isConfirming"
        >
          Réinitialiser
        </button>
        <button
          type="submit"
          class="px-4 py-2 bg-blue-500 text-white rounded-md"
          :disabled="!isFormValid || isSubmitting || isPending || isConfirming"
        >
          <span v-if="isSubmitting || isPending || isConfirming">
            <svg class="animate-spin -ml-1 mr-2 h-4 w-4 inline-block text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ isConfirming ? 'Confirmation...' : 'Envoi...' }}
          </span>
          <span v-else>Créer la proposition</span>
        </button>
      </div>
    </form>
  </div>
</template>
<style scoped>
form {
    color: black;
}

.summary-value {
    font-size: 1.7rem;
    font-weight: 700;
    color: #6366f1;
    text-align: center;
    margin-bottom: 1.5rem;
  }

.btn-container {
  margin-top: 2rem;
}

.summary-label {
  color: #4b5563;
  font-size: 0.875rem;
}
</style>