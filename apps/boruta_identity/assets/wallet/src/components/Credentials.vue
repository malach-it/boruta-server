<template>
  <div class="credentials">
    <div class="ui container">
      <Consent
        message="You are about to remove a credential from your wallet"
        :event-key="deleteConsentEventKey"
        @abort="abortDelete"
        @consent="deleteConsent"
      />
      <div class="ui cards">
        <div class="card" v-for="credential in credentials">
          <div class="content">
            <!-- <img class="right floated mini ui image" src="/images/avatar/large/elliot.jpg"> -->
            <div class="header">
              {{ credential.credentialId }}
            </div>
            <div class="meta">
              {{ credential.format }}
            </div>
            <div class="description">
              <div class="ui list">
                <div class="item" v-for="claim in credential.claims">
                  <div class="content">
                    <a class="header">{{ claim.key }}</a>
                    <div class="description">{{ claim.value }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="extra content">
            <div class="ui fluid buttons">
              <button class="ui basic red button" @click="deleteCredential(credential)">Delete</button>
              <button class="ui basic blue button" @click="showCredential(credential)">Show</button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-wrapper" v-if="credential">
      <div class="ui modal visible active">
        <div class="header">
          {{ credential.credential_configuration_id }} credential JWT
        </div>
        <div class="content">
          <div class="description">
            <p class="ui segment"><pre>{{ credential.credential }}</pre></p>
          </div>
        </div>
        <div class="actions">
          <button class="ui positive right labeled icon button" @click="hideCredential()">
            Done
            <i class="checkmark icon"></i>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { defineComponent } from 'vue'
import { decodeSdJwt } from '@sd-jwt/decode'
import Consent from './Consent.vue'

export default defineComponent({
  name: 'CredentialsView',
  props: ['credentials'],
  components: { Consent },
  data () {
    return {
      formattedCredentials: [],
      credential: null,
      credentialToDelete: null,
      deleteConsentEventKey: null
    }
  },
  methods: {
    showCredential (credential) {
      this.credential = credential
    },
    hideCredential (credential) {
      this.credential = null
    },
    deleteCredential (credential) {
      window.addEventListener('delete_credential-request~' + credential.credential, () => {
        this.deleteConsentEventKey = credential.credential
      })
      this.$store.commit('deleteCredential', credential)
    },
    deleteConsent (eventKey) {
      window.dispatchEvent(new Event('delete_credential-approval~' + eventKey))
      this.deleteConsentEventKey = null
    },
    abortDelete (eventKey) {
      this.deleteConsentEventKey = null
    },
  }
})
</script>

<style scoped lang="scss">
.ui.cards {
  justify-content: center;
}
.card .item {
  overflow: hidden

}
pre {
  white-space: pre-wrap;
  word-wrap: break-word;
  overflow: hidden;
  overflow-y: scroll;
  max-height: 60vh;
}
.modal-wrapper {
  z-index: 1000;
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 1em;
}
</style>

