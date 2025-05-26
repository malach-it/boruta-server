<template>
  <div class="select-key">
    <div class="ui center aligned key-select segment">
      <Consent
        message="You are about to remove a cryptographic key"
        :event-key="removeKeyConsentEventKey"
        @abort="abortKeyConsent"
        @consent="removeKeyConsent"
      />
      <h2>Select a key</h2>
      <div class="ui cards">
        <div class="card" v-for="identifier in keys">
          <div class="content">
            <div class="header">
              {{ identifier }}
            </div>
          </div>
          <div class="extra content">
            <div class="ui two buttons">
              <button class="ui basic blue button" @click="$emit('selected', identifier)">Use this key</button>
              <button class="ui basic red button" @click="deleteKey(identifier)">Delete</button>
            </div>
          </div>
        </div>
        <div class="card" v-if="!requestedKey">
          <div class="content">
            <div class="header">
              <div class="ui form">
                <input type="text" v-model="newIdentifier" placeholder="Key identifier"/>
              </div>
            </div>
          </div>
          <div class="extra content">
            <button :disabled="!newIdentifier" class="ui fluid basic blue button" @click="$emit('selected', newIdentifier)">Add a new key</button>
          </div>
        </div>
      </div>
      <hr />
      <button class="ui fluid orange button" @click="$emit('abort', type)">Abort</button>
    </div>
  </div>
</template>

<script>
import { defineComponent } from 'vue'
import { BorutaOauth, KeyStore, CustomEventHandler } from 'boruta-client'
import { storage } from '../store'

import Consent from './Consent.vue'

const eventHandler = new CustomEventHandler()

export default defineComponent({
  name: 'KeySelect',
  components: { Consent },
  data () {
    const keyStore = new KeyStore(eventHandler, storage)

    return {
      keys: [],
      newIdentifier: null,
      removeKeyConsentEventKey: null,
      requestedKey: null,
      keyStore
    }
  },
  mounted () {
    this.keyStore.listKeyIdentifiers().then(keys => {
      this.keys = keys
      keys.forEach(identifier => {
        eventHandler.listen('remove_key-request', identifier, () => {
          this.removeKeyConsentEventKey = identifier
        })
      })

      const dids = Promise.all(this.keys.map(async identifier => {
        return [identifier, await this.keyStore.extractDid(identifier)]
      })).then(keys => {
        const key = keys.find(([identifier, did]) => {
          return this.$route.query.client_id == did
        })

        if (key) {
          this.requestedKey = key[0]
          this.keys = [this.requestedKey]
        }
      })
    })
  },
  methods: {
    deleteKey (identifier) {
      this.keyStore.removeKey(identifier).then(keys => {
        this.keys = keys
      })
    },
    removeKeyConsent (eventKey) {
      eventHandler.dispatch('remove_key-approval', eventKey)
      this.removeKeyConsentEventKey = null
    },
    abortKeyConsent () {
      this.removeKeyConsentEventKey = null
    }
  }
})
</script>

<style scoped lang="scss">
.ui.cards {
  display: flex;
  justify-content: center;
}

.select-key {
  position: fixed;
  z-index: 1000;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
}

.key-select.segment {
  max-width: 80%;
}
</style>
