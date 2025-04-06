import { createApp } from 'vue';
import { createConfig, WagmiPlugin } from '@wagmi/vue';
import { polygonAmoy } from 'wagmi/chains';
import { http } from 'viem';
import App from './App.vue';

const config = createConfig({
  chains: [polygonAmoy],
  transports: {
    [polygonAmoy.id]: http("https://rpc-amoy.polygon.technology"),
  },
});

createApp(App)
  .use(WagmiPlugin, { config })
  .mount('#app');
