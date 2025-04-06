<script setup>
import { ref, computed } from 'vue'
import Account from './components/Account.vue'
import Connect from './components/Connect.vue'

import Proposals from './components/Proposals.vue'
import AllProposals from './components/AllProposals.vue'
import FormCreate from './components/FormCreate.vue'
import Voting from './components/Voting.vue'
// Fonction pour rafraîchir les propositions
const refreshTrigger = ref(0)

const refreshProposals = () => {
  refreshTrigger.value++
}
</script>
<template>
  <div class="flex  w-screen">
    <div class="w-200 !ml-6">
      <div class="bg-white rounded-lg shadow overflow-hidden text-gray-950 p-4 !mt-8 ">
        <Account />
      <Balance />
      <Connect />
      </div>
      <div>
        <FormCreate :is-admin="true" 
        :voting-status="votingStatusData || { isOpen: true, endTime: 0 }"
        @proposal-created="refreshProposals"
        />
      </div>
    </div>
    <div class=" w-full">
      
      <AllProposals :key="refreshTrigger" />
    </div>
    
  </div>
  
</template>
