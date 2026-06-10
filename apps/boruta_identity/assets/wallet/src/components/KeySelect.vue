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
      <div class="ui error message" v-if="keyPromptError">{{ keyPromptError }}</div>
      <div class="ui cards">
        <div class="card" v-for="[identifier, did] in keys">
          <div class="content">
            <div class="header">
              {{ identifier }}
            </div>
            <div class="description">
              <p class="ui warning message" v-if="selectedKeys.includes(identifier)"><em>key confirmed</em></p>
              <div class="ui form">
                <input type="hidden" :value="identifier" />
                <input type="password" v-model="passwords[identifier]" placeholder="Key password" autocomplete="current-password" @keyup.enter="selectKey(identifier)" />
              </div>
            </div>
          </div>
          <div class="extra content">
            <div class="ui two buttons">
              <button :disabled="!passwords[identifier]" class="ui basic blue button" @click="selectKey(identifier)">Use this key</button>
              <button class="ui basic red button" @click="deleteKey(identifier)">Delete</button>
            </div>
          </div>
        </div>
        <div class="card">
          <div class="content">
            <div class="header">
              <div class="ui form">
                <input type="text" v-model="newIdentifier" placeholder="Key identifier"/>
                <input type="password" v-model="newPassword" placeholder="Key password" autocomplete="new-password"/>
              </div>
            </div>
          </div>
          <div class="extra content">
            <button :disabled="!newIdentifier || !newPassword" class="ui fluid basic blue button" @click="$emit('selected', newIdentifier, null, newPassword)">Add a new key</button>
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
import { KeyStore, CustomEventHandler } from 'boruta-client'
import { EbsiWallet } from '@cef-ebsi/wallet-lib'
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
      newPassword: null,
      removeKeyConsentEventKey: null,
      requestedKey: null,
      requestedDid: null,
      selectedKeys: [],
      keyPromptError: null,
      passwords: {},
      keyStore
    }
  },
  async mounted () {
    await this.keyStore.listKeyIdentifiers().then(keys => {
      this.keys = keys.map(key => [key])
      keys.forEach(identifier => {
        eventHandler.listen('remove_key-request', identifier, () => {
          this.removeKeyConsentEventKey = identifier
        })
      })
    })

    this.requestedDid = this.requestedDidFromRoute()
    this.requestedKey = this.requestedDid

    if (this.requestedKey) {
      const keySelections = localStorage.getItem('keySelection')
      if (keySelections) {
        keySelections.split('|').filter(Boolean).forEach(keySelection => {
          const keySelectedAt = keySelection.split('~')[0]
          const selectedKey = keySelection.split('~')[1]
          if (parseInt(keySelectedAt) + 60000 > Date.now()) {
            this.selectedKeys.push(selectedKey)
          } else {
            localStorage.setItem('keySelection', keySelections.replace('|' + keySelection, ''))
          }
        })
      }
    }
  },
  methods: {
    async selectKey (identifier) {
      const password = this.passwords[identifier]

      if (!password) return

      this.keyPromptError = null

      try {
        const keyPair = await this.keyStore.keyPair(identifier, password)
        if (!keyPair?.publicKeyJwk) {
          this.keyPromptError = 'Could not unlock selected key.'
          return
        }

        const did = EbsiWallet.createDid('NATURAL_PERSON', keyPair.publicKeyJwk)

        if (this.requestedDid && did != this.requestedDid) {
          this.keyPromptError = 'Selected key does not match the requested key.'
          return
        }

        this.$emit('selected', identifier, did, password)
      } catch (_error) {
        this.keyPromptError = 'Could not unlock selected key.'
      }
    },
    deleteKey (identifier) {
      this.keyStore.removeKey(identifier).then(keys => {
        this.keys = keys.map(key => [key])
      })
    },
    removeKeyConsent (eventKey) {
      eventHandler.dispatch('remove_key-approval', eventKey)
      this.removeKeyConsentEventKey = null
    },
    abortKeyConsent () {
      this.removeKeyConsentEventKey = null
    },
    requestedDidFromRoute () {
      if (this.$route.query.client_id) {
        return this.didOrNull(this.$route.query.client_id)
      }

      try {
        return this.didOrNull(JSON.parse(this.$route.query.credential_offer).client_id)
      } catch (_error) {
        return null
      }
    },
    didOrNull (value) {
      if (typeof value != 'string') return null

      return value.startsWith('did:') ? value : null
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
