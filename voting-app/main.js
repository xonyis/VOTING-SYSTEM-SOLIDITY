import { createApp } from 'vue'
import { createConfig, http } from '@wagmi/core'
import { mainnet, sepolia } from '@wagmi/core/chains'
import { injected } from '@wagmi/connectors'
import { createWagmi } from '@wagmi/vue'
import App from './App.vue'
import './style.css'

// Configuration Wagmi
const config = createConfig({
  chains: [polygonAmoy],
  transports: {
    [polygonAmoy.id]: http("https://rpc-amoy.polygon.technology"),
  },
});
// Création de l'instance Wagmi
const { install } = createWagmi(config)

// Création de l'application Vue
const app = createApp(App)

// Installation du plugin Wagmi
app.use(install)

// Montage de l'application
app.mount('#app')