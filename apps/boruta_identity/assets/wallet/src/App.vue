<template>
  <div class="main header">
    <router-link to="/">
      <img src="./assets/accounts/wallet/images/logo.png" />
    </router-link>
    <button
      v-if="serviceWorkerRegistration"
      type="button"
      class="update-cache"
      :disabled="updating"
      @click="reloadServiceWorkerCache"
    >
      {{ updating ? 'Updating...' : 'Update app' }}
    </button>
  </div>
  <div class="ui container">
    <div class="ui warning message">
      This wallet is aimed for demo purposes. Only use this wallet on a trusted device that you control.
    </div>
  </div>
  <router-view/>
</template>

<script lang="ts">
import { defineComponent } from 'vue'

interface ServiceWorkerUpdatedEvent extends Event {
  detail: {
    registration: ServiceWorkerRegistration
  }
}

export default defineComponent({
  data () {
    return {
      serviceWorkerRegistration: null as ServiceWorkerRegistration | null,
      updating: false
    }
  },
  mounted () {
    window.addEventListener(
      'boruta-wallet:service-worker-updated',
      this.onServiceWorkerUpdated as EventListener
    )
  },
  beforeUnmount () {
    window.removeEventListener(
      'boruta-wallet:service-worker-updated',
      this.onServiceWorkerUpdated as EventListener
    )
  },
  methods: {
    onServiceWorkerUpdated (event: ServiceWorkerUpdatedEvent) {
      this.serviceWorkerRegistration = event.detail.registration
    },
    async reloadServiceWorkerCache () {
      if (!this.serviceWorkerRegistration) return

      this.updating = true
      await this.serviceWorkerRegistration.update()

      const waitingWorker = this.serviceWorkerRegistration.waiting

      if (waitingWorker) {
        waitingWorker.postMessage({ type: 'SKIP_WAITING' })
        window.setTimeout(() => this.resetServiceWorkerCache(), 1500)
      } else {
        await this.resetServiceWorkerCache()
      }
    },
    async resetServiceWorkerCache () {
      if (!this.serviceWorkerRegistration) return

      await this.serviceWorkerRegistration.unregister()
      window.location.reload()
    }
  }
})
</script>

<style lang="scss">
html, body {
  width: 100%;
  overflow-x: hidden;
}
.main.header {
  border-bottom: 1px solid #eee;
  padding: 1em;
  background: white;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  img {
    width: 4em;
  }
  .update-cache {
    position: absolute;
    right: 1em;
    border: 1px solid #333;
    background: #333;
    color: white;
    border-radius: .25em;
    padding: .6em .8em;
    font: inherit;
    cursor: pointer;

    &:disabled {
      cursor: progress;
      opacity: .7;
    }
  }
}
#app {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: #f8f8f8;
  min-height: 100vh;
}
.warning.message {
  text-align: center;
}
nav {
  text-align: center;
  padding: 30px;

  a {
    font-weight: bold;
    color: black;

    &:hover {
      color: #555;
    }
    &.router-link-exact-active {
      color: #f5ba00;
    }
  }
}
</style>
