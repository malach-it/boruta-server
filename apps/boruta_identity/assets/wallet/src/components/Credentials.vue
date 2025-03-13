<template>
  <div class="credentials">
    <div class="ui container">
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
              <button class="ui basic red button" @click="$emit('deleteCredential', credential)">
              {{ deleteLabel || 'Delete' }}
              </button>
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
  props: ['credentials', 'deleteLabel'],
  components: { Consent },
  data () {
    return {
      formattedCredentials: [],
      credential: null
    }
  },
  methods: {
    showCredential (credential) {
      this.credential = credential
    },
    hideCredential (credential) {
      this.credential = null
    }
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

