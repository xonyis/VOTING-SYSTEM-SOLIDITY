import { Buffer } from 'buffer'
import { VueQueryPlugin } from '@tanstack/vue-query'
import { createConfig, WagmiPlugin } from '@wagmi/vue';
import { polygonAmoy } from 'wagmi/chains';
import { http } from 'viem';

import { createApp } from 'vue'

// `@coinbase-wallet/sdk` uses `Buffer`
globalThis.Buffer = Buffer

import App from './App.vue'
import './style.css'


const config = createConfig({
    chains: [polygonAmoy],
    transports: {
      [polygonAmoy.id]: http("https://rpc-amoy.polygon.technology"),
    },
  });

const app = createApp(App)

app.use(WagmiPlugin, { config }).use(VueQueryPlugin, {})

app.mount('#app')
