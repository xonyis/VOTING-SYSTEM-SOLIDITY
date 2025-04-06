<script setup lang="ts">
import { useChainId, useConnect, useAccount } from '@wagmi/vue'

const chainId = useChainId()
const { connect, connectors, error } = useConnect()
const { status } = useAccount()
</script>

<template>
  <div class="connect-container" v-if="status != 'connected'">
    <h2 class="connect-title">Connect</h2>

    <div class="connectors-list">
      <button 
        v-for="connector in connectors" 
        :key="connector.id" 
        type="button" 
        @click="connect({ connector, chainId })"
        class="connector-button"
      >
        {{ connector.name }}
      </button>
    </div>

    
  </div>
</template>

<style scoped>
.connect-container {
  background-color: #f9fafb;
  border-radius: 0.75rem;
  padding: 1.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  margin-bottom: 1.5rem;
}

.connect-title {
  font-size: 1.7rem;
  font-weight: 700;
  color: #6366f1;
  text-align: center;
  margin-bottom: 1.5rem;
  border-bottom: 2px solid #e5e7eb;
  padding-bottom: 0.75rem;
}

.connectors-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.connector-button {
  background-color: white;
  color: #4b5563;
  font-weight: 600;
  padding: 0.75rem 1rem;
  border-radius: 0.375rem;
  border: 1px solid #e5e7eb;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.connector-button:hover {
  background-color: #f3f4f6;
  border-color: #d1d5db;
  transform: translateY(-1px);
}

.connector-button:active {
  transform: translateY(0);
}

.connection-status {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid #e5e7eb;
}

.status-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: capitalize;
  margin-bottom: 0.5rem;
}

.status-badge.connecting {
  background-color: #fef3c7;
  color: #92400e;
}

.status-badge.connected {
  background-color: #d1fae5;
  color: #065f46;
}

.status-badge.disconnected {
  background-color: #fee2e2;
  color: #b91c1c;
}

.status-badge.reconnecting {
  background-color: #fef3c7;
  color: #92400e;
}

.error-message {
  background-color: #fee2e2;
  color: #b91c1c;
  padding: 0.75rem;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  margin-top: 0.5rem;
}
</style>